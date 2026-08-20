-- Pins the enclosing lines -- function, class, block -- to the top of the
-- window. Reads the tree, so it needs a parser from plugins/treesitter.lua.
return {
  {
    'nvim-treesitter/nvim-treesitter-context',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    keys = {
      {
        -- The old config's `:TSContextToggle` no longer exists upstream; the
        -- command is now `:TSContext toggle`, and this is what it calls.
        '<leader>zc',
        function()
          require('treesitter-context').toggle()
        end,
        desc = 'context_sticky',
      },
    },
  },
}
