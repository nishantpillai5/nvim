return {
  {
    'folke/zen-mode.nvim',
    cmd = 'ZenMode',
    keys = {
      {
        '<leader>zz',
        function()
          require('zen-mode').toggle()
        end,
        desc = 'zen',
      },
      {
        '<leader>zZ',
        function()
          require('zen-mode').toggle { window = { width = 1 } }
        end,
        desc = 'zen_full',
      },
    },
    opts = {
      window = { width = 0.95 },
      plugins = {
        options = { enabled = true, laststatus = 3 },
        gitsigns = { enabled = false },
      },
    },
  },
}
