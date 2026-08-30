-- One lualine.setup call. The old config called it four times -- once here, then
-- again from lsp_zero.lua, lint.lua and noice.lua to graft components on. All
-- those components are defined inline below instead.
local ARRAY = { '｢', '｣' }

-- Buffers that shouldn't count as "unsaved work": they are modifiable but hold
-- nothing you'd lose.
local EXCLUDED_FTS = { 'toggleterm', 'TelescopePrompt', 'oil' }

-- Windows that shouldn't take statusline focus. Without TelescopePrompt here the
-- global statusline follows focus into the picker and shows the prompt buffer
-- instead of the file you were in. Add 'trouble' / 'neo-tree' if those land.
local IGNORE_FTS = { 'TelescopePrompt', 'OverseerList', 'fugitive', 'oil', 'dashboard', 'qf' }

local LSP_ICONS = {
  lua_ls = '󰢱',
  clangd = '󰙱',
  pyright = '',
  jsonls = '',
}

local function unsaved_buffer_alert()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.bo[buf].modified and not vim.tbl_contains(EXCLUDED_FTS, vim.bo[buf].filetype) then
      return '󰽂 '
    end
  end
  return ''
end

local function array_bracket(n)
  return function()
    return unsaved_buffer_alert() ~= '' and ARRAY[n] or ''
  end
end

local function cwd()
  return vim.uv.cwd()
end

-- Name of the linked git worktree, if the buffer is in one. Reads the `.git`
-- file directly -- the old config used FugitiveGitDir(), and fugitive is not
-- part of this config.
local function worktree()
  local root = vim.fs.root(0, '.git')
  if not root then
    return ''
  end
  local dotgit = vim.fs.joinpath(root, '.git')
  local stat = vim.uv.fs_stat(dotgit)
  if not stat or stat.type ~= 'file' then
    return ''
  end
  local name = (vim.fn.readfile(dotgit, '', 1)[1] or ''):match 'worktrees/(.+)$'
  return name and (' ' .. name) or ''
end

-- Branch of the cwd's repository, read straight from HEAD. lualine's own
-- `branch` component resolves the repo by walking up from the *buffer's* path,
-- which resolves nothing for a pseudo-path like `fugitive:///repo/.git//`: it
-- then blanks the branch it had cached, so the statusline loses the branch the
-- moment a fugitive window opens. This is the fallback for that.
local function cwd_branch()
  local root = vim.fs.root(vim.uv.cwd(), '.git')
  if not root then
    return ''
  end

  local gitdir = vim.fs.joinpath(root, '.git')
  local stat = vim.uv.fs_stat(gitdir)
  if stat and stat.type == 'file' then
    -- Linked worktree or submodule: `.git` points at the real git dir.
    local target = (vim.fn.readfile(gitdir, '', 1)[1] or ''):match 'gitdir: (.+)$'
    if not target then
      return ''
    end
    gitdir = vim.fs.normalize(vim.startswith(target, '/') and target or vim.fs.joinpath(root, target))
  end

  local head = vim.fn.readfile(vim.fs.joinpath(gitdir, 'HEAD'), '', 1)[1] or ''
  -- Detached HEAD falls back to a short sha, the same width lualine uses.
  return head:match 'ref: refs/heads/(.+)$' or head:sub(1, 6)
end

-- Attached LSP clients, as icons. Was lsp_zero.lua's lualine injection.
local function lsp_clients()
  local clients = vim.lsp.get_clients { bufnr = 0 }
  if #clients == 0 then
    return '  '
  end
  local out = {}
  for _, client in ipairs(clients) do
    table.insert(out, LSP_ICONS[client.name] or client.name)
  end
  return '  ' .. ARRAY[1] .. table.concat(out, ' ') .. ' ' .. ARRAY[2]
end

-- Linters currently running. Was lint.lua's lualine injection.
local function lint_progress()
  local ok, lint = pcall(require, 'lint')
  if not ok then
    return ''
  end
  local running = lint.get_running()
  if #running == 0 then
    return '   '
  end
  return '   ' .. ARRAY[1] .. table.concat(running, ', ') .. ARRAY[2]
end

local STATUS_SYMBOLS = {
  RUNNING = '  ',
  SUCCESS = '  ',
  CANCELED = ' 󰜺 ',
  FAILURE = '  ',
  DEFAULT = '  ',
}

local spinner_build, spinner_run = 1, 1

-- Most recent build task, with a spinner while it runs. Was overseer.lua's own
-- lualine.setup call.
local function last_build_text()
  local ok, overseer = pcall(require, 'overseer')
  if not ok then
    return ''
  end
  local tasks = require 'util.tasks'
  local list = overseer.list_tasks { recent_first = true, filter = tasks.filter_build_tasks }
  if vim.tbl_isempty(list) then
    return ''
  end
  local symbol = STATUS_SYMBOLS[list[1].status] or STATUS_SYMBOLS.DEFAULT
  if list[1].status == 'RUNNING' then
    local frame
    frame, spinner_build = tasks.spinner(spinner_build, 'build')
    symbol = ' ' .. frame .. ' '
  end
  return symbol .. tasks.task_formatter(list[1])
