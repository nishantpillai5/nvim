local tasks = require 'util.tasks'

local PANEL = 'horizontal' -- 'horizontal' | 'vertical'
local OPEN_DIR = PANEL == 'vertical' and 'vsplit' or 'split'

-- v2 dropped `recent_first` for a `sort` callback. Required lazily, so these
-- helpers stay cheap on the statusline path.
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

-- "core" is what the project's exrc hooks claim; "other" is the rest. With no
-- hooks both filters match everything, so the upper-case keys act on any task.
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
    -- v2 renamed run_template -> run_task; the opts table is unchanged.
    require('overseer').run_task(_G[global])
  end
end

-- v2 replaced the `default_detail` levels with a render function, so L/H swap
-- the formatter instead of nudging a counter.
local DETAIL_FORMATS = { 'format_compact', 'format_standard', 'format_verbose' }
local detail = 1

local function step_detail(delta)
  return function()
    detail = math.min(#DETAIL_FORMATS, math.max(1, detail + delta))
    -- touch() no-ops without a task; on_task_updated always re-renders.
    require('overseer.task_list').on_task_updated()
  end
end

-- Template order is provider-discovery order and v2 deleted sort priority, so
-- this call is the only place left to reorder. Those named here come first.
local MODULE_ORDER = { 'vscode' }

local function template_rank(tmpl)
  for i, module in ipairs(MODULE_ORDER) do
    if tmpl.module == module then
      return i
    end
  end
  return #MODULE_ORDER + 1
end

local function sort_templates(items)
  -- table.sort is not stable, and one provider's templates are already in a
  -- deliberate order -- so the original index is the tiebreak.
  local index = {}
  for i, item in ipairs(items) do
    index[item] = i
  end
  local sorted = vim.list_slice(items)
  table.sort(sorted, function(a, b)
    local ra, rb = template_rank(a), template_rank(b)
    if ra ~= rb then
      return ra < rb
    end
    return index[a] < index[b]
  end)
  return sorted
end

-- Only overseer's template picker sets this `kind`, so the wrapper is inert
-- elsewhere. `:checkhealth snacks` compares identity, so it reports this.
local function order_template_picker()
  local select = vim.ui.select
  vim.ui.select = function(items, opts, on_choice)
    if opts and opts.kind == 'overseer_template' then
      items = sort_templates(items)
    end
    return select(items, opts, on_choice)
  end
end

return {
  {
    'stevearc/overseer.nvim',
    version = '^2.0.0',
    dependencies = {
      -- v2 deleted the toggleterm and terminal strategies.
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
      -- OverseerShell is v2's "run this shell command as a task"; with `!` it
      -- creates without starting, the nearest thing to the old OverseerBuild.
      { '<leader>oRr', ':OverseerShell ', desc = 'run_shell_cmd' },
      { '<leader>eo', '<cmd>OverseerToggle<cr>', desc = 'tasks' },
      { '<leader>of', '<cmd>OverseerTaskAction<cr>', desc = 'change_task' },
      { '<leader>fO', '<cmd>OverseerTaskAction<cr>', desc = 'tasks' },
      { '<leader>on', ':OverseerShell! ', desc = 'new' },

      -- Lower case targets run/build tasks, upper case everything else.
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
      { '<leader>or', run_task('run_template', 'Run'), desc = 'run' },
      { '<leader>ob', run_task('build_template', 'Build'), desc = 'build' },
    },
    opts = {
      dap = false,
      task_list = {
        render = function(task)
          local render = require 'overseer.render'
          local lines = render[DETAIL_FORMATS[detail]](task)
          -- All three built-ins open with status_and_name; swap in the exrc
          -- label the lualine indicator uses.
          if tasks.has_formatter() then
            lines[1] = render.join(render.status(task), { { tasks.task_formatter(task), 'OverseerTask' } }, ': ')
          end
          return lines
        end,
        -- v2: `bindings` -> `keymaps`, and actions are "keymap.*" handlers.
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
          'on_exit_set_status',
          'on_complete_notify',
          { 'on_complete_dispose', timeout = 1800 },
          -- local component: lua/overseer/component/custom/vscode_env.lua
          'custom.vscode_env',
        },
      },
    },
    config = function(_, opts)
      require('overseer').setup(opts)
      order_template_picker()
    end,
  },
}
