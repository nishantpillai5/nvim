-- PANEL_POSITION was a global env knob; only toggleterm and overseer read it,
-- and each now keeps its own constant.
local DIRECTION = 'horizontal' -- 'horizontal' | 'vertical'

return {
  {
    'akinsho/nvim-toggleterm.lua',
    cmd = { 'ToggleTerm', 'TermExec' },
    keys = {
      {
        '<leader>o;',
        function()
          -- Always target terminal 1, so the key is a true toggle.
          vim.cmd [[exe 1 . "ToggleTerm"]]
        end,
        desc = 'toggle',
      },
    },
    opts = {
      direction = DIRECTION,
      size = function(term)
        if term.direction == 'horizontal' then
          return vim.o.lines * 0.30
        elseif term.direction == 'vertical' then
          return vim.o.columns * 0.30
        end
      end,
      close_on_exit = false,
      start_in_insert = false,
      hide_numbers = true,
      persist_size = false,
      auto_scroll = false,
    },
  },
}
