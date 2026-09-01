local env = require 'util.env'
local git = require 'util.git'
local util = require 'util'
local pick = require 'util.pick'

-- Grepping a static file list passes every path on the command line, so it has
-- to be capped.
local MAX_GREPPED_FILES = 500

local CONTENT_RIPGREP = {
  'rg',
  '--color=never',
  '--no-heading',
  '--with-filename',
  '--line-number',
  '--column',
  '--smart-case',
}

local function extend(...)
  local out = {}
  for _, list in ipairs { ... } do
    vim.list_extend(out, list)
  end
  return out
end

local scope = require 'util.scope'

---------------------------------------------------------------- live grep ----

local function live_grep_file_list(opts, file_list)
  opts = opts or {}
  opts.cwd = util.root_dir()

  local cmd_opts, dir_opts
  opts, cmd_opts, dir_opts = scope.constrain(opts)

  -- --hidden plus --no-ignore would be `rg -uu`; only hidden is wanted here.
  opts.vimgrep_arguments = extend(CONTENT_RIPGREP, { '--hidden' }, cmd_opts)
  opts.search_dirs = extend(opts.search_dirs or {}, dir_opts, file_list)

  require('telescope.builtin').live_grep(opts)
end

local function git_file_list(args, root)
  local res = vim.system(extend({ 'git' }, args), { text = true, cwd = root or util.root_dir() }):wait()
  if res.code ~= 0 then
    vim.notify(res.stderr or 'git failed', vim.log.levels.ERROR)
    return {}
  end
  local files = {}
  for line in (res.stdout or ''):gmatch '[^\r\n]+' do
    table.insert(files, line)
  end
  return files
end

local function live_grep_changed(opts)
  opts = opts or {}
  opts.prompt_title = 'Live Grep Changed Files from HEAD'
  -- `git status --porcelain -u` prefixes a fixed-width status code ("XY "), so
  -- strip exactly that. Matching the last whitespace-delimited token instead
  -- truncated any path containing a space to its final component.
  local files = {}
  for _, line in ipairs(git_file_list { 'status', '--porcelain', '-u' }) do
    local path = line:sub(4)
    -- Git quotes paths with unusual characters (core.quotePath); the C-style
    -- escapes that matter here are \" and \\.
    if path:sub(1, 1) == '"' then
      path = path:sub(2, -2):gsub('\\(.)', '%1')
    end
    -- A rename reads `old -> new`; `new` is the path that exists now.
    path = path:match '^.* %-> (.+)$' or path
    if path ~= '' then
      table.insert(files, path)
    end
  end
  live_grep_file_list(opts, files)
end

