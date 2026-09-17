return {
  {
    'mawkler/demicolon.nvim',
    -- The listener has to be watching before the jump it records, and `]` as a
    -- lazy key would also sit in front of `]c` and `]t`.
    event = 'VeryLazy',
    dependencies = {
      -- Hard-required by every demicolon module: it holds the last jump.
      { 'nvim-treesitter/nvim-treesitter-textobjects', branch = 'main' },
    },
    opts = {
      -- Upstream also disables `i`; here `]i` is neotest's next failed test.
      keymaps = { disabled_keys = { 'p', 'I', 'A', 'f' } },
    },
  },
}
