-- Linked worktrees live under .claude/worktrees inside the repo.
--
-- `_G.worktree_symlinks`, `_G.worktree_create_callback` and
-- `_G.worktree_from_branch` are project-local exrc knobs.

-- Run git and return ok, trimmed stdout, and git's own stderr -- without that
-- last one a failure here can only be reported as "it failed".
local function git_out(args)
  local res = vim.system(vim.list_extend({ 'git' }, args), { text = true }):wait()
  return res.code == 0, vim.trim(res.stdout or ''), vim.trim(res.stderr or '')
end

-- Append git's complaint to our own message when it said anything.
local function with_stderr(msg, err)
  return (err and err ~= '') and (msg .. ':\n' .. err) or msg
end

local function git_lines(args)
  local ok, out = git_out(args)
  if not ok or out == '' then
    return ok, {}
  end
  local lines = {}
  for line in out:gmatch '[^\r\n]+' do
    table.insert(lines, line)
  end
  return true, lines
end

-- Resolve the working-tree root. git-worktree.nvim and telescope run their git
-- commands from nvim's cwd; when that cwd is inside the `.git` dir (e.g. nvim
-- launched there) `git rev-parse --show-toplevel` fails. Fall back to the
-- parent of the resolved git dir in that case.
local function worktree_root()
  local ok, top = git_out { 'rev-parse', '--show-toplevel' }
  if ok and top ~= '' then
    return top
  end
  local ok2, gitdir = git_out { 'rev-parse', '--absolute-git-dir' }
  if ok2 and gitdir ~= '' then
    return vim.fn.fnamemodify((gitdir:gsub('/$', '')), ':h')
  end
  return vim.uv.cwd() or '.'
end

local function worktree_dest(root, name)
  return vim.fs.joinpath(root, '.claude', 'worktrees', name)
end

-- Make a freshly added worktree usable: symlink the local-only files (not
-- tracked by git, so `worktree add` does not bring them) from `src`, then let
-- the project hook in. Shared by the CREATE hook and move_branch_to_worktree.
local function prepare_worktree(src, dest, branch)
  dest = vim.fn.fnamemodify(dest, ':p'):gsub('/$', '')
  if src ~= '' and src ~= dest then
    for _, item in ipairs(_G.worktree_symlinks or { '.env', '.vscode' }) do
      local from = vim.fs.joinpath(src, item)
      if vim.uv.fs_stat(from) then
        -- -f replaces an existing entry; -n avoids dereferencing a symlinked
        -- directory target.
        local res = vim.system({ 'ln', '-sfn', from, vim.fs.joinpath(dest, item) }):wait()
        if res.code ~= 0 then
          vim.notify('Failed to symlink ' .. item .. ' into worktree', vim.log.levels.WARN)
        end
      end
    end
  end
  if _G.worktree_create_callback ~= nil then
    _G.worktree_create_callback(dest, branch)
  end
end

-- Worktree records for the repo `cwd` is in; nil when that is not a repo. The
-- parsing lives in util.git so the Claude worktree maps read the same records.
local function worktree_records(cwd)
  return require('util.git').worktrees(cwd)
end

-- The repo's primary working tree: the first non-bare entry git reports.
local function main_worktree(cwd)
  local records = worktree_records(cwd)
  if not records then
    return nil
  end
  for _, r in ipairs(records) do
    if not r.bare then
      return r.path
    end
  end
  return nil
end

-- git's lock reason for `path`, or nil when it is not locked. Claude Code locks
-- the worktree a session runs in, which is the usual reason one here is.
local function worktree_lock(cwd, path)
  local real = vim.uv.fs_realpath(path) or path
  for _, r in ipairs(worktree_records(cwd) or {}) do
    if (vim.uv.fs_realpath(r.path) or r.path) == real then
      return r.locked
    end
  end
  return nil
end

-- Set by the CREATE hook so the create-triggered SWITCH can stay put.
local stay_after_create = nil

-- Where the user actually was when they asked for a new worktree. create_worktree
-- has to cd to the repo root before handing off, so the CREATE hook cannot read
-- the real origin out of vim.uv.cwd() itself.
local create_origin = nil

