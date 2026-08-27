return {
  {
    'nishantpillai5/git-blame.nvim',
    event = 'BufReadPost',
    keys = {
      { '<leader>goc', '<cmd>GitBlameOpenCommitURL<cr>', mode = { 'n', 'v' }, desc = 'commit' },
      { '<leader>gof', '<cmd>GitBlameOpenFileURL<cr>', mode = { 'n', 'v' }, desc = 'file' },
      {
        '<leader>gv',
        function()
          vim.g.gitblame_display_virtual_text = vim.g.gitblame_display_virtual_text == 0 and 1 or 0
        end,
        desc = 'virtual_blame',
      },
      {
        '<leader>zg',
        function()
          vim.g.gitblame_display_virtual_text = vim.g.gitblame_display_virtual_text == 0 and 1 or 0
        end,
        desc = 'git_virtual_blame',
      },
    },
    init = function()
      -- Must be set before the plugin loads.
      vim.g.gitblame_display_virtual_text = 0
      vim.g.gitblame_date_format = '%r'
      vim.g.gitblame_highlight_group = 'GitSignsCurrentLineBlame'
    end,
  },
}
