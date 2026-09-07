return {
  {
    'nvim-telescope/telescope-project.nvim',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    keys = {
      {
        '<leader>wW',
        function()
          require('telescope').load_extension 'project'
          require('telescope').extensions.project.project()
        end,
        desc = 'select_project',
      },
    },
  },
}
