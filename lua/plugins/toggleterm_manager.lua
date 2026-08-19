-- `_G.env_reader` is also used by the custom.vscode_env overseer component, so a
-- task and a terminal see the same environment. A project-local exrc file can
-- replace it.
_G.env_reader = _G.env_reader
  or function()
    local cwd = vim.uv.cwd()
    local candidates = { vim.fs.joinpath(cwd, '.vscode', '.env'), vim.fs.joinpath(cwd, '.env') }

    local path
    for _, candidate in ipairs(candidates) do
      if vim.uv.fs_stat(candidate) then
        path = candidate
        break
      end
    end
    if not path then
      return nil
    end

    local env = {}
    for _, line in ipairs(vim.fn.readfile(path)) do
      local key, value = line:match '^([^#=]+)=(.*)$'
      if key then
        env[vim.trim(key)] = vim.trim(value)
      end
    end
    return env
  end

return {
  {
    -- Forked to create terminals with env vars.
    'nishantpillai5/toggleterm-manager.nvim',
    dependencies = {
      'akinsho/nvim-toggleterm.lua',
      'nvim-telescope/telescope.nvim',
      'nvim-lua/plenary.nvim',
    },
    keys = {
      { '<leader>fo', '<cmd>Telescope toggleterm_manager<cr>', desc = 'terminals' },
      { '<leader>oF', '<cmd>Telescope toggleterm_manager<cr>', desc = 'find' },
    },
    config = function()
      local manager = require 'toggleterm-manager'
      local actions = manager.actions

      manager.setup {
        mappings = {
          n = {
            ['<CR>'] = { action = actions.toggle_term, exit_on_action = true },
            ['o'] = {
              action = actions.create_and_name_term_with_env_reader(_G.env_reader),
              exit_on_action = true,
            },
            ['i'] = {
              action = actions.create_term_with_env_reader(_G.env_reader),
              exit_on_action = true,
            },
            ['x'] = { action = actions.delete_term, exit_on_action = false },
          },
        },
      }
    end,
  },
}
