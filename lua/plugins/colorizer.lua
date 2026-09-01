return {
  {
    'catgoose/nvim-colorizer.lua',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      require('colorizer').setup {
        filetypes = { 'lua', 'css', 'javascript', html = { display = { mode = 'foreground' } } },
        options = { display = { mode = 'background' } },
      }
    end,
  },
}