local function live_grep_changed_from(ref, opts)
  if not ref then
    return
  end
  local files = git_file_list { 'diff', '--name-only', ref .. '..HEAD' }
  if #files > MAX_GREPPED_FILES then
    vim.notify(('Too many files (%d); limiting to the first %d'):format(#files, MAX_GREPPED_FILES), vim.log.levels.WARN)
    files = vim.list_slice(files, 1, MAX_GREPPED_FILES)
  end
  live_grep_file_list(opts, files)
end

local function live_grep_changed_from_fork(opts)
  opts = opts or {}
  opts.prompt_title = 'Live Grep Changed Files from Fork'
  live_grep_changed_from(git.require_fork_point(), opts)
end

local function live_grep_changed_from_main(opts)
  opts = opts or {}
  local main = git.main_branch()
  opts.prompt_title = 'Live Grep Changed Files from ' .. main
  live_grep_changed_from(main, opts)
end

local function live_grep_changed_from_branch()
  pick.branch(function(branch)
    live_grep_changed_from(branch, { prompt_title = 'Live Grep Changed Files from ' .. branch })
  end)
end

------------------------------------------------------------ changed files ----

-- git_file_list runs git from the repo root, so its paths are root-relative --
-- anchor them there and not at nvim's cwd, which differs the moment you are in
-- a subdirectory. `root` is captured once per picker rather than re-resolved:
-- both this and the previewer run with telescope's prompt buffer current, where
-- util.root_dir() would answer for that buffer instead of the real one.
local function entry_maker_for(root)
  return function(entry)
    return {
      value = entry,
      display = entry,
      ordinal = entry,
      filename = vim.fs.joinpath(root, entry),
    }
  end
end

-- delta makes the diff readable, but it's an external binary; fall back to
-- git's own output when it isn't installed.
-- `-C` for the same reason as entry_maker_for: the termopen previewer inherits
-- nvim's cwd, but `value` is relative to the repo root.
local function diff_command(ref, value, root)
  local cmd = { 'git', '-C', root }
  if vim.fn.executable 'delta' == 1 then
    vim.list_extend(cmd, { '-c', 'core.pager=delta', '-c', 'delta.side-by-side=false' })
  end
  vim.list_extend(cmd, { 'diff', '--diff-filter=ACMR', '--relative', ref, '--', value })
  return cmd
end

local function changed_files_from(ref, include_untracked)
  if not ref then
    return
  end
  local finders = require 'telescope.finders'
  local pickers = require 'telescope.pickers'
  local previewers = require 'telescope.previewers'
  local sorters = require 'telescope.sorters'

  -- Resolved from the buffer you invoked the picker from, then reused
  -- throughout: see entry_maker_for.
  local root = util.root_dir()
  local entry_maker = entry_maker_for(root)

  local diff_args = { 'diff', '--name-only', '--diff-filter=ACMR', '--relative', ref }
  local untracked_args = { 'ls-files', '--others', '--exclude-standard' }

  -- `with_untracked` overrides the picker's own setting, for the <C-i> mapping
  -- below that pulls untracked files into an already-open picker.
  local function results(with_untracked)
    if with_untracked == nil then
      with_untracked = include_untracked
    end
    local files = git_file_list(diff_args, root)
    if with_untracked then
      local seen = {}
      for _, f in ipairs(files) do
        seen[f] = true
      end
      for _, f in ipairs(git_file_list(untracked_args, root)) do
        if not seen[f] then
          table.insert(files, f)
          seen[f] = true
        end
      end
    end
    return files
  end

  pickers
    .new({
      prompt_title = 'Changed files from ' .. ref .. (include_untracked and ' (+untracked)' or ''),
      finder = finders.new_table { results = results(), entry_maker = entry_maker },
      sorter = sorters.get_fuzzy_file(),
      previewer = previewers.new_termopen_previewer {
        get_command = function(entry)
          return diff_command(ref, entry.value, root)
        end,
      },
      attach_mappings = function(prompt_bufnr, map)
        map({ 'i', 'n' }, '<C-i>', function()
          local picker = require('telescope.actions.state').get_current_picker(prompt_bufnr)
          picker:refresh(
            finders.new_table { results = results(true), entry_maker = entry_maker },
            { reset_prompt = false }
          )
        end, { desc = 'include_untracked_files' })
        return true
      end,
    }, {})
    :find()
end

--------------------------------------------------------------------- git -----

local function reset_file_to(ref)
  if not ref then
    return
  end
  local file = vim.fn.expand '%:p'
  if file == '' then
    vim.notify('No file to reset', vim.log.levels.WARN)
    return
  end
  -- Was `:Git checkout` via fugitive, which this config doesn't have.
  git.run({ 'checkout', ref, '--', file }, 'Reset ' .. vim.fn.fnamemodify(file, ':t') .. ' to ' .. ref)
end

---------------------------------------------------------------- pickers ------

local function project_files()
  local builtin = require 'telescope.builtin'
  -- A scope narrows to its dirs, which git_files can't express.
  if scope.dirs() then
    builtin.find_files(scope.apply {})
    return
  end
  local res = vim.system({ 'git', 'rev-parse', '--is-inside-work-tree' }):wait()
  if res.code == 0 then
    builtin.git_files { show_untracked = true }
  else
    builtin.find_files {}
  end
end

local function b(name, opts)
  return function()
    require('telescope.builtin')[name](opts or {})
  end
end

return {
  {
    'nvim-telescope/telescope.nvim',
    cmd = 'Telescope',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = env.OS == 'windows' and 'mingw32-make' or 'make',
      },
      'nvim-telescope/telescope-live-grep-args.nvim',
      'paopaol/telescope-git-diffs.nvim',
      'scottmckendry/pick-resession.nvim',
    },
    keys = {
      { '<leader>:', b 'commands', desc = 'find_commands' },
      { '<leader>ff', project_files, desc = 'git_files' },
      {
        '<leader>fF',
        function()
          require('telescope.builtin').find_files { default_text = env.USER_PREFIX .. '_', no_ignore = true }
        end,
        desc = 'ignored_files',
      },
      { '<leader>fa', b('find_files', { no_ignore = true }), desc = 'all' },
      {
        '<leader>fn',
        function()
          require('telescope.builtin').find_files {
            cwd = vim.fs.joinpath(util.root_dir(), 'wiki'),
            no_ignore = true,
          }
        end,
        desc = 'notes',
      },
      {
        '<leader>fA',
        function()
          local basename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t:r'):lower()
          if scope.dirs() then
            require('telescope.builtin').find_files(scope.apply { default_text = basename })
          else
            require('telescope.builtin').git_files { default_text = basename }
          end
        end,
        desc = 'alternate',
      },

      -- Changed-file pickers
      {
        '<leader>fi',
        function()
          changed_files_from('HEAD', true)
        end,
        desc = 'files_from_head_include_untracked',
      },
      {
        '<leader>fj',
        function()
          changed_files_from 'HEAD'
        end,
        desc = 'files_from_head',
      },
      {
        '<leader>fk',
        function()
          changed_files_from(git.require_fork_point())
        end,
        desc = 'files_from_fork',
      },
      {
        '<leader>fl',
        function()
          changed_files_from(git.main_branch())
        end,
        desc = 'files_from_main',
      },
      {
        '<leader>f;',
        function()
          pick.branch(changed_files_from)
        end,
        desc = 'files_from_branch',
      },

      -- Grep across changed files, on both <leader>f and <leader>g
      { '<leader>fJ', live_grep_changed, desc = 'grep_from_head' },
      { '<leader>fK', live_grep_changed_from_fork, desc = 'grep_from_fork' },
      { '<leader>fL', live_grep_changed_from_main, desc = 'grep_from_main' },
      { '<leader>f:', live_grep_changed_from_branch, desc = 'grep_from_branch' },
      { '<leader>gJ', live_grep_changed, desc = 'grep_from_head' },
      { '<leader>gK', live_grep_changed_from_fork, desc = 'grep_from_fork' },
      { '<leader>gL', live_grep_changed_from_main, desc = 'grep_from_main' },
      { '<leader>g:', live_grep_changed_from_branch, desc = 'grep_from_branch' },
      {
        '<leader>ft',
        function()
          live_grep_changed_from_fork { default_text = env.TODO_CUSTOM .. ':' }
        end,
        desc = 'todos_in_fork(' .. env.TODO_CUSTOM .. ')',
      },

      -- Git pickers
      { '<leader>fgb', b 'git_branches', desc = 'branch_checkout' },
      {
        '<leader>fgB',
        b('git_branches', { show_remote_tracking_branches = false }),
        desc = 'branch_checkout_local',
      },
      { '<leader>fgc', b 'git_bcommits', desc = 'commits_checkout' },
      {
        '<leader>fgC',
        function()
          require('telescope').extensions.git_diffs.diff_commits()
        end,
        desc = 'commits_diff',
      },
      { '<leader>fgz', b 'git_stash', desc = 'stash' },
      { '<leader>gzf', b 'git_stash', desc = 'find' },
      { '<leader>fgx', '<cmd>Telescope conflicts<cr>', desc = 'conflicts' },
      {
        '<leader>gm',
        function()
          pick.branch(function(branch)
            git.run({ 'merge', branch }, 'Merged ' .. branch)
          end)
        end,
        desc = 'merge_from_branch',
      },
      {
        '<leader>gRk',
        function()
          reset_file_to(git.require_fork_point())
        end,
        desc = 'reset_file_to_fork',
      },
      {
        '<leader>gRl',
        function()
          reset_file_to(git.main_branch())
        end,
        desc = 'reset_file_to_main',
      },
      {
        '<leader>gR;',
        function()
          pick.branch(reset_file_to)
        end,
        desc = 'reset_file_to_branch',
      },

      -- Grep
      {
        '<leader>f/',
        function()
          require('telescope.builtin').live_grep(scope.apply {})
        end,
        desc = 'live_grep_global',
      },
      {
        '<leader>f?',
        function()
          require('telescope').extensions.live_grep_args.live_grep_args(scope.apply {})
        end,
        desc = 'live_grep_global_with_args',
      },
      { '<leader>/', b 'current_buffer_fuzzy_find', desc = 'find_local' },
      {
        '<leader>?',
        function()
          local search = vim.fn.input 'Search > '
          if search ~= '' then
            require('telescope.builtin').grep_string(scope.apply { search = search })
          end
        end,
        desc = 'find_global',
      },
      {
        '<leader>fw',
        function()
          require('telescope.builtin').grep_string(scope.apply { search = vim.fn.expand '<cword>' })
        end,
        desc = 'word',
      },
      {
        '<leader>fW',
        function()
          require('telescope.builtin').grep_string(scope.apply { search = vim.fn.expand '<cWORD>' })
        end,
        desc = 'whole_word',
      },

      -- Misc pickers
      { '<leader>Ff', '<cmd>Telescope<cr>', desc = 'builtin' },
      { '<leader>wf', '<cmd>Telescope resession<cr>', desc = 'find_session' },
      { '<leader>fs', b 'lsp_document_symbols', desc = 'symbols' },
      { '<leader>fm', b 'marks', desc = 'marks' },
      { '<leader>fr', b('oldfiles', { only_cwd = true }), desc = 'recents' },
      { '<leader>f"', b 'registers', desc = 'registers' },
      { '<leader>f=', b 'spell_suggest', desc = 'spellcheck' },
      {
        '<leader>fh',
        function()
          require('telescope.builtin').buffers {
            -- Unsaved buffers first, then buffer order.
            sort_buffers = function(a, z)
              if vim.bo[a].modified ~= vim.bo[z].modified then
                return vim.bo[a].modified
              end
              return a < z
            end,
          }
        end,
        desc = 'buffers',
      },
      {
        '<leader>wc',
        function()
          require('telescope.builtin').find_files {
            prompt_title = 'Workspace Configuration',
            hidden = true,
            no_ignore = true,
            no_ignore_parent = true,
            search_dirs = { '.vscode' },
          }
        end,
        desc = 'local_config',
      },
    },
    config = function()
      local actions = require 'telescope.actions'
      local action_layout = require 'telescope.actions.layout'
      local lga_actions = require 'telescope-live-grep-args.actions'

      -- Bound as `y` in every picker, so it cannot assume entry.value is a
      -- string: builtins like `commands` (<leader>:) put a table there.
      local function yank_name(prompt_bufnr)
        local entry = require('telescope.actions.state').get_selected_entry()
        local name = entry and entry.value
        if type(name) ~= 'string' then
          name = entry and entry.ordinal
        end
        if type(name) ~= 'string' then
          name = entry and type(entry.display) == 'string' and entry.display or nil
        end
        if name and name ~= '' then
          vim.fn.setreg('+', name)
          vim.notify('Copied : ' .. name)
        else
          vim.notify('Nothing to copy from this entry', vim.log.levels.WARN)
        end
        actions.close(prompt_bufnr)
      end

      -- The old config also bound T/t here to send results to trouble.nvim,
      -- which isn't part of this config.
      local defaults = {
        follow = true,
        path_display = { filename_first = { reverse_directories = true } },
        preview = { filesize_limit = 0.5 },
        mappings = {
          n = {
            ['p'] = action_layout.toggle_preview,
            ['y'] = yank_name,
          },
        },
      }

      require('telescope').setup {
        defaults = defaults,
        pickers = {
          find_files = defaults,
          live_grep = defaults,
          grep_string = defaults,
          git_files = defaults,
          git_branches = {
            mappings = {
              i = { ['<cr>'] = actions.git_switch_branch },
              n = {
                ['<cr>'] = actions.git_switch_branch,
                ['d'] = actions.git_delete_branch,
                ['R'] = actions.git_rebase_branch,
                ['r'] = actions.git_rename_branch,
                ['m'] = actions.git_merge_branch,
                ['c'] = actions.git_checkout,
                ['C'] = actions.git_create_branch,
                ['p'] = action_layout.toggle_preview,
                ['y'] = yank_name,
              },
            },
          },
        },
        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = 'smart_case',
          },
          live_grep_args = {
            auto_quoting = true,
            mappings = {
              i = {
                ['<C-k>'] = lga_actions.quote_prompt(),
                ['<C-i>'] = lga_actions.quote_prompt { postfix = ' --iglob **' },
                ['<C-f>'] = actions.to_fuzzy_refine,
              },
            },
          },
          git_diffs = {
            git_command = { 'git', 'log', '--oneline', '--decorate', '--all', '.' },
          },
          resession = {
            prompt_title = 'Find Sessions',
            dir = 'session',
          },
        },
      }

      require('telescope').load_extension 'fzf'
      require('telescope').load_extension 'git_diffs'
    end,
  },
}
