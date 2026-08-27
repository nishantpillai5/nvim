-- Breakpoints that survive a restart. They are stored per project and restored
-- on BufReadPost, which is why this loads on file-open rather than on its keys
-- -- and why nvim-dap comes with it, since restoring goes through dap's API.
return {
  {
    'Weissle/persistent-breakpoints.nvim',
    dependencies = { 'mfussenegger/nvim-dap' },
    event = { 'BufReadPre', 'BufNewFile' },
    keys = {
      {
        'mb',
        function()
          require('persistent-breakpoints.api').toggle_breakpoint()
        end,
        desc = 'breakpoint',
      },
      {
        'mB',
        function()
          require('persistent-breakpoints.api').set_conditional_breakpoint()
        end,
        desc = 'breakpoint_conditional',
      },
    },
    -- Also available, unmapped: clear_all_breakpoints(), set_log_point().
    opts = {
      load_breakpoints_event = { 'BufReadPost' },
    },
  },
}
