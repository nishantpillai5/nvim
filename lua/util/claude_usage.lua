-- The percentages claude.ai shows, straight from the server: `/usage` is the
-- only local way to them, since the statusLine that carries `rate_limits` stays
-- suppressed for the IDE sessions claudecode.nvim starts.

local M = {}

-- No MCP servers, since they are irrelevant here and cost seconds of startup;
-- no session either, or every refresh would leave a transcript behind.
local CMD = {
  'claude',
  '-p',
  '/usage',
  '--no-session-persistence',
  '--strict-mcp-config',
  '--mcp-config',
  '{"mcpServers":{}}',
}

-- The numbers move slowly, and each fetch is a CLI spawn.
local TTL = 3 * 60 * 1000

local MONTHS =
  { Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6, Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12 }

local state = { running = false, fetched_at = nil, usage = nil }

-- `Sep 18 at 2pm`, `Sep 22 at 12:59am` -- a local wall clock with no year.
local function parse_reset(when)
  local month, day, hour, min, meridiem = when:match '(%a+) (%d+) at (%d+):?(%d*)([ap]m)'
  if not MONTHS[month or ''] then
    return nil
  end
  hour = tonumber(hour) % 12
  if meridiem == 'pm' then
    hour = hour + 12
  end
  local fields = { month = MONTHS[month], day = tonumber(day), hour = hour, min = tonumber(min) or 0, sec = 0 }
  fields.year = os.date('*t').year
  local at = os.time(fields)
  -- A reset in the past means the year rolled over between the two.
  if at < os.time() - 86400 then
    fields.year = fields.year + 1
    at = os.time(fields)
  end
  return at
end

local function parse(out)
  local usage = {}
  local session, when = out:match 'Current session: (%d+)%% used[^\n]-resets ([^(\n]+)'
  usage.session = tonumber(session)
  usage.resets_at = when and parse_reset(when)
  -- The per-model bucket is whatever the server scoped this week to, so keep
  -- its label rather than looking for one.
  for label, percent in out:gmatch 'Current week %(([^)]+)%): (%d+)%%' do
    if label == 'all models' then
      usage.week = tonumber(percent)
    else
      usage.model, usage.model_label = tonumber(percent), label
    end
  end
  return usage.session and usage or nil
end

local function fetch()
  state.running = true
  vim.system(CMD, {
    text = true,
    -- Any cwd works, and this one is always a trusted workspace.
    cwd = vim.fn.stdpath 'config',
  }, function(result)
    local usage = result.code == 0 and parse(result.stdout or '')
    vim.schedule(function()
      state.running = false
      -- Keep the last good numbers on a failure; only the clock decides retries.
      state.fetched_at = vim.uv.now()
      state.usage = usage or state.usage
    end)
  end)
end

local function countdown(at)
  local left = at - os.time()
  if left <= 0 then
    return nil
  end
  local hours, minutes = math.floor(left / 3600), math.floor(left % 3600 / 60)
  if hours > 24 then
    return ('%dd%dh'):format(math.floor(hours / 24), hours % 24)
  end
  return hours > 0 and ('%dh%02dm'):format(hours, minutes) or ('%dm'):format(minutes)
end

---@return string
function M.status()
  if
    not state.running
    and (not state.fetched_at or vim.uv.now() - state.fetched_at > TTL)
    and vim.fn.executable 'claude' == 1
  then
    fetch()
  end

  local usage = state.usage
  if not usage then
    return ''
  end

  local parts = { ('%d%%%%'):format(usage.session) }
  local left = usage.resets_at and countdown(usage.resets_at)
  if left then
    parts[#parts + 1] = left
  end
  if usage.week then
    parts[#parts + 1] = ('w%d%%%%'):format(usage.week)
  end
  if usage.model then
    parts[#parts + 1] = ('%s%d%%%%'):format(usage.model_label:sub(1, 1), usage.model)
  end

  local text = '󰄪 ｢' .. table.concat(parts, ' · ') .. '｣'
  local worst = math.max(usage.session, usage.week or 0, usage.model or 0)
  if worst >= 95 then
    return '%#DiagnosticError#' .. text .. '%*'
  elseif worst >= 80 then
    return '%#DiagnosticWarn#' .. text .. '%*'
  end
  return text
end

return M