end

-- Only shown while a run task is actually running.
local function last_run_text()
  local ok, overseer = pcall(require, 'overseer')
  if not ok then
    return ''
  end
  local tasks = require 'util.tasks'
  local list = overseer.list_tasks {
    recent_first = true,
    filter = tasks.filter_run_tasks,
    status = { 'RUNNING' },
  }
  if vim.tbl_isempty(list) then
    return ''
  end
  local frame
  frame, spinner_run = tasks.spinner(spinner_run, 'run')
  return ' ' .. frame .. ' ' .. tasks.task_formatter(list[1])
end

local function task_status()
  return last_run_text() .. last_build_text()
end

-- Whether Claude's prompt box will dictate (<leader>ad, plugins/whisper.lua),
-- and what a live session is doing. nil flag = whisper not in this config.
local MIC, MIC_OFF = '󰍬', '󰍭'

local function dictation()
  if vim.g.whisper_auto_dictate == nil then
    return ''
  elseif not vim.g.whisper_auto_dictate then
    return MIC_OFF
  end
  if package.loaded['whisper'] then
    local state = require 'whisper.state'
    if state.is_recording() and not state.is_model_loaded() then
      return MIC .. ' Loading'
    elseif vim.g.whisper_dictating then
      return state.is_processing() and (MIC .. ' Processing') or (MIC .. ' Recording')
    end
  end
  -- Armed: model resident, waiting for a prompt box.
  return MIC
end

return {
  {
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      extensions = { 'overseer', 'nvim-dap-ui' },
      options = {
        globalstatus = true,
        theme = 'vscode',
        section_separators = { left = '', right = '' },
        component_separators = { left = '', right = '' },
        ignore_focus = IGNORE_FTS,
        disabled_filetypes = {
          statusline = {},
          winbar = { 'toggleterm' },
        },
      },
      sections = {
        lualine_a = { 'mode', 'selectioncount' },
        lualine_b = { cwd },
        lualine_c = {
          -- lualine's own component, with cwd_branch() covering the cases where
          -- its per-buffer resolution comes up empty: fugitive:// and other
          -- pseudo-path buffers, and the per-buffer cache misses that
          -- ignore_focus causes in pickers, the dashboard and the quickfix list.
          {
            'branch',
            fmt = function(name)
              return name ~= '' and name or require('lualine.utils.utils').stl_escape(cwd_branch())
            end,
          },
          worktree,
          -- Was gitblame.lua's own lualine.setup call, gated on the dropped
          -- SCREEN=='widescreen' knob. The cond keeps it out of the way when
          -- there's no blame text.
          {
            function()
              return '' .. require('gitblame').get_current_blame_text()
            end,
            cond = function()
              local ok, gitblame = pcall(require, 'gitblame')
              return ok and gitblame.is_blame_text_available()
            end,
          },
        },
        lualine_x = {
          lint_progress,
          { 'diagnostics', always_visible = false },
          lsp_clients,
        },
        lualine_y = {
          'encoding',
          'filetype',
          { 'fileformat', icons_enabled = false },
        },
        lualine_z = { 'progress', 'location' },
      },
      tabline = {
        lualine_a = { { 'grapple' } },
        lualine_b = {
          {
            'filename',
            path = 1,
            symbols = { modified = '●', readonly = '', directory = '' },
          },
        },
        lualine_c = { 'diff' },
        lualine_x = {
          unsaved_buffer_alert,
          array_bracket(1),
          {
            'buffers',
            icons_enabled = false,
            show_modified_status = false,
            symbols = { modified = '', alternate_file = '', directory = '' },
            -- Only name the modified buffers; the rest collapse to nothing.
            fmt = function(name, context)
              return vim.bo[context.bufnr].modified and name or ''
            end,
            cond = function()
              return unsaved_buffer_alert() ~= ''
            end,
          },
          array_bracket(2),
        },
        lualine_y = {
          'searchcount',
          {
            function()
              return '󰄉 ' .. tostring(require('pomo').get_first_to_finish())
            end,
            cond = function()
              local ok, pomo = pcall(require, 'pomo')
              return ok and pomo.get_first_to_finish() ~= nil
            end,
          },
          task_status,
          { 'overseer' },
          {
            function()
              return require('noice').api.statusline.command.get()
            end,
            cond = function()
              local ok, noice = pcall(require, 'noice')
              return ok and noice.api.statusline.command.has()
            end,
          },
        },
        lualine_z = {
          {
            function()
              return require('util.scope').status()
            end,
            cond = function()
              return package.loaded['neoscopes'] ~= nil
            end,
          },
          dictation,
        },
      },
    },
  },
}
