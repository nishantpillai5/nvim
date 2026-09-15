-- Written by the Dockerfile; absent on the host, where mmdc drives puppeteer's
-- own browser with its own defaults.
local PUPPETEER_CONFIG = '/etc/mermaid-puppeteer.json'

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
      -- util.markdown turns it on for <leader>zp. Needs `magick`, `mmdc` for
      -- mermaid, and `tectonic` or `pdflatex` plus the latex parser for math --
      -- `:checkhealth snacks`.
      image = {
        enabled = false,
        convert = {
          -- snacks' own default arguments, plus `-p` where the container's
          -- puppeteer settings exist. Replaces rather than extends, so the
          -- background/theme/scale half has to be repeated.
          mermaid = function()
            local theme = vim.o.background == 'light' and 'neutral' or 'dark'
            local args = { '-i', '{src}', '-o', '{file}', '-b', 'transparent', '-t', theme, '-s', '{scale}' }
            if vim.uv.fs_stat(PUPPETEER_CONFIG) then
              vim.list_extend(args, { '-p', PUPPETEER_CONFIG })
            end
            return args
          end,
        },
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
