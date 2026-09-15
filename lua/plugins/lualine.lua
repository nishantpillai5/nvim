-- One lualine.setup call. The old config called it four times -- once here, then
-- again from lsp_zero.lua, lint.lua and noice.lua to graft components on. All
-- those components are defined inline below instead.
local ARRAY = { '｢', '｣' }

-- Buffers that shouldn't count as "unsaved work": they are modifiable but hold
-- nothing you'd lose.
local EXCLUDED_FTS = { 'toggleterm', 'TelescopePrompt', 'oil' }

-- Windows that shouldn't take statusline focus. Without TelescopePrompt here the
-- global statusline follows focus into the picker and shows the prompt buffer
-- instead of the file you were in; the snacks_picker entries are the same case
-- for whatever vim.ui.select opens. Add 'trouble' if it lands.
local IGNORE_FTS = {
  'TelescopePrompt',
  'snacks_picker_list',
  'snacks_picker_input',
  'neo-tree',
  'aerial',
  'OverseerList',
  'fugitive',
  'oil',
  'dashboard',
  'qf',
}

local LSP_ICONS = {
  lua_ls = '󰢱',
  clangd = '󰙱',
  pyright = '',
  jsonls = '',
}

-- Four tabline components ask for this per redraw (the component itself, both
-- array_brackets and the `buffers` cond), and each sweep reads three options per
-- buffer. vim.uv.now() is the event loop's cached time, so it is stable within a
-- redraw and advances between them: keying the memo on it collapses the four
-- sweeps into one without ever serving a value from an earlier redraw.
local unsaved_alert_cache = { at = -1, value = '' }

local function unsaved_buffer_alert()
  local now = vim.uv.now()
  if unsaved_alert_cache.at == now then
    return unsaved_alert_cache.value
  end

  local value = ''
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.bo[buf].modified and not vim.tbl_contains(EXCLUDED_FTS, vim.bo[buf].filetype) then
      value = '󰽂 '
      break
    end
  end

  unsaved_alert_cache.at, unsaved_alert_cache.value = now, value
  return value
end

local function array_bracket(n)
  return function()
    return unsaved_buffer_alert() ~= '' and ARRAY[n] or ''
  end
end

local function cwd()
  return vim.uv.cwd()
end

-- Directory of the current buffer, or nil for anything without a real path:
-- unnamed buffers and pseudo-paths like fugitive:// and oil://, none of which
-- resolve to a repo anyway.
local function buf_dir()
  local name = vim.api.nvim_buf_get_name(0)
  if name == '' or name:match '^%w+://' then
    return nil
  end
  return vim.fs.dirname(name)
end

-- Name of the linked git worktree, if the buffer is in one. Resolved from the
-- `.git` file rather than FugitiveGitDir(), which this config has no fugitive
-- for; util.git.dir_info caches, since this runs on every redraw.
local function worktree()
  local dir = buf_dir()
  local info = dir and require('util.git').dir_info(dir)
  return info and info.worktree and (' ' .. info.worktree) or ''
end

-- Branch of the cwd's repository. lualine's own `branch` component resolves the
-- repo by walking up from the *buffer's* path, which resolves nothing for a
-- pseudo-path like `fugitive:///repo/.git//`: it then blanks the branch it had
-- cached, so the statusline loses the branch the moment a fugitive window opens.
-- This is the fallback for that.
local function cwd_branch()
  local info = require('util.git').dir_info(vim.uv.cwd())
  return info and info.branch or ''
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
  -- overseer v2 replaced `recent_first` with a sort callback.
  local list = overseer.list_tasks {
    sort = require('overseer.task_list').sort_newest_first,
    filter = tasks.filter_build_tasks,
  }
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
    sort = require('overseer.task_list').sort_newest_first,
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

-- Macro recording. lualine has no component for it, and the "recording @q"
-- message is a mode message that noice swallows.
local function macro_recording()
  local reg = vim.fn.reg_recording()
  return reg ~= '' and ('󰑊 ' .. reg) or ''
end

-- minuet's request progress, off its own User events. Its bundled component is
-- unused: requiring it in `opts` would load minuet at startup, not on InsertEnter.
local minuet = { busy = false, total = 1, finished = 0, spinner = 1, round = nil, model = nil }

