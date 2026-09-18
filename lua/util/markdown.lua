-- <leader>zp toggles in-buffer rendering per buffer, on top of both plugins'
-- global `enabled = false`; <leader>zP is the browser preview.
local M = {}

-- snacks.image has no detach and redraws after any edit, so only losing the
-- buffer clears it -- at the cost of its marks and undo.
local function detach_images()
  local file = vim.api.nvim_buf_get_name(0)
  local win = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(win)
  local old = vim.api.nvim_get_current_buf()
  -- Park the window on a scratch first: wiping a buffer closes every window
  -- showing it, and the :edit below would then evict a split's other file.
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.bo[scratch].bufhidden = 'wipe'
  vim.api.nvim_win_set_buf(win, scratch)
  vim.api.nvim_buf_delete(old, { force = true })
  vim.cmd.edit(vim.fn.fnameescape(file))
  pcall(vim.api.nvim_win_set_cursor, win, cursor)
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
    -- Window-local so it survives the buffer wipe in detach_images().
    vim.w.md_wrap = vim.wo.wrap
    vim.wo.wrap = true
    attach_images()
    vim.b[buf].md_render = true
  else
    Snacks.image.config.enabled = false
    detach_images()
    if vim.w.md_wrap ~= nil then
      vim.wo.wrap = vim.w.md_wrap
      vim.w.md_wrap = nil
    end
  end
end

return M
