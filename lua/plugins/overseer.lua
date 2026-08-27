local tasks = require 'util.tasks'

-- PANEL_POSITION was a global env knob; overseer and toggleterm each keep their
-- own constant now.
local PANEL = 'horizontal' -- 'horizontal' | 'vertical'
local OPEN_ACTION = PANEL == 'vertical' and 'OpenVsplit' or 'OpenSplit'

local function action_on_all(action)
  local overseer = require 'overseer'
  local list = overseer.list_tasks { recent_first = true }
  if vim.tbl_isempty(list) then
    vim.notify('No tasks found', vim.log.levels.WARN)
    return
  end
  for _, task in ipairs(list) do
    overseer.run_action(task, action)
  end
end

local function action_on_last(action, filter)
  local overseer = require 'overseer'
  local list = overseer.list_tasks { recent_first = true, filter = filter }
  if vim.tbl_isempty(list) then
    vim.notify('No tasks found', vim.log.levels.WARN)
    return
  end
  overseer.run_action(list[1], action)
end

local function core_tasks(task)
  return tasks.filter_run_tasks(task) or tasks.filter_build_tasks(task)
end

local function other_tasks(task)
  return not core_tasks(task)
end

local function run_template(global, label)
  return function()
    if _G[global] == nil then
      vim.notify(label .. ' template not set', vim.log.levels.ERROR)
      return
    end
    require('overseer').run_template(_G[global])
  end
end

local function select_bundle(prompt, command)
  return function()
    local overseer = require 'overseer'
    vim.ui.select(overseer.list_task_bundles(), {
      prompt = prompt,
    }, function(selected)
      if selected then
        vim.cmd(command .. ' ' .. selected)
      end
    end)
  end
end

return {
  {
    'stevearc/overseer.nvim',
    -- FIXME: pinned, see stevearc/overseer.nvim#448
    version = '^1.6.0',
    dependencies = {
      'akinsho/nvim-toggleterm.lua',
      'nvim-telescope/telescope.nvim',
      'folke/snacks.nvim',
    },
    cmd = {
      'OverseerList',
      'OverseerRun',
      'OverseerRunCmd',
      'OverseerToggle',
      'OverseerBuild',
      'OverseerTaskAction',
      'OverseerLoadBundle',
      'OverseerDeleteBundle',
    },
    keys = {
      { '<leader>oo', '<cmd>OverseerRun<cr>', desc = 'run_from_list' },
      { '<leader>oRr', ':OverseerRunCmd ', desc = 'run_cmd_with_template' },
      { '<leader>eo', '<cmd>OverseerToggle<cr>', desc = 'tasks' },
      { '<leader>of', '<cmd>OverseerTaskAction<cr>', desc = 'change_task' },
      { '<leader>fO', '<cmd>OverseerTaskAction<cr>', desc = 'tasks' },
      { '<leader>on', '<cmd>OverseerBuild<cr>', desc = 'new' },

      -- Act on the most recent task. Lower case targets run/build tasks, upper
      -- case everything else.
      {
        '<leader>oc',
        function()
          action_on_last(nil, core_tasks)
        end,
        desc = 'change_last_core',
      },
      {
        '<leader>oC',
        function()
          action_on_last(nil, other_tasks)
        end,
        desc = 'change_last_other',
      },
      {
        '<leader>ol',
        function()
          action_on_last('restart', core_tasks)
        end,
        desc = 'restart_last_core',
      },
      {
        '<leader>oL',
        function()
          action_on_last('restart', other_tasks)
        end,
        desc = 'restart_last_other',
      },
      {
        '<leader>op',
        function()
          action_on_last('open float', core_tasks)
        end,
        desc = 'preview_last_core',
      },
      {
        '<leader>oP',
        function()
          action_on_last('open float', other_tasks)
        end,
        desc = 'preview_last_other',
      },
      {
        '<leader>os',
        function()
          action_on_last('open hsplit', core_tasks)
        end,
        desc = 'split_last_core',
      },
      {
        '<leader>oS',
        function()
          action_on_last('open hsplit', other_tasks)
        end,
        desc = 'split_last_other',
      },
      {
        '<leader>ov',
        function()
          action_on_last('open vsplit', core_tasks)
        end,
        desc = 'vsplit_last_core',
      },
      {
        '<leader>oV',
        function()
          action_on_last('open vsplit', other_tasks)
        end,
        desc = 'vsplit_last_other',
      },
      {
        '<leader>ox',
        function()
          action_on_last('stop', core_tasks)
        end,
        desc = 'stop_last_core',
      },
      {
        '<leader>oX',
        function()
          action_on_last('stop', other_tasks)
        end,
        desc = 'stop_last_other',
      },
      {
        '<leader>oq',
        function()
          action_on_all 'stop'
        end,
        desc = 'stop_all',
      },
      {
        '<leader>ows',
        function()
          action_on_last 'save'
        end,
        desc = 'save_last',
      },

      { '<leader>or', run_template('run_template', 'Run'), desc = 'run' },
      { '<leader>ob', run_template('build_template', 'Build'), desc = 'build' },

      { '<leader>owl', select_bundle('Load bundle', 'OverseerLoadBundle'), desc = 'load_bundle' },
      { '<leader>owd', select_bundle('Delete bundle', 'OverseerDeleteBundle'), desc = 'delete_bundle' },
    },
    opts = {
      strategy = { 'toggleterm', open_on_start = false },
      bundles = { autostart_on_load = false },
      dap = false,
      task_list = {
        default_detail = 1,
        width = 0.13,
        bindings = {
          -- Freed up for tmux-style window navigation.
          ['<C-h>'] = false,
          ['<C-j>'] = false,
          ['<C-k>'] = false,
          ['<C-l>'] = false,
          ['L'] = 'IncreaseDetail',
          ['H'] = 'DecreaseDetail',
          ['v'] = 'OpenVsplit',
          ['s'] = 'OpenSplit',
          ['<CR>'] = OPEN_ACTION,
          ['c'] = 'RunAction',
          ['d'] = 'Dispose',
          ['j'] = 'NextTask',
          ['k'] = 'PrevTask',
          ['x'] = 'Stop',
          ['r'] = 'Restart', -- FIXME: doesn't work
        },
      },
      component_aliases = {
        default = {
          'on_output_summarize',
          'on_exit_set_status',
          'on_complete_notify',
          'on_complete_dispose',
          -- lua/overseer/component/custom/vscode_env.lua
          'custom.vscode_env',
        },
        default_neotest = {
          'on_output_summarize',
          'on_exit_set_status',
          'on_complete_notify',
          'on_complete_dispose',
        },
      },
    },
  },
}
