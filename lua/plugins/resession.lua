-- Sessions, named after the active neoscopes scope when there is one so each
-- scope keeps its own layout.
local function scoped(action)
  return function()
    action(require('util.scope').name() or 'workspace')
  end
end

return {
  {
    'stevearc/resession.nvim',
    dependencies = { 'cbochs/grapple.nvim' },
    keys = {
      {
        '<leader>ws',
        function()
          scoped(require('resession').save)()
        end,
        desc = 'save_session',
      },
      {
        '<leader>wl',
        function()
          scoped(require('resession').load)()
        end,
        desc = 'load_session',
      },
      {
        '<leader>wS',
        function()
          require('resession').save()
        end,
        desc = 'save_manual_session',
      },
      {
        '<leader>wL',
        function()
          require('resession').load()
        end,
        desc = 'load_manual_session',
      },
      {
        '<leader>wd',
        function()
          require('resession').delete()
        end,
        desc = 'delete_session',
      },
    },
    opts = {
      extensions = {
        -- overseer v2 moved the bundle feature's `autostart_on_load` here, and
        -- the extension's config is now { autostart_on_load, filter } -- the
        -- old `recent_first` was a list_tasks option that no longer exists.
        -- Without this, loading a session restarts every task it restores.
        overseer = { autostart_on_load = false },
      },
    },
  },
}
