return {
  {
    'smoka7/hop.nvim',
    cmd = { 'HopChar2', 'HopNodes' },
    keys = {
      { 's', '<cmd>HopChar2<cr>', mode = 'n', desc = 'hop_char' },
      { 'S', '<cmd>HopNodes<cr>', mode = 'n', desc = 'hop_node' },
    },
    opts = {
      multi_windows = true,
      uppercase_labels = true,
      jump_on_sole_occurrence = false,
    },
  },
}
