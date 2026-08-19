return {
  {
    'akinsho/git-conflict.nvim',
    version = '*',
    cmd = { 'GitConflictPrevConflict', 'GitConflictNextConflict' },
    keys = {
      { '<leader>gxo', '<Plug>(git-conflict-ours)', desc = 'ours' },
      { '<leader>gxt', '<Plug>(git-conflict-theirs)', desc = 'theirs' },
      { '<leader>gxb', '<Plug>(git-conflict-both)', desc = 'both' },
      { '<leader>gxn', '<Plug>(git-conflict-none)', desc = 'none' },
      -- Plain searches for the marker; the plugin's own motions were unreliable.
      { '[x', '?<<<<<<<<cr>', desc = 'conflict' },
      { ']x', '/<<<<<<<<cr>', desc = 'conflict' },
    },
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      default_mappings = false,
      default_commands = true,
      disable_diagnostics = true,
    },
  },
}
