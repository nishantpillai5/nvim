return {
  {
    'smartpde/neoscopes',
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
    -- The startup picker is opt-in per project, so it loads by hand rather than
    -- through an `event` that would fire everywhere.
    init = function()
      vim.api.nvim_create_autocmd('User', {
        pattern = 'VeryLazy',
        once = true,
        callback = function()
          if _G.workspace_load_on_init then
            require('util.scope').select()
          end
        end,
      })
    end,
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('neoscopes').setup {
        neoscopes_config_filename = _G.scope_config_file,
        enable_scopes_from_npm = true,
      }
    end,
  },
}
