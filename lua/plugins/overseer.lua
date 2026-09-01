local tasks = require 'util.tasks'

-- PANEL_POSITION was a global env knob; overseer and toggleterm each keep their
-- own constant now. v2 names the split direction rather than an action.
local PANEL = 'horizontal' -- 'horizontal' | 'vertical'
local OPEN_DIR = PANEL == 'vertical' and 'vsplit' or 'split'

-- v2 dropped `list_tasks { recent_first = true }` for a `sort` callback.
-- sort_newest_first is the same ordering (newest start time first); the module
-- is required lazily so these helpers stay cheap on the statusline path.
local function newest_first()
  return require('overseer.task_list').sort_newest_first
end

local function action_on_all(action)
  local overseer = require 'overseer'
  local list = overseer.list_tasks { sort = newest_first() }
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
  local list = overseer.list_tasks { sort = newest_first(), filter = filter }
  if vim.tbl_isempty(list) then
    vim.notify('No tasks found', vim.log.levels.WARN)
    return
  end
  overseer.run_action(list[1], action)
end

-- "core" is whatever the project's exrc hooks claim as its run/build tasks;
-- "other" is the rest. With no hooks set both filters match everything, so
-- there is no meaningful split and the upper-case keys fall back to acting on
-- any task rather than reporting nothing found.
local function core_tasks(task)
  return tasks.filter_run_tasks(task) or tasks.filter_build_tasks(task)
end

local function other_tasks(task)
  if not tasks.has_filters() then
    return true
  end
  return not core_tasks(task)
end

local function run_task(global, label)
  return function()
    if _G[global] == nil then
      vim.notify(label .. ' template not set', vim.log.levels.ERROR)
      return
    end
    -- v2 renamed run_template -> run_task; the opts table is unchanged apart
    -- from `prompt` becoming `disallow_prompt`, which no exrc here sets.
    require('overseer').run_task(_G[global])
  end
end

-- v2 replaced the 1-3 `default_detail` levels with a render function, so L/H
-- swap the formatter and force a redraw instead of nudging a detail counter.
local DETAIL_FORMATS = { 'format_compact', 'format_standard', 'format_verbose' }
local detail = 1

local function step_detail(delta)
  return function()
    detail = math.min(#DETAIL_FORMATS, math.max(1, detail + delta))
    -- touch() no-ops without a task argument; on_task_updated is the
    -- unconditional re-render.
    require('overseer.task_list').on_task_updated()
  end
end

return {
  {
    'stevearc/overseer.nvim',
    version = '^2.0.0',
    dependencies = {
      -- No toggleterm: v2 deleted the toggleterm and terminal strategies. Task
      -- output is a terminal buffer via the default `output.use_terminal`.
      'nvim-telescope/telescope.nvim',
      'folke/snacks.nvim',
    },
    cmd = {
      'OverseerOpen',
      'OverseerClose',
      'OverseerToggle',
      'OverseerRun',
      'OverseerShell',
      'OverseerTaskAction',
    },
    keys = {
      { '<leader>oo', '<cmd>OverseerRun<cr>', desc = 'run_from_list' },
      -- OverseerRunCmd is gone; OverseerShell is v2's "run this shell command
      -- as a task", and with `!` it creates the task without starting it --
      -- the nearest thing left to the deleted OverseerBuild.
      { '<leader>oRr', ':OverseerShell ', desc = 'run_shell_cmd' },
      { '<leader>eo', '<cmd>OverseerToggle<cr>', desc = 'tasks' },
      { '<leader>of', '<cmd>OverseerTaskAction<cr>', desc = 'change_task' },
      { '<leader>fO', '<cmd>OverseerTaskAction<cr>', desc = 'tasks' },
      { '<leader>on', ':OverseerShell! ', desc = 'new' },

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

      -- <leader>ows / owl / owd are gone with task bundles, which v2 deleted in
      -- favour of the resession extension configured in plugins/resession.lua.

      { '<leader>or', run_task('run_template', 'Run'), desc = 'run' },
      { '<leader>ob', run_task('build_template', 'Build'), desc = 'build' },
    },
    opts = {
      -- No `strategy`: v2 removed the option along with the toggleterm and
      -- terminal strategies, and jobstart-into-a-terminal-buffer is the default.
      -- `bundles` went with the bundle feature; autostart_on_load moved to the
      -- resession extension.
      dap = false,
      task_list = {
        -- `width` only ever applied to a left/right task list, and direction
        -- defaults to "bottom", so it was already inert -- v2 dropped it.
        render = function(task)
          return require('overseer.render')[DETAIL_FORMATS[detail]](task)
        end,
        -- `bindings` -> `keymaps`, and the action names are now "keymap.*"
        -- handlers taking an `opts` table.
        keymaps = {
          -- Freed up for tmux-style window navigation.
          ['<C-h>'] = false,
          ['<C-j>'] = false,
          ['<C-k>'] = false,
          ['<C-l>'] = false,
          ['L'] = { step_detail(1), desc = 'Increase task detail' },
          ['H'] = { step_detail(-1), desc = 'Decrease task detail' },
          ['v'] = { 'keymap.open', opts = { dir = 'vsplit' }, desc = 'Open task output in vsplit' },
          ['s'] = { 'keymap.open', opts = { dir = 'split' }, desc = 'Open task output in split' },
          ['<CR>'] = { 'keymap.open', opts = { dir = OPEN_DIR }, desc = 'Open task output' },
          ['c'] = 'keymap.run_action',
          ['d'] = { 'keymap.run_action', opts = { action = 'dispose' }, desc = 'Dispose task' },
          ['j'] = 'keymap.next_task',
          ['k'] = 'keymap.prev_task',
          ['x'] = { 'keymap.run_action', opts = { action = 'stop' }, desc = 'Stop task' },
          ['r'] = { 'keymap.run_action', opts = { action = 'restart' }, desc = 'Restart task' },
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
