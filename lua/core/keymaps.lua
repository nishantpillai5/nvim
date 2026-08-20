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
map({ 'n', 'x' }, '<leader>P', [["+dP]], { desc = 'delete_then_paste_from_clipboard' })
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
local function map_local(lhs, pattern, rhs, desc)
  vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
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

map_local('<leader>iI', config_dir .. '/**', function()
  vim.cmd.source(vim.env.MYVIMRC)
  vim.notify('Sourced full config: ' .. vim.env.MYVIMRC)
end, 'source_config_full')

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
