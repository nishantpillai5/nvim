return {
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-neotest/nvim-nio',
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
      'stevearc/overseer.nvim',
      'nvim-neotest/neotest-python',
      'alfaix/neotest-gtest',
    },
    keys = {
      -- Also bound buffer-locally under the config directory, where that
      -- mapping wins; these apply everywhere else.
      {
        '<leader>ii',
        function()
          require('neotest').run.run()
        end,
        desc = 'run',
      },
      {
        '<leader>iI',
        function()
          require('neotest').run.run(vim.fn.expand '%')
        end,
        desc = 'run_file',
      },
      {
        -- gtest only in practice: the python adapter comes from
        -- plugins/dap_python.lua, which lua/enabled.lua has off.
        '<leader>id',
        function()
          ---@diagnostic disable-next-line: missing-fields
          require('neotest').run.run { strategy = 'dap' }
        end,
        desc = 'debug',
      },
      {
        '<leader>ix',
        function()
          require('neotest').run.stop()
        end,
        desc = 'stop',
      },
      {
        '<leader>ia',
        function()
          require('neotest').run.attach()
        end,
        desc = 'attach',
      },
      {
        '<leader>ip',
        function()
          require('neotest').output.open { enter = true }
        end,
        desc = 'preview',
      },
      {
        '<leader>io',
        function()
          require('neotest').output_panel.toggle()
        end,
        desc = 'output',
      },
      {
        '<leader>ei',
        function()
          require('neotest').summary.toggle()
        end,
        desc = 'tests',
      },
      -- ] is next, as everywhere else in this config.
      {
        ']i',
        function()
          require('neotest').jump.next { status = 'failed' }
        end,
        desc = 'test',
      },
      {
        '[i',
        function()
          require('neotest').jump.prev { status = 'failed' }
        end,
        desc = 'test',
      },
    },
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('neotest').setup {
        adapters = {
          require('neotest-gtest').setup {},
          require 'neotest-python' {},
        },
        consumers = {
          -- A table with __call, which lua_ls does not count as a `fun(client)`.
          ---@diagnostic disable-next-line: assign-type-mismatch
          overseer = require 'neotest.consumers.overseer',
        },
      }
    end,
  },
}
