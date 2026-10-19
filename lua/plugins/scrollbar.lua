return {
  {
    'petertriho/nvim-scrollbar',
    -- v2 lands on main on 2026-11-16; drop this line then.
    branch = 'refactor/v2',
    event = 'BufReadPre',
    config = function()
      local c = require('vscode.colors').get_colors()
      ---@diagnostic disable-next-line: undefined-field
      require('scrollbar').setup {
        providers = { gitsigns = true },
        scrollbar = {
          thumb = { highlight = { bg = c.vscPopupHighlightGray } },
        },
        marks = {
          Search = { text = { '', '' }, highlight = { fg = c.vscViolet } },
          Error = { text = { '', '' }, highlight = { fg = c.vscRed } },
          Warn = { text = { '', '' }, highlight = { fg = c.vscOrange } },
          Info = { text = { '', '' }, highlight = { fg = c.vscYellow } },
          Hint = { text = { '', '' }, highlight = { fg = c.vscYellow } },
          Misc = { text = { '-', '=' }, highlight = { fg = c.vscYellow } },
          GitAdd = { text = '▌', highlight = { fg = c.vscGreen } },
          GitChange = { text = '▌', highlight = { fg = c.vscYellow } },
          GitDelete = { text = '▌', highlight = { fg = c.vscRed } },
        },
      }

      -- v2 draws a float without `border`, so it inherits our winborder=rounded.
      vim.api.nvim_create_autocmd('WinNew', {
        group = vim.api.nvim_create_augroup('scrollbar_no_border', { clear = true }),
        callback = vim.schedule_wrap(function()
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.w[win].scrollbar_owned and vim.api.nvim_win_get_config(win).border ~= 'none' then
              vim.api.nvim_win_set_config(win, { border = 'none' })
            end
          end
        end),
      })
    end,
  },
}
