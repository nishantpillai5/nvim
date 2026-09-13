-- Which AI backend <leader>a talks to, and the registry they are declared in.
-- Safe to require from the lualine component: nothing here touches
-- claudecode.nvim or omp.nvim at load.

local M = {}

-- Declaration order is the picker order and the fallback preference.
local BACKENDS = {
  {
    name = 'claude',
    exe = 'claude',
    plugin = 'coder/claudecode.nvim',
    icon = '󰚩',
  },
  {
    name = 'omp',
    exe = 'omp',
    plugin = 'rauls-kjarners/omp.nvim',
    icon = '󰚩',
  },
}

-- enabled.lua cannot change after startup, so resolve once and keep.
local enabled_set

local function is_enabled(spec)
  if not enabled_set then
    enabled_set = {}
    for _, name in ipairs(require 'enabled') do
      enabled_set[name] = true
    end
  end
  return enabled_set[spec.plugin] == true
end

-- vim.fn.executable stats every PATH entry, and PATH does not change under a
-- running session.
local executable = {}

local function has_exe(spec)
  local cached = executable[spec.exe]
  if cached == nil then
    cached = vim.fn.executable(spec.exe) == 1
    executable[spec.exe] = cached
  end
  return cached
end

-- nil when usable, else why not -- shown in the picker and used to refuse it.
local function unavailable(spec)
  if not is_enabled(spec) then
    return 'commented out of enabled.lua'
  end
  if not has_exe(spec) then
    return spec.exe .. ' is not on PATH'
  end
end

function M.available(spec)
  return unavailable(spec) == nil
end

-- `omarchy default agent <name>` writes the bare name here. Omarchy hardcodes
-- $HOME/.config, so this does too rather than using env.XDG_CONFIG_HOME.
local OMARCHY_AGENT = vim.fs.normalize '~/.config/omarchy/defaults/agent'

function M.omarchy_agent()
  local f = io.open(OMARCHY_AGENT, 'r')
  if not f then
    return nil
  end
  local line = f:read 'l'
  f:close()
  line = line and vim.trim(line) or ''
  return line ~= '' and line or nil
end

-- nil until the first get(): resolving the default touches PATH.
local current = nil

local function default_backend()
  -- Omarchy's names match `name` above. One it names that has no backend here
  -- (`codex`, `grok`) is not a fault -- fall through to declaration order.
  local preferred = M.omarchy_agent()
  for _, spec in ipairs(BACKENDS) do
    if spec.name == preferred then
      -- Stay on a backend Omarchy named even when broken, rather than hand the
      -- keys to an agent nobody chose. Scheduled: get() can precede nvim-notify.
      local why = unavailable(spec)
      if why then
        vim.schedule(function()
          vim.notify(('Omarchy default agent %s is unusable: %s'):format(spec.name, why), vim.log.levels.ERROR)
        end)
      end
      return spec
    end
  end
  for _, spec in ipairs(BACKENDS) do
    if M.available(spec) then
      return spec
    end
  end
  -- Nothing installed: callers need no nil guard, and the ops report it anyway.
  return BACKENDS[1]
end

function M.get()
  if not current then
    current = default_backend()
  end
  return current
end

function M.set(name)
  for _, spec in ipairs(BACKENDS) do
    if spec.name == name then
      current = spec
      -- lualine only repaints on redraw, and nothing else dirties the tabline.
      vim.cmd.redrawtabline()
      vim.api.nvim_exec_autocmds('User', { pattern = 'AiBackendChanged', modeline = false })
      return spec
    end
  end
  vim.notify('No such AI backend: ' .. tostring(name), vim.log.levels.WARN)
end

-- Unavailable backends are listed too: "omp -- omp is not on PATH" answers what
-- a silently short menu would not. telescope is required inside, not at load.
function M.pick()
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'

  local active = M.get()

  pickers
    .new({}, {
      prompt_title = 'AI Backend',
      finder = finders.new_table {
        results = BACKENDS,
        entry_maker = function(spec)
          return {
            value = spec,
            display = function(e)
              local head = e.value.icon .. ' ' .. e.value.name
              local note = unavailable(e.value)
              if e.value == active then
                note = note and ('active, ' .. note) or 'active'
              end
              if not note then
                return head
              end
              local full = head .. '  \u{2014}  ' .. note
              return full, { { { #head, #full }, 'Comment' } }
            end,
            ordinal = spec.name,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local sel = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not sel then
            return
          end
          local why = unavailable(sel.value)
          if why then
            vim.notify(('%s: %s'):format(sel.value.name, why), vim.log.levels.WARN)
          elseif sel.value ~= active then
            -- Silent on success: the tabline indicator is the feedback.
            M.set(sel.value.name)
          end
        end)
        return true
      end,
    })
    :find()
end

-- Registered at file-body level by each plugin file, which core/lazy.lua runs
-- while collecting specs -- so ops exist before the plugin loads, or without it.
local ops = {}

function M.register(name, table_of_ops)
  ops[name] = table_of_ops
end

-- pcall'd: a backend commented out of enabled.lua has no spec for lazy to find.
local loaded = {}

local function ensure_loaded(spec)
  if loaded[spec.name] then
    return
  end
  loaded[spec.name] = true
  pcall(function()
    require('lazy').load { plugins = { spec.plugin:match '[^/]+$' } }
  end)
end

-- For capabilities only some backends have. Returning nil is load-bearing and
-- deliberately not `call`'s warning -- see the note atop util/ai/prompt.lua.
function M.try(op, ...)
  local spec = M.get()
  local fn = ops[spec.name] and ops[spec.name][op]
  if not fn then
    return nil
  end
  ensure_loaded(spec)
  return fn(...)
end

-- Warns rather than no-ops: with two agents running, silence is
-- indistinguishable from having sent the keystroke to the wrong one.
function M.call(op, ...)
  local spec = M.get()
  local fn = ops[spec.name] and ops[spec.name][op]
  if not fn then
    vim.notify(('%s does not support %s'):format(spec.name, op), vim.log.levels.WARN)
    return
  end
  ensure_loaded(spec)
  return fn(...)
end

function M.status()
  local spec = M.get()
  return spec.icon .. ' ' .. spec.name
end

-- Anchored on the pid in "term://{cwd}//{pid}:{command}", and argv[0]'s basename
-- compared for equality: a substring test matches `omp` inside docker-compose.
function M.backend_for_terminal(name)
  local cmd = name:match '//%d+:(.+)$' or name:match ':([^:]*)$'
  local argv0 = cmd and cmd:match '^%S+'
  local exe = argv0 and vim.fs.basename(argv0)
  if not exe then
    return nil
  end
  for _, spec in ipairs(BACKENDS) do
    if exe == spec.exe then
      return spec
    end
  end
  return nil
end

function M.is_agent_terminal(buf)
  buf = buf or 0
  if vim.bo[buf].buftype ~= 'terminal' then
    return nil
  end
  return M.backend_for_terminal(vim.api.nvim_buf_get_name(buf))
end

return M
