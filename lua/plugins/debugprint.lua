-- `_G.custom_debug_log` lets a project-local exrc file add filetype templates.
return {
  {
    'andrewferrier/debugprint.nvim',
    cmd = {
      'SearchDebugPrints',
      'ToggleCommentDebugPrints',
      'DeleteDebugPrints',
      'ResetDebugPrintsCounter',
    },
    keys = {
      -- Bound by debugprint itself via the `keymaps` option below; listed here
      -- so lazy loads the plugin when they're first pressed.
      { '<leader>gcc', mode = { 'n', 'x' }, desc = 'variable' },
      { '<leader>gcC', mode = { 'n', 'x' }, desc = 'variable_above' },
      { '<leader>gco', desc = 'plain' },
      { '<leader>gcO', desc = 'plain_above' },
      { '<leader>gcx', desc = 'toggle' },
      { '<leader>gcX', desc = 'delete' },
      -- Command wrappers.
      { '<leader>gcf', '<cmd>SearchDebugPrints<cr>', desc = 'search' },
      { '<leader>gct', '<cmd>ToggleCommentDebugPrints<cr>', desc = 'toggle' },
      { '<leader>gcd', '<cmd>DeleteDebugPrints<cr>', desc = 'delete' },
      { '<leader>gcr', '<cmd>ResetDebugPrintsCounter<cr>', desc = 'reset' },
    },
    opts = function()
      return {
        filetypes = _G.custom_debug_log or {},
        keymaps = {
          normal = {
            variable_below = '<leader>gcc',
            variable_above = '<leader>gcC',
            plain_below = '<leader>gco',
            plain_above = '<leader>gcO',
            toggle_comment_debug_prints = '<leader>gcx',
            delete_debug_prints = '<leader>gcX',
            variable_below_alwaysprompt = nil,
            variable_above_alwaysprompt = nil,
          },
          visual = {
            variable_below = '<leader>gcc',
            variable_above = '<leader>gcC',
          },
        },
      }
    end,
  },
}
