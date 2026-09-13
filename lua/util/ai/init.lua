-- Which AI backend <leader>a talks to, and the registry the backends are
-- declared in. Claude Code and OMP are separate agents in separate terminals
-- that share nothing; this module is what lets one set of keymaps point at
-- whichever is active, and what the tabline indicator reads to say which that
-- is. See the AI section of README.md.
--
-- Required from a lualine component, so it has to stay safe to load before
-- either plugin is on the runtimepath: nothing here touches claudecode.nvim or
-- omp.nvim, and every field is static or resolved from the buffer list.
--
-- Phase 0 of the plan: identity, availability and terminal detection only. The
-- operations (send_raw, show, scrape_*, sessions) and the capability flags that
-- go with them land when the keymaps start dispatching through here.

local M = {}

-- Declaration order is both the cycle order and the default preference: the
-- first available backend is the one a session starts on.
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

-- lua/enabled.lua is read once at startup and cannot change afterwards, so this
-- is resolved on first use and kept.
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

-- vim.fn.executable stats every PATH entry. Availability is asked on the first
-- get() and on each cycle, never per redraw -- but PATH doesn't change under a
-- running session either way, so cache it.
local executable = {}

local function has_exe(spec)
  local cached = executable[spec.exe]
  if cached == nil then
    cached = vim.fn.executable(spec.exe) == 1
    executable[spec.exe] = cached
  end
  return cached
end

-- Enabled in enabled.lua *and* installed. Cycling skips anything unavailable,
-- so switching can never leave the keymaps pointing at a CLI that isn't there.
function M.available(spec)
  return is_enabled(spec) and has_exe(spec)
end

-- nil until the first get(): resolving the default touches PATH, and this
-- module is required during startup.
local current = nil

local function default_backend()
  for _, spec in ipairs(BACKENDS) do
    if M.available(spec) then
      return spec
    end
  end
  -- Nothing installed. Fall back to the first declared backend rather than
  -- returning nil, so callers need no extra guard -- the keymaps already report
  -- a missing terminal when one is asked for.
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
      -- Nothing else dirties the tabline, and lualine only repaints on redraw.
      vim.cmd.redrawtabline()
      vim.api.nvim_exec_autocmds('User', { pattern = 'AiBackendChanged', modeline = false })
      return spec
    end
  end
  vim.notify('No such AI backend: ' .. tostring(name), vim.log.levels.WARN)
end

-- Next available backend, wrapping. Unavailable ones are stepped over, so with
-- one installed this is a no-op that says so rather than appearing to switch.
function M.cycle()
  local active = M.get()
  local start = 1
  for i, spec in ipairs(BACKENDS) do
    if spec == active then
      start = i
      break
    end
  end
  for step = 1, #BACKENDS - 1 do
    local spec = BACKENDS[(start + step - 1) % #BACKENDS + 1]
    if M.available(spec) then
      -- Silent on success: the tabline indicator is the feedback. The warnings
      -- here and in `set` stay -- those report a switch that did not happen.
      M.set(spec.name)
      return spec
    end
  end
  vim.notify('No other AI backend available', vim.log.levels.WARN)
end

-- Backend operations, registered by the plugin files. Keeping them there rather
-- than here is what stops this module from needing to know how either agent is
-- driven: plugins/claudecode.lua and plugins/omp.lua already own their terminals
-- and their quirks, and each hands over a table of the operations the shared
-- <leader>a keys dispatch to.
--
-- Registration happens at *file body* level, which core/lazy.lua runs for every
-- module under lua/plugins/ while it collects specs -- so the table is here long
-- before its plugin loads, and regardless of whether enabled.lua asked for that
-- plugin at all. An op table existing therefore says nothing about the plugin
-- being loaded; ops load it themselves on first use, via `call` below.
local ops = {}

function M.register(name, table_of_ops)
  ops[name] = table_of_ops
end

-- lazy.nvim keys loading on the plugin's short name, and is a no-op once the
-- plugin is in. Wrapped because a backend whose plugin is commented out of
-- enabled.lua has no spec for lazy to find.
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

-- Run `op` on the active backend if it has one, and return nil if it doesn't.
-- For capabilities only some backends have: a scraper that reads a terminal, a
-- command list, a mention format. Silence is the *correct* answer there, and
-- deliberately not the same silence as `call`'s warning -- see the note at the
-- top of util/ai/prompt.lua for what inheriting another agent's scraper would
-- have done.
function M.try(op, ...)
  local spec = M.get()
  local fn = ops[spec.name] and ops[spec.name][op]
  if not fn then
    return nil
  end
  ensure_loaded(spec)
  return fn(...)
end

-- Run `op` on the active backend. An operation a backend does not implement
-- reports itself rather than doing nothing: silence here reads as a key that
-- didn't register, and with two agents running it would be indistinguishable
-- from having sent the keystroke to the wrong one.
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

-- The backend a term:// buffer *name* refers to, or nil. Terminal buffers are
-- named "term://{cwd}//{pid}:{command}": the split is anchored on the pid so
-- neither a cwd nor an argument containing a colon can shift it, and argv[0]'s
-- basename is compared for *equality*. A substring test would match `omp` inside
-- docker-compose and `claude` inside a shell started in a .claude/ directory.
--
-- Split out from is_agent_terminal because this is the half with the sharp
-- edges and the only half that can be tested: 'terminal' is not a buftype a
-- buffer can be given, so a real one cannot be synthesised to check it against.
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

-- The backend whose CLI runs in `buf`, or nil.
function M.is_agent_terminal(buf)
  buf = buf or 0
  if vim.bo[buf].buftype ~= 'terminal' then
    return nil
  end
  return M.backend_for_terminal(vim.api.nvim_buf_get_name(buf))
end

return M
