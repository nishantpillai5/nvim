return {
  {
    'akinsho/git-conflict.nvim',
    version = '*',
    -- Loaded on file open, not just on its own commands: the plugin's whole job
    -- is to detect conflict markers as a buffer is read and highlight them.
    -- Lazy-loading on the nav commands alone meant a conflicted file opened with
    -- no highlighting, and the first <leader>gx* press only loaded the plugin.
    event = { 'BufReadPre', 'BufNewFile' },
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
