-- Written by the Dockerfile; absent on the host.
local PUPPETEER_CONFIG = '/etc/mermaid-puppeteer.json'

return {
  {
    'folke/snacks.nvim',
    -- On VeryLazy, vim.ui.input and vim.ui.select stayed Neovim's until
    -- startup ended, which its health check reports.
    lazy = false,
    priority = 1000,
    -- snacks' probe cannot see kitty through tmux; KITTY_PID survives the pane.
    init = function()
      if vim.env.KITTY_PID and vim.env.TMUX then
        vim.env.SNACKS_KITTY = '1'
      end
    end,
    opts = {
      input = { enabled = true },
      picker = { enabled = true, ui_select = true },
      -- Off here; util.markdown turns it on for <leader>zp. Needs `magick`,
      -- `mmdc` and a latex toolchain -- `:checkhealth snacks`.
      image = {
        enabled = false,
        doc = {
          -- Cells, not pixels; the default 80x40 is most of the window.
          max_width = 50,
          max_height = 16,
          -- A plain `false` will not do: snacks wraps it in a closure that
          -- returns itself, which is truthy.
          conceal = function()
            return false
          end,
        },
        convert = {
          magick = {
            -- Transparent border: 18px at 192dpi is about a cell of gap.
            math = { '-density', 192, '{src}[{page}]', '-trim', '+repage', '-bordercolor', 'none', '-border', '18x0' },
          },
          -- Replaces rather than extends, so the defaults are repeated.
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
          latex = {
            -- xcolor is the addition: snacks' template emits
            -- `\color[HTML]{<hex>}` without loading it. Replaces, not extends.
            packages = { 'xcolor', 'amsmath', 'amssymb', 'amsfonts', 'amscd', 'mathtools' },
          },
        },
      },
    },
  },
}
