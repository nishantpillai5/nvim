-- Scoped finding. The pickers in telescope.lua read the active scope at call
-- time via util.scope, so nothing here rebinds keymaps.
return {
  {
    'smartpde/neoscopes',
    event = 'VeryLazy',
    dependencies = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope.nvim' },
    keys = {
      {
        '<leader>wn',
        function()
          require('util.scope').select()
        end,
        desc = 'select_scope',
      },
      {
        '<leader>wN',
        function()
          require('util.scope').clear()
        end,
        desc = 'close_scope',
      },
    },
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('neoscopes').setup {
        neoscopes_config_filename = _G.scope_config_file,
        enable_scopes_from_npm = true,
      }

      -- Only auto-open the scope picker if a project asked for it.
      if _G.workspace_load_on_init then
        require('util.scope').select()
      end
    end,
  },
}
