return {
  {
    'kevinhwang91/nvim-hlslens',
    event = 'BufReadPre',
    dependencies = { 'petertriho/nvim-scrollbar' },
    config = function()
      require('scrollbar.handlers.search').setup {
        override_lens = function() end,
      }
    end,
  },
}