local function minuet_track()
  local group = vim.api.nvim_create_augroup('lualine_minuet', { clear = true })
  vim.api.nvim_create_autocmd('User', {
    pattern = 'MinuetRequestStartedPre',
    group = group,
    callback = function(ev)
      local data = ev.data or {}
      minuet.total = data.n_requests or 1
      minuet.finished = 0
      minuet.busy = false
      minuet.round = data.timestamp
    end,
  })
  vim.api.nvim_create_autocmd('User', {
    pattern = 'MinuetRequestStarted',
    group = group,
    callback = function()
      minuet.busy = true
    end,
  })
  vim.api.nvim_create_autocmd('User', {
    pattern = 'MinuetRequestFinished',
    group = group,
    callback = function(ev)
      -- terminate_all_jobs() runs before the next round announces itself, so a
      -- superseded job's Finished can land after the counters reset. Drop those:
      -- the stamp is os.time(), so same-second rounds can still slip through.
      if minuet.round and (ev.data or {}).timestamp ~= minuet.round then
        return
      end
      minuet.finished = minuet.finished + 1
      if minuet.finished >= minuet.total then
        minuet.busy = false
      end
    end,
  })
end

-- Ask the server what it actually loaded. Retried only while unknown, so a down
-- server cannot spin curl on every redraw; a later swap needs an nvim restart.
local function minuet_fetch_model(provider)
  if minuet.model or not provider or not provider.end_point then
    return
  end
  local now = vim.uv.now()
  if minuet.asked_at and now - minuet.asked_at < 10000 then
    return
  end
  minuet.asked_at = now
  local base = provider.end_point:gsub('/v1/.*$', '')
  vim.system({ 'curl', '-sf', '--max-time', '2', base .. '/v1/models' }, { text = true }, function(res)
    local ok, decoded = pcall(vim.json.decode, res.stdout or '')
    local id = ok and vim.tbl_get(decoded or {}, 'data', 1, 'id')
    if type(id) == 'string' and id ~= '' then
      minuet.model = id
    end
  end)
end

-- Gated on minuet being loaded, so a disabled plugin shows nothing.
local function minuet_model()
  if not package.loaded['minuet'] then
    return ''
  end
  local config = require('minuet').config
  local provider = config and config.provider_options[config.provider]
  minuet_fetch_model(provider)
  local model = minuet.model or (provider and provider.model)
  if not model or model == '' then
    return ''
  end
  -- Served names are often a full repo id; the basename is what fits a statusline.
  model = model:match '[^/\\]+$' or model
  if not minuet.busy then
    return ' 󰚩 ' .. ARRAY[1] .. model .. ARRAY[2]
  end
  local frame
  frame, minuet.spinner = require('util.tasks').spinner(minuet.spinner, 'run')
  local progress = minuet.total > 1 and (' %d/%d'):format(minuet.finished + 1, minuet.total) or ''
  return ' ' .. frame .. ' ' .. ARRAY[1] .. model .. progress .. ARRAY[2]
end

return {
  {
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    init = minuet_track,
    opts = {
      extensions = { 'overseer', 'nvim-dap-ui' },
      options = {
        globalstatus = true,
        theme = 'vscode',
        section_separators = { left = '', right = '' },
        component_separators = { left = '', right = '' },
        ignore_focus = IGNORE_FTS,
        -- The defaults are repeated because this table is deep-extended onto
        -- them by index, so a shorter list would leave their tail in place.
        -- RecordingEnter/Leave are the additions; the refresh they queue runs a
        -- tick later, by which point RecordingLeave's reg_recording() is clear.
        refresh = {
          events = {
            'WinEnter',
            'BufEnter',
            'BufWritePost',
            'SessionLoadPost',
            'FileChangedShellPost',
            'VimResized',
            'Filetype',
            'CursorMoved',
            'CursorMovedI',
            'ModeChanged',
            'RecordingEnter',
            'RecordingLeave',
          },
        },
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
          minuet_model,
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
            -- NoiceStatus declares its ---@class on a `return` statement, so
            -- lua_ls registers the class name but none of its fields.
            function()
              ---@diagnostic disable-next-line: undefined-field
              return require('noice').api.status.command.get()
            end,
            cond = function()
              local ok, noice = pcall(require, 'noice')
              ---@diagnostic disable-next-line: undefined-field
              return ok and noice.api.status.command.has()
            end,
          },
          macro_recording,
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
          -- Whisper: the pulse, then the buffer transcribed words are landing
          -- in, while any are. The mic that goes with it is the component after
          -- the backend label below. See util/whisper.lua.
          {
            function()
              return require('util.whisper').status()
            end,
          },
          -- The AI backend <leader>a sends to (cycled with <leader>ab), then the
          -- dictation mic: together they say where a dictated prompt would land,
          -- so they are one component rather than two adjacent ones. lualine pads
          -- every non-empty component on both sides, which would read as two
          -- spaces between them. See util/ai/init.lua and util/whisper.lua.
          {
            function()
              local parts = { require('util.ai').status() }
              -- Empty whenever whisper isn't in the config -- no trailing space.
              local mic = require('util.whisper').mic()
              if mic ~= '' then
                parts[#parts + 1] = mic
              end
              return table.concat(parts, ' ')
            end,
          },
        },
      },
    },
  },
}
