return {
  {
    'norcalli/nvim-colorizer.lua',
    event = 'VeryLazy',
    config = function()
      require('colorizer').setup(
        { 'lua', 'css', 'javascript', html = { mode = 'foreground' } },
        { mode = 'background' }
      )
    end,
  },
}
