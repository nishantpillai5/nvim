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
      -- Off until <leader>zp asks for it, so editing a note is the raw text and
      -- rendering is a preview you turn on -- the same shape as <leader>zP.
      -- The plugin's own default is to render every markdown buffer on open.
      enabled = false,
      -- nabla owns equations, on the same key. render-markdown's LaTeX support
      -- shells out to latex2text and would draw over the same expressions.
      latex = { enabled = false },
    },
  },
}
