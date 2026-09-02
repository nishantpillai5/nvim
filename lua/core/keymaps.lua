local env = require 'util.env'

-- Descriptions go inline on each mapping. which-key and `:map` both read them
-- straight off the keymap, so there is no separate table to keep in sync.
local function map(mode, lhs, rhs, opts)
  opts = vim.tbl_extend('force', { noremap = true, silent = true }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

-- jk as escape
map('i', 'jk', '<Esc>', { desc = 'escape' })

-- Delete a blank line into the black hole register instead of clobbering ""
map('n', 'dd', function()
  return vim.api.nvim_get_current_line():match '^%s*$' and '"_dd' or 'dd'
end, { expr = true, noremap = false, desc = 'delete_line' })

-- Toggles
map('n', '<leader>zl', ':set relativenumber!<cr>', { desc = 'line_no_relative' })
map('n', '<leader>zw', ':set wrap!<cr>', { desc = 'wrap' })
map('n', '<leader>zq', ':set lazyredraw!<cr>', { desc = 'lazyredraw_toggle' })
map('n', '<leader>z/', ':nohlsearch<cr>', { desc = 'clear_search' })

-- <leader>a drives whichever AI backend is active: <leader>ab cycles it
-- (skipping any whose CLI isn't installed) and the tabline indicator says which
-- one is live. The operations themselves are registered by
-- plugins/claudecode.lua and plugins/omp.lua -- this only names the keys, so a
-- backend that can't do one of them says so instead of failing silently. The
-- keys live here rather than in either plugin's `keys` list because two specs
-- cannot both claim <leader>aa; util.ai loads the right plugin on first use.
-- See util/ai/init.lua and the AI section of README.md.
map({ 'n', 'v' }, '<leader>ab', function()
  require('util.ai').cycle()
end, { desc = 'backend_cycle' })

-- The prompt box, and the answer menu when the backend can see a question on
-- screen. Lives in util/ai/prompt.lua, which is backend-agnostic.
map({ 'n', 'v' }, '<leader><leader>', function()
  require('util.ai.prompt').open()
end, { desc = 'prompt' })

for _, entry in ipairs {
  { '<leader>aa', 'toggle', 'toggle' },
  { '<leader>j', 'accept', 'accept_prompt' },
  { '<leader>k', 'reject', 'reject_prompt' },
  { '<leader>al', 'interrupt', 'interrupt' },
  { '<leader>a;', 'next_tab', 'next_question' },
  { '<leader>am', 'cycle_mode', 'cycle_mode' },
  { '<leader>aM', 'model', 'model' },
  { '<leader>ax', 'kill', 'kill' },
  { '<leader>as', 'continue', 'session_continue' },
  { '<leader>aV', 'attach_buffer', 'attach_buffer' },
  { '<leader>af', 'find_session', 'find_session' },
  { '<leader>aF', 'find_session_cli', 'find_session_cli' },
  { '<leader>aw', 'worktree_continue', 'worktree_continue' },
  { '<leader>aW', 'worktree_session', 'worktree_session' },
  { '<leader>ay', 'diff_accept', 'diff_accept' },
  { '<leader>an', 'diff_reject', 'diff_reject' },
  { '<leader>ah', 'health', 'health' },
} do
  local lhs, op, desc = entry[1], entry[2], entry[3]
  map({ 'n', 'v' }, lhs, function()
    require('util.ai').call(op)
  end, { desc = desc })
end

-- <leader>av attaches what you are looking at, and what that means depends on
-- where you are: a visual selection anywhere, or the entry under the cursor in a
-- file tree. Two separate maps rather than one op that inspects the mode, so the
-- key simply does not exist in normal mode in an ordinary buffer -- which is how
-- it behaved when claudecode.nvim's own `keys` spec scoped it with `ft`.
map('v', '<leader>av', function()
  require('util.ai').call 'attach_visual'
end, { desc = 'attach_visual' })

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('ai_attach_tree', { clear = true }),
  pattern = { 'NvimTree', 'neo-tree', 'oil', 'minifiles', 'netrw' },
  desc = 'attach the tree entry under the cursor to the active AI backend',
  callback = function()
    map('n', '<leader>av', function()
      require('util.ai').call 'attach_tree'
    end, { buffer = true, desc = 'attach_file' })
  end,
})

