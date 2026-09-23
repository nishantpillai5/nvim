-- <leader>zp toggles in-buffer rendering per buffer, on top of both plugins'
-- global `enabled = false`; <leader>zP is the browser preview.
local M = {}

-- snacks.image has no detach and redraws after any edit, so only losing the
-- buffer clears it -- at the cost of its marks and undo.
local function detach_images()
  local old = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(old)
  local cursor = vim.api.nvim_win_get_cursor(0)
  -- A placeholder keeps the windows open: a bare wipe closes them, and :edit
  -- then lands in whatever window is left (e.g. a terminal split).
  local tmp = vim.api.nvim_create_buf(false, true)
  vim.bo[tmp].bufhidden = 'wipe'
  local wins = vim.fn.win_findbuf(old)
  for _, win in ipairs(wins) do
    vim.api.nvim_win_set_buf(win, tmp)
  end
  vim.api.nvim_buf_delete(old, { force = true })
  vim.cmd.edit(vim.fn.fnameescape(file))
  local new = vim.api.nvim_get_current_buf()
  for _, win in ipairs(wins) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_buf(win, new)
    end
  end
  pcall(vim.api.nvim_win_set_cursor, 0, cursor)
end

local function attach_images()
  local buf = vim.api.nvim_get_current_buf()
  -- Both before the attach: doc.attach() returns early while enabled is false.
  Snacks.image.config.enabled = true
  require('snacks.image').setup()
  -- snacks' "already attached" guard, which survives a :edit.
  vim.b[buf].snacks_image_attached = nil
  Snacks.image.doc.attach(buf)
end

function M.toggle()
  local buf = vim.api.nvim_get_current_buf()
  local on = not vim.b[buf].md_render

  if not on and vim.bo.modified then
    vim.notify('Write the buffer before turning the preview off', vim.log.levels.WARN)
    return
  end

  -- The API is in render-markdown.api; the root module only has setup.
  require('render-markdown.api').set_buf(on)

  if on then
    attach_images()
    vim.b[buf].md_render = true
    -- Local to this buffer in this window; the reload on toggle-off drops it.
    vim.wo[0][0].wrap = true
    vim.wo[0][0].linebreak = true
  else
    Snacks.image.config.enabled = false
    detach_images()
  end
end

return M
