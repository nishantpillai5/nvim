-- NOTE: needs a treesitter parser for the buffer's language. plugins/treesitter.lua
-- installs the list this config cares about; anything outside it, plus whatever
-- Neovim bundles, will not split/join.
return {
  {
    'Wansmer/treesj',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    keys = {
      {
        -- Was '<space>J' in the old config; identical, leader is space.
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