-- Keep the cursor centered while navigating
map('n', '<C-d>', '<C-d>zz', { desc = 'page_down' })
map('n', '<C-u>', '<C-u>zz', { desc = 'page_up' })
map('n', '#', '#zz', { desc = 'prev' })
map('n', '*', '*zz', { desc = 'next' })
map('n', 'N', 'Nzzzv', { desc = 'prev' })
map('n', 'n', 'nzzzv', { desc = 'next' })

-- System clipboard, explicitly. The unnamed register stays vim-local.
map({ 'n', 'v' }, '<leader>y', [["+y]], { desc = 'yank_to_clipboard' })
map('n', '<leader>Y', [["+Y]], { desc = 'yank_line_to_clipboard' })
map({ 'n', 'v' }, '<leader>d', [["+d]], { desc = 'delete_to_clipboard' })
map({ 'n', 'v' }, '<leader>D', [["_d]], { desc = 'delete_to_void' })
-- Visual only: `"_d` voids the selection instead of letting it clobber the
-- unnamed register, so `"+P` still pastes the clipboard. There is no useful
-- normal-mode form -- `"+d` there just waits for a motion `P` cannot supply.
map('x', '<leader>P', [["_d"+P]], { desc = 'delete_then_paste_from_clipboard' })
map({ 'n', 'x' }, '<leader>p', [["+p]], { desc = 'paste_from_clipboard' })

-- Files and buffers
map('n', '<leader>s', ':w<cr>', { desc = 'save' })
map('n', '<leader>S', ':w!<cr>', { desc = 'save_force' })
map('n', '<leader>x', ':q<cr>', { desc = 'quit' })
map('n', '<leader>X', ':q!<cr>', { desc = 'quit_force' })
map('n', '<leader>W', ':wq<cr>', { desc = 'save_quit' })
map('n', '<leader>zd', ':bd<cr>', { desc = 'delete_buffer' })
map('n', '<leader>H', ':b#<cr>', { desc = 'buffer_prev' })
map('n', '<leader>ll', ':checktime<cr>', { desc = 'reload_file' })
map('n', '<leader>eF', vim.cmd.Ex, { desc = 'netrw' })

-- Windows
map('n', '<leader>zv', '<cmd>vs<cr>', { desc = 'vertical_split' })
map('n', '<leader>zs', '<cmd>sp<cr>', { desc = 'horizontal_split' })
map('n', '<C-Right>', ':vertical resize +2<cr>', { desc = 'vertical_resize_right' })
map('n', '<C-Left>', ':vertical resize -2<cr>', { desc = 'vertical_resize_left' })
map('n', '<C-Up>', ':resize -2<cr>', { desc = 'vertical_resize_up' })
map('n', '<C-Down>', ':resize +2<cr>', { desc = 'horizontal_resize_down' })
map('t', '<Esc>', '<C-\\><C-n>', { desc = 'exit_terminal' })

-- Spaceless join
map('n', 'J', 'gJ', { desc = 'join_next_line' })

-- Custom TODO comment, prefixed with the user initials
map('n', 'gco', 'o' .. env.TODO_CUSTOM .. ': <esc>:normal gcc<cr>A', { desc = 'add_comment' })

-- cd to the current file's directory
local function cd_to_current_file()
  local file = vim.fn.expand '%:p'
  if file == '' then
    vim.notify('No file to cd to', vim.log.levels.WARN)
    return
  end
  local dir = vim.fn.fnamemodify(file, ':p:h')
  vim.cmd.cd(dir)
  vim.notify('Changed directory to: ' .. dir)
end

map('n', '<leader>ew', cd_to_current_file, { desc = 'cd_to_current_file' })
map('n', '<leader>we', cd_to_current_file, { desc = 'cd_to_current_file' })

-- Reveal the current file in the OS file manager. vim.ui.open picks the right
-- opener per platform, so there is no OS branching to maintain here.
map('n', '<leader>eO', function()
  local path = vim.fn.expand '%:p:h'
  vim.notify('Opening: ' .. path)
  vim.ui.open(path)
end, { desc = 'open_explorer' })

-- Yank the current file's path in various forms
for lhs, spec in pairs {
  ['<leader>eyy'] = { '%:p', 'yank_absolute_path' },
  ['<leader>eyY'] = { '%', 'yank_relative_path' },
  ['<leader>eyf'] = { '%:t', 'yank_filename' },
  ['<leader>eyF'] = { '%:p:h', 'yank_folder' },
} do
  local modifier, desc = spec[1], spec[2]
  map('n', lhs, function()
    local value = vim.fn.expand(modifier)
    vim.fn.setreg('*', value)
    vim.fn.setreg('+', value)
    vim.notify('Yanked: ' .. value)
  end, { desc = desc })
end

-- Copy a terminal buffer's scrollback into a scratch `log` buffer, so the output
-- survives the terminal and can be searched and yanked from normally.
map('n', '<leader>oy', function()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].buftype ~= 'terminal' then
    vim.notify('Not a terminal buffer', vim.log.levels.WARN)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  while #lines > 0 and lines[#lines]:match '^%s*$' do
    table.remove(lines)
  end

  local output_name = vim.api.nvim_buf_get_name(bufnr) .. '.output'
  local target
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(b) == output_name then
      target = b
      break
    end
  end
  target = target or vim.api.nvim_create_buf(true, false)

  vim.bo[target].buftype = 'nofile'
  vim.bo[target].bufhidden = 'hide'
  vim.bo[target].swapfile = false
  vim.bo[target].modifiable = true

  vim.api.nvim_buf_set_lines(target, 0, -1, false, lines)
  vim.api.nvim_buf_set_name(target, output_name)
  vim.api.nvim_set_current_buf(target)
  vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(target), 0 })
  vim.bo[target].filetype = 'log'
end, { desc = 'yank_to_log' })

-- Buffer-local mapping, registered when a file under `pattern` is opened.
-- Grouped and cleared: <leader>iI re-runs this file, and an ungrouped autocmd
-- would stack another copy of every map_local on each reload.
local map_local_group = vim.api.nvim_create_augroup('map_local', { clear = true })

local function map_local(lhs, pattern, rhs, desc)
  vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
    group = map_local_group,
    pattern = pattern,
    callback = function()
      map('n', lhs, rhs, { buffer = true, desc = desc })
    end,
  })
end

local config_dir = vim.fn.stdpath 'config'

map_local('<leader>ii', config_dir .. '/**', function()
  local file = vim.fn.expand '%:p'
  if file == '' then
    vim.notify('No file to source', vim.log.levels.WARN)
    return
  end
  vim.cmd.source(file)
  vim.notify('Sourced config: ' .. file)
end, 'source_config_current_file')

-- init.lua is only the leader vars plus `require 'core'`, so sourcing MYVIMRC
-- reloads nothing -- the require is already cached. Drop the base modules from
-- the cache and re-require them instead. core.lazy and core.lsp are skipped on
-- purpose: re-running lazy.setup and vim.lsp.enable in a live session is not
-- reload-safe.
local BASE_MODULES = {
  'core.options',
  'core.filetypes',
  'core.keymaps',
  'core.autocmds',
  'core.commands',
}

map_local('<leader>iI', config_dir .. '/**', function()
  for name in pairs(package.loaded) do
    if name == 'util' or name:match '^util%.' then
      package.loaded[name] = nil
    end
  end
  for _, name in ipairs(BASE_MODULES) do
    package.loaded[name] = nil
    local ok, err = pcall(require, name)
    if not ok then
      vim.notify('Reload failed in ' .. name .. ': ' .. tostring(err), vim.log.levels.ERROR)
      return
    end
  end
  vim.notify('Reloaded base config: ' .. table.concat(BASE_MODULES, ', '))
end, 'reload_base_config')

-- Reload external tools from their own config files. vim.system is async and
-- takes an argv list, so nothing goes through a shell.
local function reloader(cmd, label)
  return function()
    vim.system(cmd, { text = true }, function(res)
      vim.schedule(function()
        if res.code == 0 then
          vim.notify('Reloaded ' .. label)
        else
          vim.notify('Reload failed for ' .. label .. ': ' .. (res.stderr or ''), vim.log.levels.ERROR)
        end
      end)
    end)
  end
end

map_local(
  '<leader>ii',
  env.XDG_CONFIG_HOME .. '/kitty/**',
  reloader({ 'pkill', '-USR1', 'kitty' }, 'kitty'),
  'reload_external_config'
)

map_local(
  '<leader>ii',
  env.XDG_CONFIG_HOME .. '/tmux/**',
  reloader({ 'tmux', 'source-file', env.XDG_CONFIG_HOME .. '/tmux/tmux.conf' }, 'tmux'),
  'reload_external_config'
)

map_local(
  '<leader>ii',
  env.XDG_CONFIG_HOME .. '/hypr/*',
  reloader({ 'hyprctl', 'reload' }, 'hyprland'),
  'reload_external_config'
)
