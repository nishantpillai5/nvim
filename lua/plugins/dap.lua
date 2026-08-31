-- Debugging. nvim-dap only speaks the Debug Adapter Protocol; the adapters
-- themselves are separate binaries, installed through Mason -- see
-- MASON_PACKAGES in core/lsp.lua.
--
-- The F-key row mirrors VSCode: F4 step over, F5 continue/start, F6 step into,
-- F8 step out, F9 pause, C-F5 stop.

-- Steps that announce themselves, the way the old config did -- without a
-- notification there is no feedback when the step lands off-screen.
local function step(fn, label)
  return function()
    vim.notify('DAP: ' .. label)
    require('dap')[fn]()
  end
end

-- Telescope's dap pickers. load_extension is idempotent and telescope may not
-- be loaded when dap's config runs, so it happens on first use instead.
local function picker(name)
  return function()
    require('telescope').load_extension 'dap'
    require('telescope').extensions.dap[name]()
  end
end

local function toggle_virtual_text()
  require('nvim-dap-virtual-text').toggle()
end

return {
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      'ofirgall/goto-breakpoints.nvim',
      'theHamsta/nvim-dap-virtual-text',
      'nvim-telescope/telescope-dap.nvim',
      'stevearc/overseer.nvim',
    },
    keys = {
      {
        '<F4>',
        function()
          require('dap').step_over()
        end,
        desc = 'debug_step_over',
      },
      {
        '<F5>',
        function()
          require('dap').continue()
        end,
        desc = 'debug_continue/start',
      },
      { '<C-F5>', step('terminate', 'Stop'), desc = 'debug_stop' },
      { '<F6>', step('step_into', 'Step Into'), desc = 'debug_step_into' },
      { '<F8>', step('step_out', 'Step Out'), desc = 'debug_step_out' },
      { '<F9>', step('pause', 'Pause'), desc = 'debug_pause' },

      {
        '[b',
        function()
          require('goto-breakpoints').prev()
        end,
        desc = 'breakpoint',
      },
      {
        ']b',
        function()
          require('goto-breakpoints').next()
        end,
        desc = 'breakpoint',
      },

      { '<leader>fbb', picker 'list_breakpoints', desc = 'breakpoint' },
      { '<leader>fbc', picker 'configurations', desc = 'configurations' },
      { '<leader>fbv', picker 'variables', desc = 'variables' },
      { '<leader>fbf', picker 'frames', desc = 'frames' },

      { '<leader>zb', toggle_virtual_text, desc = 'debug_virtual' },
      { '<leader>bz', toggle_virtual_text, desc = 'virtual_text_toggle' },
    },
    config = function()
      local dap = require 'dap'

      -- dap.continue() offers the project's .vscode/launch.json configurations by
      -- itself (its "dap.launch.json" config provider), so nothing has to load
      -- them here -- but it decodes them with vim.json.decode, which rejects the
      -- comments and trailing commas VSCode allows. overseer's decoder does not.
      require('dap.ext.vscode').json_decode = require('overseer.json').decode

      -- overseer's own opts set `dap = false`, so it is patched here instead --
      -- that routes preLaunchTask/postDebugTask through overseer.
      require('overseer').enable_dap(true)

      require('nvim-dap-virtual-text').setup {
        only_first_definition = false,
        all_references = true,
      }

      -- Alternates, if these read badly in a given font:   
      vim.fn.sign_define('DapBreakpoint', { text = '', texthl = '@error' })
      vim.fn.sign_define('DapLogPoint', { text = '󰰍', texthl = '@error' })
      vim.fn.sign_define('DapBreakpointCondition', { text = '', texthl = '@error' })

      -- C/C++ through cpptools. The binary carries the .exe suffix on Windows
      -- only; Mason puts it on Neovim's PATH either way.
      dap.adapters.cppdbg = {
        id = 'cppdbg',
        type = 'executable',
        command = require('util.env').OS == 'windows' and 'OpenDebugAD7.exe' or 'OpenDebugAD7',
        options = { detached = false },
      }
    end,
  },
}
