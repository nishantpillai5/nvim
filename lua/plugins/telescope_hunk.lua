return {
  {
    'nishantpillai5/telescope-git-hunk',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    keys = {
      { '<leader>fgh', '<cmd>Telescope git_hunk<cr>', desc = 'hunks' },
      { '<leader>ghf', '<cmd>Telescope git_hunk<cr>', desc = 'find' },
    },
    config = function()
      require('telescope').load_extension 'git_hunk'
    end,
  },
}
