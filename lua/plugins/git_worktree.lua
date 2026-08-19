-- Linked worktrees live under .claude/worktrees inside the repo.
--
-- `_G.worktree_symlinks`, `_G.worktree_create_callback` and
-- `_G.worktree_from_branch` are project-local exrc knobs.

-- Run git and return ok plus trimmed stdout. Replaces the
-- vim.fn.system + vim.v.shell_error pairs the old config used throughout.
local function git_out(args)
  local res = vim.system(vim.list_extend({ 'git' }, args), { text = true }):wait()
  return res.code == 0, vim.trim(res.stdout or '')
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

-- The repo's primary working tree: the first non-bare entry `git worktree list`
-- reports. Records are delimited by the next `worktree` line, so this does not
-- depend on the blank separators that git_lines strips.
local function main_worktree(cwd)
  local ok, lines = git_lines { '-C', cwd, 'worktree', 'list', '--porcelain' }
  if not ok then
    return nil
  end

  local path, bare = nil, false
  for _, line in ipairs(lines) do
    local next_path = line:match '^worktree (.+)$'
    if next_path then
      if path and not bare then
        return path
      end
      path, bare = next_path, false
    elseif line == 'bare' then
      bare = true
    end
  end

  return (path and not bare) and path or nil
end

-- Centered single-line input. The global vim.ui.input provider renders at the
-- cursor; this floats in the middle of the editor instead.
local function centered_input(opts, on_submit)
  local ok, Input = pcall(require, 'nui.input')
  if not ok then
    return vim.ui.input(opts, on_submit)
  end
  local event = require('nui.utils.autocmd').event
  local title = (opts.prompt or 'Input'):gsub('%s*:%s*$', '')
  local input = Input({
    relative = 'editor',
    position = '50%',
    size = { width = math.min(60, vim.o.columns - 8) },
    border = {
      style = 'rounded',
      text = { top = ' ' .. title .. ' ', top_align = 'center' },
    },
    win_options = { winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder' },
  }, {
    default_value = opts.default or '',
    on_submit = on_submit,
  })
  input:mount()
  input:map('n', '<Esc>', function()
    input:unmount()
  end, { noremap = true })
  input:map('i', '<C-c>', function()
    input:unmount()
  end, { noremap = true })
  input:on(event.BufLeave, function()
    input:unmount()
  end)
end

-- Set by the CREATE hook so the create-triggered SWITCH can stay put.
local stay_after_create = nil

local function switch_worktree()
  require('telescope').extensions.git_worktree.git_worktree { cwd = worktree_root() }
end

local function create_worktree()
  local root = worktree_root()
  centered_input({ prompt = 'New worktree name: ' }, function(name)
    name = name and vim.trim(name)
    if not name or name == '' then
      return
    end
    -- git-worktree.nvim runs every git op from nvim's cwd; point it at the
    -- working tree (not the .git dir) so `git worktree add` resolves right.
    vim.cmd.cd(vim.fn.fnameescape(root))
    require('git-worktree').create_worktree(worktree_dest(root, name), name, _G.worktree_from_branch or 'origin/main')
  end)
end

local function delete_worktree()
  local root = worktree_root()
  local ok, lines = git_lines { '-C', root, 'worktree', 'list' }
  if not ok then
    vim.notify('Not a git repository', vim.log.levels.ERROR)
    return
  end

  local items = {}
  for _, line in ipairs(lines) do
    local path, rest = line:match '^(%S+)%s+(.*)$'
    if path and not rest:match '^%(bare%)' then
      table.insert(items, { path = path, label = line })
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

-- Promote the current worktree onto the main working tree: bring its branch
-- (committed history) and any uncommitted work over, then tear the worktree
-- down. The main tree ends up checked out on the worktree's branch.
local function move_worktree_to_repo()
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
    vim.notify('Already in the main working tree — nothing to move', vim.log.levels.WARN)
    return
  end

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

  local choice = vim.fn.confirm(
    ('Move worktree "%s" (branch %s) onto\n%s ?'):format(vim.fn.fnamemodify(cur, ':t'), branch, main),
    '&Yes\n&No',
    2
  )
  if choice ~= 1 then
    return
  end

  -- Preserve uncommitted work (tracked + untracked) in the stash, which lives in
  -- the shared git dir and so is reachable from the main tree afterwards.
  local stashed = false
  local _, cur_dirty = git_lines { '-C', cur, 'status', '--porcelain' }
  if #cur_dirty > 0 then
    local stash_ok = git_out { '-C', cur, 'stash', 'push', '--include-untracked', '-m', 'worktree-move: ' .. branch }
    if not stash_ok then
      vim.notify('Failed to stash worktree changes; aborting', vim.log.levels.ERROR)
      return
    end
    stashed = true
  end

  -- Step out of the worktree before removing it so nvim's cwd isn't inside it.
  vim.cmd.cd(vim.fn.fnameescape(main))

  if not (git_out { '-C', main, 'worktree', 'remove', '--force', cur }) then
    vim.notify('Failed to remove worktree; `git stash pop` in it to recover changes', vim.log.levels.ERROR)
    return
  end

  if not (git_out { '-C', main, 'checkout', branch }) then
    vim.notify('Worktree removed but `git checkout ' .. branch .. '` failed in ' .. main, vim.log.levels.ERROR)
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
      { '<leader>wwm', move_worktree_to_repo, desc = 'worktree_move_to_repo' },
    },
    config = function()
      require('telescope').load_extension 'git_worktree'

      local Hooks = require 'git-worktree.hooks'
      local config = require 'git-worktree.config'

      Hooks.register(Hooks.type.CREATE, function(path, branch)
        -- git-worktree.nvim auto-switches into the new worktree right after this
        -- hook. Stash the current cwd so the create-triggered SWITCH can bail
        -- out and leave us where we are instead of following into the new tree.
        stay_after_create = vim.uv.cwd()

        -- Symlink local-only files (not tracked by git) into the fresh worktree
        -- so it's ready to run and stays in sync with the source. The hook fires
        -- before the switch, so cwd is still the source worktree.
        local ok, src = git_out { 'rev-parse', '--show-toplevel' }
        local dest = vim.fn.fnamemodify(path, ':p'):gsub('/$', '')
        local symlinks = _G.worktree_symlinks or { '.env', '.vscode' }
        if ok and src ~= '' and src ~= dest then
          for _, item in ipairs(symlinks) do
            local from = vim.fs.joinpath(src, item)
            local to = vim.fs.joinpath(dest, item)
            if vim.uv.fs_stat(from) then
              -- -f replaces an existing entry; -n avoids dereferencing a
              -- symlinked directory target.
              local res = vim.system({ 'ln', '-sfn', from, to }):wait()
              if res.code ~= 0 then
                vim.notify('Failed to symlink ' .. item .. ' into worktree', vim.log.levels.WARN)
              end
            end
          end
        end

        if _G.worktree_create_callback ~= nil then
          _G.worktree_create_callback(path, branch)
        end
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
