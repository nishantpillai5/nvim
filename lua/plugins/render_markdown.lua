return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = 'markdown',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    keys = {
      {
        '<leader>zp',
        function()
          require('util.markdown').toggle()
        end,
        ft = 'markdown',
        desc = 'render_markdown',
      },
    },
    opts = {
      -- Off until <leader>zp asks; the plugin's default renders on open.
      enabled = false,
      -- snacks draws the equations; this would put latex2text text over them.
      latex = { enabled = false },
    },
  },
}
