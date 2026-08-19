return {
  {
    'jemag/telescope-diff.nvim',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    keys = {
      {
        '<leader>ed',
        function()
          require('telescope').load_extension 'diff'
          require('telescope').extensions.diff.diff_current { hidden = true, no_ignore = true }
        end,
        desc = 'diff_file_current',
      },
      {
        '<leader>eD',
        function()
          require('telescope').load_extension 'diff'
          require('telescope').extensions.diff.diff_files { hidden = true, no_ignore = true }
        end,
        desc = 'diff_file_select_both',
      },
    },
  },
}
