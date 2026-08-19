return {
  {
    'Mofiqul/vscode.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      local c = require('vscode.colors').get_colors()

      require('vscode').setup {
        transparent = true,
        italic_comments = true,
        group_overrides = {
          -- https://github.com/Mofiqul/vscode.nvim/blob/main/lua/vscode/colors.lua
          DiagnosticError = { fg = c.vscRed, bg = c.vscPopupHighlightGray },
          DiagnosticInfo = { fg = c.vscBlue, bg = c.vscPopupHighlightGray },
          DiagnosticHint = { fg = c.vscBlue, bg = c.vscPopupHighlightGray },
          DashboardHeader = { fg = c.vscGreen },
        },
      }

      vim.cmd.colorscheme 'vscode'

      -- Recolor the window separator to match the current mode.
      vim.api.nvim_create_autocmd('ModeChanged', {
        group = vim.api.nvim_create_augroup('theme_separator', { clear = true }),
        callback = function(args)
          local mode = args.match:match '.:(%a)'
          if mode then
            require('util.theme').highlight_separator(mode)
          end
        end,
      })
    end,
  },
}
