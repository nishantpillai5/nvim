return {
  {
    'folke/snacks.nvim',
    event = 'VeryLazy',
    opts = {
      input = { enabled = true },
      picker = { enabled = true, ui_select = true },
      -- Inline images in markdown, drawn with the kitty graphics protocol.
      -- Deliberately off: `util.markdown` enables it and calls the module's
      -- setup itself, so images appear on <leader>zp rather than on open.
      -- Needs `magick` on PATH for anything that is not a PNG.
      image = {
        enabled = false,
        -- nabla owns equations, on the same key. snacks' math also wants
        -- `tectonic` or `pdflatex`, neither of which is installed here.
        math = { enabled = false },
      },
    },
  },
}
