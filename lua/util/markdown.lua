-- <leader>zp turns every in-buffer markdown renderer on and off together:
-- render-markdown for headings, tables, code blocks and checkboxes, snacks.image
-- for inline images, and nabla for LaTeX equations. <leader>zP is the separate
-- browser preview and is not touched here.
--
-- State is per buffer, because two of the three attach per buffer. The
-- exception is render-markdown, whose toggle is global: `rm_on` mirrors it so it
-- is only flipped when it actually disagrees with what this buffer wants, which
-- leaves it following whichever buffer toggled last.
local M = {}

local rm_on = false

local function set_render_markdown(want)
  if rm_on ~= want then
    require('render-markdown').toggle()
    rm_on = want
  end
end

-- snacks.image has no detach. doc.attach() guards on a buffer-local flag, the
-- inline renderer holds an nvim_buf_attach whose on_lines redraws images after
-- any edit, and nothing rechecks config.enabled once a buffer is attached -- so
-- turning images off means losing the buffer they are drawn in. Reopening the
-- file is the only reliable way back, and it costs that buffer's marks, undo
-- history and jumplist.
local function detach_images()
  local file = vim.api.nvim_buf_get_name(0)
  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.cmd.bwipeout()
  vim.cmd.edit(vim.fn.fnameescape(file))
  -- The file can come back shorter than it was when the buffer was wiped.
  pcall(vim.api.nvim_win_set_cursor, 0, cursor)
end

local function attach_images()
  local buf = vim.api.nvim_get_current_buf()
  -- The flag is snacks' "already attached" guard, and it survives a :edit -- so
  -- reopening the file alone would never re-attach.
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

  set_render_markdown(on)
  -- nabla's own state is per buffer, so it tracks md_render without a mirror.
  require('nabla').toggle_virt()

  -- setup() registers the FileType hook only while config.enabled is true, and
  -- no-ops after its first call. snacks loads on VeryLazy, i.e. after the first
  -- BufReadPre, so leaving this to snacks' own trigger would miss the file nvim
  -- was started on -- and would render images with no key pressed. Hence
  -- `image.enabled = false` in the snacks spec and this call here.
  Snacks.image.config.enabled = true
  require('snacks.image').setup()
  Snacks.image.config.enabled = on

  if on then
    attach_images()
    vim.b[buf].md_render = true
  else
    -- The wipe drops md_render with the buffer, which is the state we want.
    detach_images()
  end
end

return M
