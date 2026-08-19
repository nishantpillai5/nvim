return {
  {
    'nvim-zh/colorful-winsep.nvim',
    event = 'WinLeave',
    config = function()
      require('colorful-winsep').setup {
        animate = { enabled = false },
      }
      require('util.theme').highlight_separator 'n'
    end,
  },
}
