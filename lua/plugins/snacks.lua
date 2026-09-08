return {
  {
    'folke/snacks.nvim',
    -- Its health check asks for both. snacks owns vim.ui.input and
    -- vim.ui.select, which on VeryLazy were still Neovim's until startup ended.
    lazy = false,
    priority = 1000,
    opts = {
      input = { enabled = true },
      picker = { enabled = true, ui_select = true },
      -- Inline images and equations, via the kitty graphics protocol. Off here;
      -- util.markdown turns it on for <leader>zp. Needs `magick`, and `tectonic`
      -- or `pdflatex` plus the latex parser for math -- `:checkhealth snacks`.
      image = {
        enabled = false,
        math = {
          enabled = true,
          -- xcolor is the addition: snacks' template emits `\color[HTML]{<hex>}`
          -- without loading it, which typesets as literal text. The rest is its
          -- own default list, repeated because this replaces rather than extends.
          latex = { packages = { 'xcolor', 'amsmath', 'amssymb', 'amsfonts', 'amscd', 'mathtools' } },
        },
      },
    },
  },
}
