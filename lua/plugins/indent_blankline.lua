return {
  {
    'lukas-reineke/indent-blankline.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = { 'HiPhish/rainbow-delimiters.nvim' },
    config = function()
      local highlight = {
        'RainbowRed',
        'RainbowYellow',
        'RainbowBlue',
        'RainbowOrange',
        'RainbowGreen',
        'RainbowViolet',
        'RainbowCyan',
      }

      local hooks = require 'ibl.hooks'
      -- Registered as a hook so the groups survive a colorscheme change.
      hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        for name, fg in pairs {
          RainbowRed = '#E06C75',
          RainbowYellow = '#E5C07B',
          RainbowBlue = '#61AFEF',
          RainbowOrange = '#D19A66',
          RainbowGreen = '#98C379',
          RainbowViolet = '#C678DD',
          RainbowCyan = '#56B6C2',
        } do
          vim.api.nvim_set_hl(0, name, { fg = fg })
        end
      end)

      vim.g.rainbow_delimiters = {
        highlight = highlight,
        -- Only run where a treesitter parser actually exists, otherwise
        -- rainbow-delimiters errors on unparsed buffers.
        condition = function(bufnr)
          local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
          if not lang then
            return false
          end
          local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
          return ok and parser ~= nil
        end,
      }

      require('ibl').setup {
        scope = { highlight = highlight },
        exclude = { filetypes = { 'dashboard' } },
      }

      hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
    end,
  },
}
