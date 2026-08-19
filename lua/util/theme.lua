local M = {}

-- Tints the window separator by current mode. Called from the ModeChanged
-- autocmd in plugins/colorscheme.lua and by colorful-winsep on load.
-- `vscode.colors` is required lazily so this module stays safe to load early.
function M.highlight_separator(mode)
  local c = require('vscode.colors').get_colors()

  local by_mode = {
    n = c.vscAccentBlue,
    i = c.vscBlueGreen,
    v = c.vscDarkYellow,
    V = c.vscDarkYellow,
    c = c.vscYellow,
    o = c.vscYellow,
    r = c.vscYellow,
    s = c.vscYellow,
    t = c.vscBlueGreen,
  }

  vim.api.nvim_set_hl(0, 'NvimSeparator', { fg = by_mode[mode] or c.vscAccentBlue })

  if mode == 'c' then
    vim.cmd.redraw()
  end
end

return M
