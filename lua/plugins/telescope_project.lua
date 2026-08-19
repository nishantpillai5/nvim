return {
  {
    'nvim-telescope/telescope-project.nvim',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    keys = {
      {
        -- The old config's key table said <leader>wN, but it bound <leader>wW;
        -- <leader>wN is neoscopes' clear-scope.
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
