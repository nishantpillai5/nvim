return {
  {
    'mawkler/demicolon.nvim',
    -- The `]`/`[` listener has to be watching before the jump it records, so
    -- lazy `keys` on `]` would both miss the session's first jump and, being a
    -- mapping that is also a prefix, sit in front of `]c` and `]t`.
    event = 'VeryLazy',
    dependencies = {
      -- Hard-required by every demicolon module -- it holds the last jump. On
      -- `main` that is a standalone file, so nothing else of textobjects runs.
      { 'nvim-treesitter/nvim-treesitter-textobjects', branch = 'main' },
    },
    opts = {
      -- Upstream also disables `i`, for the built-in `]i`; here `]i` is
      -- neotest's next failed test.
      keymaps = { disabled_keys = { 'p', 'I', 'A', 'f' } },
    },
  },
}
