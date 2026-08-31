return {
  {
    'petertriho/nvim-scrollbar',
    event = 'BufReadPre',
    config = function()
      local c = require('vscode.colors').get_colors()
      -- scrollbar/init.lua requires scrollbar.utils and scrollbar.handlers,
      -- which require it back, so lua_ls resolves the module through the cycle
      -- to an `M` that has no fields on it yet. `setup` is there at runtime.
      ---@diagnostic disable-next-line: undefined-field
      require('scrollbar').setup {
        handle = { color = c.vscPopupHighlightGray },
        marks = {
          Search = { text = { '', '' }, color = c.vscViolet },
          Error = { text = { '', '' }, color = c.vscRed },
          Warn = { text = { '', '' }, color = c.vscOrange },
          Info = { text = { '', '' }, color = c.vscYellow },
          Hint = { text = { '', '' }, color = c.vscYellow },
          Misc = { text = { '-', '=' }, color = c.vscYellow },
          GitAdd = { text = '▌', color = c.vscGreen },
          GitChange = { text = '▌', color = c.vscYellow },
          GitDelete = { text = '▌', color = c.vscRed },
        },
      }
    end,
  },
}
