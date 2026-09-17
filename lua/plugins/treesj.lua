return {
  {
    'Wansmer/treesj',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    keys = {
      {
        '<leader>J',
        function()
          require('treesj').toggle()
        end,
        desc = 'code_join',
      },
    },
    opts = {
      use_default_keymaps = false,
    },
  },
}
