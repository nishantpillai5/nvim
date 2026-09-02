-- The whisper indicators for lualine, as two components. M.status is
-- `pulse filename`: it shows up only while words are landing, and names the
-- buffer they land in. M.mic says whether the agent prompt box is armed
-- (<leader>ad in plugins/whisper.lua) -- armed, not listening -- and sits after
-- the AI backend label instead, since between them they say where a dictated
-- prompt would go.
local M = {}

local MIC, MIC_OFF = '󰍬', '󰍭'

-- A breathing wave rather than a spinner: it reads as a level rather than a
-- busy indicator. It leads the component -- the mic it used to sit beside now
-- lives after the backend label. The frame comes off the clock, so the speed is
-- refresh-independent.
local FRAMES = { '󰕿', '󰖀', '󰕾', '󰖀' }
-- Also the rate the whole tabline recomputes at while transcribing.
local PULSE_MS = 500

-- Floats are usually scratch buffers with no name, and a name can't tell a float
-- from a split.
local FLOAT_ICON = ''

---@type uv.uv_timer_t?
local pulse

-- Whisper is only *writing* while its poll timer is alive: between boxes the
-- stream lingers for its idle window with `recording` still true and a stale
-- insert position. is_processing() covers the defer_fn-based manual trigger.
function M.is_writing()
  if not package.loaded['whisper'] then
    return false
  end
  local state = require 'whisper.state'
  return state.is_recording() and (state.get_poll_timer() ~= nil or state.is_processing())
end

-- A dead insert position is not an error: insert_streaming_text falls back to
-- writing at the cursor of whatever buffer is current.
local function target_buf()
  local pos = package.loaded['whisper'] and require('whisper.state').get_insert_position()
  if pos and pos.buf and vim.api.nvim_buf_is_valid(pos.buf) then
    return pos.buf
  end
  return vim.api.nvim_get_current_buf()
end

-- Nil when the buffer is being written to while hidden.
local function window_for(buf)
  local fallback
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      if vim.api.nvim_win_get_config(win).relative ~= '' then
        return win, true
      end
      fallback = fallback or win
    end
  end
  return fallback, false
end

-- `title` is either a string or a list of [text, highlight] chunks.
local function float_title(win)
  local title = vim.api.nvim_win_get_config(win).title
  if type(title) == 'string' then
    return vim.trim(title)
  end
  if type(title) ~= 'table' then
    return nil
  end
  local chunks = {}
  for _, chunk in ipairs(title) do
    table.insert(chunks, type(chunk) == 'table' and chunk[1] or chunk)
  end
  local text = vim.trim(table.concat(chunks))
  return text ~= '' and text or nil
end

local function buf_label(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name ~= '' then
    return vim.fn.fnamemodify(name, ':t')
  end
  local ft = vim.bo[buf].filetype
  return ft ~= '' and ft or ('buffer ' .. buf)
end

-- lualine caches the tabline and recomputes it on its own 1s timer, so
-- `redrawtabline` would only repaint the same frame: the pulse has to ask.
function M.start()
  if pulse then
    return
  end
  pulse = vim.uv.new_timer()
  pulse:start(
    PULSE_MS,
    PULSE_MS,
    vim.schedule_wrap(function()
      if not M.is_writing() then
        M.stop()
      end
      local ok, lualine = pcall(require, 'lualine')
      if ok then
        -- Queued, not forced: lualine coalesces on a 16ms timer of its own.
        pcall(lualine.refresh, { place = { 'tabline' } })
      end
    end)
  )
end

function M.stop()
  if not pulse then
    return
  end
  pulse:stop()
  pulse:close()
  pulse = nil
end

-- A nil flag means whisper is not in this config at all, the one case that
-- renders nothing.
function M.mic()
  if vim.g.whisper_auto_dictate == nil then
    return ''
  elseif not vim.g.whisper_auto_dictate then
    return MIC_OFF
  end
  -- Still paging in the model, so nothing can land yet. Once per cold start,
  -- which plugins/whisper.lua keeps honest by resetting model_loaded.
  if package.loaded['whisper'] then
    local state = require 'whisper.state'
    if state.is_recording() and not state.is_model_loaded() then
      return MIC .. ' Loading'
    end
  end
  return MIC
end

-- Also owns the pulse timer's lifetime, so the lualine spec needs nothing else.
-- That ownership is why this component and not M.mic is the one that has to stay
-- in the spec: M.mic can be moved anywhere, this cannot be dropped.
function M.status()
  if not M.is_writing() then
    M.stop()
    return ''
  end
  M.start()
  local buf = target_buf()
  local win, floating = window_for(buf)
  local label = (floating and win and float_title(win)) or buf_label(buf)
  local name = (floating and (FLOAT_ICON .. ' ') or '') .. label
  return FRAMES[math.floor(vim.uv.now() / PULSE_MS) % #FRAMES + 1] .. ' ' .. name
end

return M
