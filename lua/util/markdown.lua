-- <leader>zp toggles the in-buffer markdown rendering: render-markdown for the
-- text, snacks.image for images, equations and mermaid. Per buffer, on top of
-- both plugins' global `enabled = false`. <leader>zP is the browser preview.
local M = {}

-- snacks.image has no detach, and its inline renderer redraws after any edit,
-- so only losing the buffer clears it -- at the cost of its marks and undo.
local function detach_images()
  local file = vim.api.nvim_buf_get_name(0)
  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.cmd.bwipeout()
  vim.cmd.edit(vim.fn.fnameescape(file))
  pcall(vim.api.nvim_win_set_cursor, 0, cursor)
end

local function attach_images()
  local buf = vim.api.nvim_get_current_buf()
  -- Both before the attach: doc.attach() returns early while enabled is false,
  -- and setup() registers its FileType hook only while it is true.
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
  else
    Snacks.image.config.enabled = false
    detach_images()
  end
end

return M
