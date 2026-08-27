-- Test running. Each language needs its own adapter; python and gtest are the
-- two the old config carried. Results run as overseer tasks (see the
-- `default_neotest` component alias in overseer.lua), so a test run shows up in
-- the task list and the lualine task indicator like any other job.
--
-- FixCursorHold.nvim was a dependency in the old config; the CursorHold bug it
-- worked around is long fixed, so it is dropped here.
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
      -- <leader>ii and <leader>iI are also bound buffer-locally under the config
      -- directory (core/keymaps.lua, source_config_*); the local mapping wins
      -- there, these apply everywhere else.
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
        '<leader>id',
        function()
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
      -- The old config had these two the wrong way round; ] is next here, as
      -- everywhere else in this config.
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
          -- No `python` here on purpose: the adapter then looks for the
          -- project's own venv (venv/, .venv/) before falling back to python3.
          -- The old config pinned a machine-specific interpreter instead.
          require 'neotest-python' {},
        },
        consumers = {
          overseer = require 'neotest.consumers.overseer',
        },
      }
    end,
  },
}
