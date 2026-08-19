-- NOTE: needs a treesitter parser for the buffer's language. nvim-treesitter is
-- pulled in as a dependency but is not configured in this config yet, so only
-- the parsers Neovim bundles will split/join.
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
