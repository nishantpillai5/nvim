return {
  {
    'code-biscuits/nvim-biscuits',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      default_config = {
        prefix_string = '  ',
        toggle_keybind = '<leader>zC',
        show_on_start = false,
      },
    },
  },
}