local function switch_worktree()
  require('telescope').extensions.git_worktree.git_worktree { cwd = worktree_root() }
end

local function create_worktree()
  local root = worktree_root()
  vim.ui.input({ prompt = 'New worktree name: ' }, function(name)
    name = name and vim.trim(name)
    if not name or name == '' then
      return
    end
    -- git-worktree.nvim runs every git op from nvim's cwd; point it at the
    -- working tree (not the .git dir) so `git worktree add` resolves right.
    -- Remember where we came from first: this cd used to be permanent even when
    -- creation then aborted, and the CREATE hook's "stay put" value was this
    -- root rather than the directory the user was actually in.
    create_origin = vim.uv.cwd()
    vim.cmd.cd(vim.fn.fnameescape(root))

    -- Default the upstream to the repo's real default branch. Hard-coding
    -- origin/main silently based a new worktree on the current HEAD in any
    -- repo whose default is something else: git-worktree.nvim treats an
    -- unresolvable upstream as "no upstream" rather than an error.
    local upstream = _G.worktree_from_branch or ('origin/' .. require('util.git').main_branch())

    local ok, err = pcall(require('git-worktree').create_worktree, worktree_dest(root, name), name, upstream)
    if not ok then
      if create_origin then
        vim.cmd.cd(vim.fn.fnameescape(create_origin))
      end
      create_origin = nil
      vim.notify('Failed to create worktree: ' .. tostring(err), vim.log.levels.ERROR)
    end
  end)
end

