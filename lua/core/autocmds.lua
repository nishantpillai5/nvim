local augroup = function(name)
  return vim.api.nvim_create_augroup('core_' .. name, { clear = true })
end

-- Don't continue comments onto new lines. FileType, because ftplugins set
-- formatoptions and would otherwise win.
vim.api.nvim_create_autocmd('FileType', {
  group = augroup 'formatoptions',
  desc = 'disable auto-commenting new lines',
  callback = function()
    vim.opt_local.formatoptions:remove { 'c', 'r', 'o' }
  end,
})

-- Restore the last cursor position in a reopened file
vim.api.nvim_create_autocmd('BufReadPost', {
  group = augroup 'last_place',
  desc = 'remember last cursor place',
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Pick up files changed on disk (by git, a formatter, another editor)
local checktime = augroup 'checktime'
vim.api.nvim_create_autocmd('FocusGained', {
  group = checktime,
  desc = 'reload files from disk when nvim regains focus',
  command = "if getcmdwintype() == '' | checktime | endif",
})
vim.api.nvim_create_autocmd('BufEnter', {
  group = checktime,
  desc = 'check an unmodified buffer for on-disk changes when entering it',
  command = "if &buftype == '' && !&modified && expand('%') != '' | exec 'checktime ' . expand('<abuf>') | endif",
})

-- Terminals
local term = augroup 'terminal'
vim.api.nvim_create_autocmd('TermClose', {
  group = term,
  desc = 'leave insert mode when a terminal exits',
  callback = function()
    vim.cmd.stopinsert()
  end,
})

vim.api.nvim_create_autocmd('BufEnter', {
  group = term,
  pattern = 'term://*',
  desc = 'jump to newest output in normal mode so scrollback stays readable',
  callback = function()
    -- Deferred, in case we immediately switch back out of the buffer.
    vim.defer_fn(function()
      if vim.bo.buftype ~= 'terminal' then
        return
      end
      -- Agent terminals manage their own insert and scroll behaviour --
      -- claudecode.lua pins unfocused windows to the newest output, omp.lua
      -- keeps its panel readable -- so leave them alone. util.ai matches on the
      -- command's basename rather than a substring, which is what keeps `omp`
      -- from matching docker-compose.
      if require('util.ai').is_agent_terminal(0) then
        return
      end
      vim.cmd.stopinsert()
      local line_count = vim.api.nvim_buf_line_count(0)
      if line_count > 0 then
        vim.api.nvim_win_set_cursor(0, { line_count, 0 })
      end
    end, 100)
  end,
})
