return {
  {
    'nvim-treesitter/nvim-treesitter-context',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    keys = {
      {
        '<leader>zc',
        function()
          require('treesitter-context').toggle()
        end,
        desc = 'context_sticky',
      },
    },
  },
}
