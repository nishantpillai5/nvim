-- One lualine.setup call; every grafted-on component is defined inline below.
local ARRAY = { '｢', '｣' }

-- Modifiable, but holding nothing you'd lose.
local EXCLUDED_FTS = { 'toggleterm', 'TelescopePrompt', 'oil' }

-- Without these the global statusline follows focus into a picker and shows
-- its prompt buffer instead of the file you were in.
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

-- Four tabline components ask for this per redraw. vim.uv.now() is the loop's
-- cached time -- stable within a redraw, advancing between -- so it keys a memo.
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

-- nil for pseudo-paths like fugitive:// and oil://, which resolve to no repo.
local function buf_dir()
  local name = vim.api.nvim_buf_get_name(0)
  if name == '' or name:match '^%w+://' then
    return nil
  end
  return vim.fs.dirname(name)
end

-- From the `.git` file rather than FugitiveGitDir(), which this config has no
-- fugitive for. util.git.dir_info caches, since this runs on every redraw.
local function worktree()
  local dir = buf_dir()
  local info = dir and require('util.git').dir_info(dir)
  return info and info.worktree and (' ' .. info.worktree) or ''
end

-- The fallback for lualine's own `branch`, which walks up from the *buffer's*
-- path and blanks its cache on a pseudo-path like `fugitive:///repo/.git//`.
local function cwd_branch()
  local info = require('util.git').dir_info(vim.uv.cwd())
  return info and info.branch or ''
end

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

-- `pcall(require, x)` would load x through lazy's module hook; this does not.
local function loaded(mod)
  return package.loaded[mod] ~= nil
end

local function lint_progress()
  if not loaded 'lint' then
    return ''
  end
  local running = require('lint').get_running()
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

-- Most recent build task, with a spinner while it runs.
local function last_build_text()
  if not loaded 'overseer' then
    return ''
  end
  local overseer = require 'overseer'
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
  if not loaded 'overseer' then
    return ''
  end
  local overseer = require 'overseer'
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

local OVERSEER_ICONS = { FAILURE = '󰅚 ', CANCELED = ' ', SUCCESS = '󰄴 ', RUNNING = '󰑮 ' }

-- Replaces the `{ 'overseer' }` component, which requires overseer -- and so
-- telescope -- at file scope, on setup.
local function overseer_counts()
  if not loaded 'overseer' then
    return ''
  end
  local counts, pieces = {}, {}
  for _, task in ipairs(require('overseer.task_list').list_tasks { include_ephemeral = true }) do
    counts[task.status] = (counts[task.status] or 0) + 1
  end
  for _, status in ipairs(require('overseer.constants').STATUS.values) do
    if OVERSEER_ICONS[status] and counts[status] then
      table.insert(pieces, ('%%#Overseer%s#%s%d'):format(status, OVERSEER_ICONS[status], counts[status]))
    end
  end
  return table.concat(pieces, ' ')
end

-- lualine has no component for it, and noice swallows the mode message.
local function macro_recording()
  local reg = vim.fn.reg_recording()
  return reg ~= '' and ('󰑊 ' .. reg) or ''
end

-- Off minuet's own User events: requiring its bundled component in `opts`
-- would load minuet at startup rather than on InsertEnter.
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
      -- superseded job's Finished can land after the counters reset.
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

-- Retried only while unknown, so a down server cannot spin curl on every
-- redraw; a later model swap needs an nvim restart.
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

local function minuet_model()
  if not loaded 'minuet' then
    return ''
  end
  local config = require('minuet').config
  local provider = config and config.provider_options[config.provider]
  minuet_fetch_model(provider)
  local model = minuet.model or (provider and provider.model)
  if not model or model == '' then
    return ''
  end
  -- Served names are often a full repo id; only the basename fits.
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
        -- Deep-extended onto the defaults by index, so they are repeated or
        -- their tail stays in place. RecordingEnter/Leave are the additions.
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
          -- cwd_branch() covers where lualine's per-buffer resolution comes up
          -- empty: pseudo-paths, and the cache misses ignore_focus causes.
          {
            'branch',
            fmt = function(name)
              return name ~= '' and name or require('lualine.utils.utils').stl_escape(cwd_branch())
            end,
          },
          worktree,
          -- The cond keeps it out of the way when there's no blame text.
          {
            function()
              return '' .. require('gitblame').get_current_blame_text()
            end,
            cond = function()
              return loaded 'gitblame' and require('gitblame').is_blame_text_available()
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
            -- Only name the modified buffers.
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
              return loaded 'pomo' and require('pomo').get_first_to_finish() ~= nil
            end,
          },
          task_status,
          overseer_counts,
          {
            -- NoiceStatus declares its ---@class on a `return`, so lua_ls
            -- registers the class name but none of its fields.
            function()
              ---@diagnostic disable-next-line: undefined-field
              return require('noice').api.status.command.get()
            end,
            cond = function()
              ---@diagnostic disable-next-line: undefined-field
              return loaded 'noice' and require('noice').api.status.command.has()
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
              return loaded 'neoscopes'
            end,
          },
          -- The pulse, and the buffer transcribed words are landing in. Its
          -- mic is the component after the backend label below.
          {
            function()
              return require('util.whisper').status()
            end,
          },
          -- Backend label plus dictation mic, as one component: lualine pads
          -- every non-empty component, so two would read as a double space.
          {
            function()
              local parts = { require('util.ai').status() }
              -- Empty without whisper, so there is no trailing space.
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