local function delete_worktree()
  local root = worktree_root()
  local records = worktree_records(root)
  if not records then
    vim.notify('Not a git repository', vim.log.levels.ERROR)
    return
  end

  local items = {}
  for _, r in ipairs(records) do
    if not r.bare then
      local suffix = (r.branch and ('  [' .. r.branch .. ']')) or (r.detached and '  [detached]') or ''
      table.insert(items, {
        path = r.path,
        locked = r.locked,
        label = r.path .. suffix .. (r.locked and '  (locked)' or ''),
      })
    end
  end
  if #items == 0 then
    vim.notify('No worktrees to delete', vim.log.levels.WARN)
    return
  end

  vim.ui.select(items, {
    prompt = 'Delete worktree',
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end
    -- git refuses a locked worktree, and the plugin's callback carries no reason.
    if choice.locked then
      local reason = type(choice.locked) == 'string' and choice.locked or 'no reason given'
      if
        vim.fn.confirm(('This worktree is locked:\n  %s\n\nUnlock and delete it?'):format(reason), '&Yes\n&No', 2) ~= 1
      then
        return
      end
      local ok_unlock, _, unlock_err = git_out { '-C', root, 'worktree', 'unlock', choice.path }
      if not ok_unlock then
        vim.notify(with_stderr('Failed to unlock the worktree', unlock_err), vim.log.levels.ERROR)
        return
      end
    end
    require('git-worktree').delete_worktree(choice.path, false, {
      on_success = function()
        vim.notify('Deleted worktree: ' .. choice.path)
      end,
      on_failure = function()
        vim.notify('Failed to delete ' .. choice.path .. ' (uncommitted changes or in use)', vim.log.levels.ERROR)
      end,
    })
  end)
end

-- Buffers with unwritten changes whose file lives under `dir`. The stash below
-- only captures what is on disk, so these would be lost by the --force removal.
local function modified_buffers_under(dir)
  -- Buffer names are fully resolved real paths, while `dir` can reach us through
  -- a symlink (/tmp -> /private/tmp on macOS), so resolve both sides or the
  -- comparison silently matches nothing.
  local root = vim.uv.fs_realpath(dir) or dir
  local prefix = root:gsub('/$', '') .. '/'
  local out = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
      local name = vim.api.nvim_buf_get_name(buf)
      local real = name ~= '' and (vim.uv.fs_realpath(name) or name) or ''
      if real:sub(1, #prefix) == prefix then
        table.insert(out, real:sub(#prefix + 1))
      end
    end
  end
  return out
end

-- Gitignored paths in `dir`. `stash push --include-untracked` does NOT stash
-- these, so `worktree remove --force` deletes them for good -- typically exactly
-- the local-only files the CREATE hook symlinks in (.env and friends), though a
-- symlink losing its own entry is harmless while a real file is not.
local function ignored_paths(dir)
  -- No --untracked-files=no here: it suppresses the ignored entries too. The
  -- `!!` filter below is what keeps untracked lines out.
  local _, lines = git_lines { '-C', dir, 'status', '--porcelain', '--ignored=matching' }
  local out = {}
  for _, line in ipairs(lines or {}) do
    local path = line:match '^!!%s+(.+)$'
    if path then
      if path:sub(1, 1) == '"' then
        path = path:sub(2, -2):gsub('\\(.)', '%1')
      end
      table.insert(out, path)
    end
  end
  return out
end

-- Promote the current worktree onto the main working tree: bring its branch
-- (committed history) and any uncommitted work over, then tear the worktree
-- down. The main tree ends up checked out on the worktree's branch.
local function move_worktree_to_repo(cur, main)
  local ok_branch, branch = git_out { '-C', cur, 'rev-parse', '--abbrev-ref', 'HEAD' }
  if not ok_branch or branch == '' or branch == 'HEAD' then
    vim.notify('Worktree is on a detached HEAD; cannot move by branch', vim.log.levels.ERROR)
    return
  end

  -- The main tree must be clean: `git checkout <branch>` there would refuse to
  -- overwrite local changes otherwise.
  local _, main_dirty = git_lines { '-C', main, 'status', '--porcelain' }
  if #main_dirty > 0 then
    vim.notify('Main working tree has local changes; commit or stash them first', vim.log.levels.ERROR)
    return
  end

  -- Unwritten buffer contents cannot be recovered once the worktree is gone, and
  -- the stash below reads from disk only -- so refuse rather than ask, the same
  -- way a dirty main tree is refused above.
  local unsaved = modified_buffers_under(cur)
  if #unsaved > 0 then
    vim.notify(
      'Unsaved changes in this worktree; write or discard them first:\n  ' .. table.concat(unsaved, '\n  '),
      vim.log.levels.ERROR
    )
    return
  end

  local prompt = ('Move worktree "%s" (branch %s) onto\n%s ?'):format(vim.fn.fnamemodify(cur, ':t'), branch, main)

  -- `worktree remove --force` refuses a locked tree (git wants --force twice),
  -- so unlock as part of the move. Named in the prompt because a live session's
  -- lock and one left behind by a crashed session look identical.
  local lock = worktree_lock(cur, cur)
  if lock then
    prompt = prompt
      .. '\n\nThis worktree is locked and will be unlocked first:\n  '
      .. (type(lock) == 'string' and lock or 'no reason given')
  end

  local ignored = ignored_paths(cur)
  if #ignored > 0 then
    local shown = vim.list_slice(ignored, 1, math.min(#ignored, 8))
    prompt = prompt
      .. ('\n\nThese gitignored paths are NOT stashed and will be deleted (%d):\n  '):format(#ignored)
      .. table.concat(shown, '\n  ')
    if #ignored > #shown then
      prompt = prompt .. ('\n  ... and %d more'):format(#ignored - #shown)
    end
  end

  local choice = vim.fn.confirm(prompt, '&Yes\n&No', 2)
  if choice ~= 1 then
    return
  end

  if lock then
    local ok_unlock, _, unlock_err = git_out { '-C', main, 'worktree', 'unlock', cur }
    if not ok_unlock then
      vim.notify(with_stderr('Failed to unlock the worktree', unlock_err), vim.log.levels.ERROR)
      return
    end
  end

  -- Preserve uncommitted work (tracked + untracked) in the stash, which lives in
  -- the shared git dir and so is reachable from the main tree afterwards.
  local stashed = false
  local _, cur_dirty = git_lines { '-C', cur, 'status', '--porcelain' }
  if #cur_dirty > 0 then
    local stash_ok, _, stash_err =
      git_out { '-C', cur, 'stash', 'push', '--include-untracked', '-m', 'worktree-move: ' .. branch }
    if not stash_ok then
      vim.notify(with_stderr('Failed to stash worktree changes; aborting', stash_err), vim.log.levels.ERROR)
      return
    end
    stashed = true
  end

  -- Step out of the worktree before removing it so nvim's cwd isn't inside it.
  vim.cmd.cd(vim.fn.fnameescape(main))

  local ok_rm, _, rm_err = git_out { '-C', main, 'worktree', 'remove', '--force', cur }
  if not ok_rm then
    local msg = with_stderr('Failed to remove worktree', rm_err)
    if stashed then
      msg = msg .. '\nYour changes are stashed — `git stash pop` in the worktree to recover them.'
    end
    vim.notify(msg, vim.log.levels.ERROR)
    return
  end

  local ok_co, _, co_err = git_out { '-C', main, 'checkout', branch }
  if not ok_co then
    vim.notify(
      with_stderr('Worktree removed but `git checkout ' .. branch .. '` failed in ' .. main, co_err),
      vim.log.levels.ERROR
    )
    return
  end

  if stashed and not (git_out { '-C', main, 'stash', 'pop' }) then
    vim.notify('Branch moved, but restoring changes hit conflicts — resolve them in ' .. main, vim.log.levels.WARN)
  end

  -- Re-point the current buffer from the (now gone) worktree path into main.
  local name = vim.api.nvim_buf_get_name(0)
  if name:find '^oil:///' then
    require('oil').open(main)
  elseif name:sub(1, #cur + 1) == cur .. '/' then
    pcall(vim.cmd.edit, vim.fn.fnameescape(main .. '/' .. name:sub(#cur + 2)))
  end

  vim.notify(('Moved %s onto the main working tree'):format(branch))
end

-- Lift the current branch out of the main working tree into a linked worktree:
-- the mirror of move_worktree_to_repo. Uncommitted work travels with it and the
-- main tree is left on the base branch, free for the dev stack.
local function move_branch_to_worktree(root)
  local ok_branch, branch = git_out { '-C', root, 'rev-parse', '--abbrev-ref', 'HEAD' }
  if not ok_branch or branch == '' or branch == 'HEAD' then
    vim.notify('Main tree is on a detached HEAD; cannot move by branch', vim.log.levels.ERROR)
    return
  end

  -- Where the main tree is left afterwards, and what new worktrees fork from.
  local base = (_G.worktree_from_branch or require('util.git').main_branch()):gsub('^origin/', '')
  if branch == base then
    vim.notify(('Already on %s — check out the branch you want to move first'):format(base), vim.log.levels.WARN)
    return
  end

  -- The stash below reads from disk, so unwritten buffers would be left behind
  -- in the tree their branch just left.
  local unsaved = modified_buffers_under(root)
  if #unsaved > 0 then
    vim.notify(
      'Unsaved changes in the main tree; write or discard them first:\n  ' .. table.concat(unsaved, '\n  '),
      vim.log.levels.ERROR
    )
    return
  end

  vim.ui.input({ prompt = 'New worktree name: ', default = branch }, function(name)
    name = name and vim.trim(name)
    if not name or name == '' then
      return
    end

    local dest = worktree_dest(root, name)
    if vim.uv.fs_stat(dest) then
      vim.notify('Already exists: ' .. dest, vim.log.levels.ERROR)
      return
    end

    local prompt = ('Move branch %s out of\n%s\ninto a worktree at\n%s ?\n\nThe main tree is left on %s.'):format(
      branch,
      root,
      dest,
      base
    )
    if vim.fn.confirm(prompt, '&Yes\n&No', 2) ~= 1 then
      return
    end

    local stashed = false
    local _, dirty = git_lines { '-C', root, 'status', '--porcelain' }
    if #dirty > 0 then
      local ok_stash, _, stash_err =
        git_out { '-C', root, 'stash', 'push', '--include-untracked', '-m', 'worktree-move: ' .. branch }
      if not ok_stash then
        vim.notify(with_stderr('Failed to stash changes; aborting', stash_err), vim.log.levels.ERROR)
        return
      end
      stashed = true
    end

    -- git will not check one branch out in two trees, so the main tree has to
    -- leave it before the worktree can take it.
    local ok_co, _, co_err = git_out { '-C', root, 'checkout', base }
    if not ok_co then
      if stashed then
        git_out { '-C', root, 'stash', 'pop' }
      end
      vim.notify(with_stderr('Failed to check out ' .. base, co_err), vim.log.levels.ERROR)
      return
    end

    local ok_add, _, add_err = git_out { '-C', root, 'worktree', 'add', dest, branch }
    if not ok_add then
      git_out { '-C', root, 'checkout', branch }
      if stashed then
        git_out { '-C', root, 'stash', 'pop' }
      end
      vim.notify(with_stderr('Failed to create the worktree', add_err), vim.log.levels.ERROR)
      return
    end

    prepare_worktree(root, dest, branch)

    if stashed and not (git_out { '-C', dest, 'stash', 'pop' }) then
      vim.notify('Branch moved, but restoring changes hit conflicts — resolve them in ' .. dest, vim.log.levels.WARN)
    end

    -- Follow the work: staying put would leave every buffer showing the base
    -- branch's version of a file whose changes now live in the worktree.
    vim.cmd.cd(vim.fn.fnameescape(dest))
    local buf = vim.api.nvim_buf_get_name(0)
    if buf:find '^oil:///' then
      require('oil').open(dest)
    elseif buf:sub(1, #root + 1) == root .. '/' then
      pcall(vim.cmd.edit, vim.fn.fnameescape(dest .. '/' .. buf:sub(#root + 2)))
    end

    vim.notify(('Moved %s into %s'):format(branch, dest))
  end)
end

-- <leader>wwm moves your work between the two trees, in whichever direction you
-- are: from a linked worktree it folds the branch onto the main tree, from the
-- main tree it lifts the current branch out into a worktree.
local function move_worktree()
  local ok, cur = git_out { 'rev-parse', '--show-toplevel' }
  if not ok or cur == '' then
    vim.notify('Not inside a git worktree', vim.log.levels.ERROR)
    return
  end

  local main = main_worktree(cur)
  if not main then
    vim.notify('Could not locate the main working tree', vim.log.levels.ERROR)
    return
  end

  if vim.fn.fnamemodify(main, ':p') == vim.fn.fnamemodify(cur, ':p') then
    move_branch_to_worktree(cur)
  else
    move_worktree_to_repo(cur, main)
  end
end

return {
  {
    'polarmutex/git-worktree.nvim',
    version = '^2',
    -- The old spec also depended on overseer.nvim; nothing here uses it.
    dependencies = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope.nvim' },
    keys = {
      { '<leader>www', switch_worktree, desc = 'worktree_switch' },
      { '<leader>wwc', create_worktree, desc = 'worktree_create' },
      { '<leader>wwd', delete_worktree, desc = 'worktree_delete' },
      { '<leader>wwm', move_worktree, desc = 'worktree_move' },
    },
    config = function()
      require('telescope').load_extension 'git_worktree'

      local Hooks = require 'git-worktree.hooks'
      local config = require 'git-worktree.config'

      Hooks.register(Hooks.type.CREATE, function(path, branch)
        -- git-worktree.nvim auto-switches into the new worktree right after this
        -- hook. Stash the current cwd so the create-triggered SWITCH can bail
        -- out and leave us where we are instead of following into the new tree.
        stay_after_create = create_origin or vim.uv.cwd()
        create_origin = nil

        -- The hook fires before the switch, so cwd is still the source worktree.
        local ok, src = git_out { 'rev-parse', '--show-toplevel' }
        prepare_worktree(ok and src or '', path, branch)
      end)

      Hooks.register(Hooks.type.SWITCH, function(path, prev_path)
        if stay_after_create then
          local stay = stay_after_create
          stay_after_create = nil
          -- Undo the auto-cd into the freshly created worktree.
          vim.cmd.cd(vim.fn.fnameescape(stay))
          return
        end

        vim.notify('Moved: ' .. prev_path .. '  ~>  ' .. path)

        if vim.fn.expand('%'):find '^oil:///' then
          require('oil').open(vim.uv.cwd())
        else
          Hooks.builtins.update_current_buffer_on_switch(path, prev_path)
        end
      end)

      Hooks.register(Hooks.type.DELETE, function()
        vim.cmd(config.update_on_change_command)
      end)
    end,
  },
}
