-- The whisper indicators for lualine: M.status is `pulse filename`, shown while
-- words land; M.mic says whether the prompt box is armed, not whether it hears.
local M = {}

local MIC, MIC_OFF = '󰍬', '󰍭'

-- A wave rather than a spinner: it reads as a level, not a busy indicator. The
-- frame comes off the clock, so the speed is refresh-independent.
local FRAMES = { '󰕿', '󰖀', '󰕾', '󰖀' }
-- Also the rate the whole tabline recomputes at while transcribing.
local PULSE_MS = 500

-- Floats are usually unnamed scratch buffers, and a name tells you no more.
local FLOAT_ICON = ''

---@type uv.uv_timer_t?
local pulse

-- Only *writing* while the poll timer is alive: between boxes the stream
-- lingers with `recording` still true and a stale insert position.
function M.is_writing()
  if not package.loaded['whisper'] then
    return false
  end
  local state = require 'whisper.state'
  return state.is_recording() and (state.get_poll_timer() ~= nil or state.is_processing())
end

-- A dead insert position is not an error: insert_streaming_text falls back to
-- the current buffer's cursor.
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

-- lualine recomputes the tabline on its own 1s timer, so `redrawtabline` would
-- only repaint the same frame -- the pulse has to ask.
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

-- nil means whisper is not in this config at all, the one case rendering ''.
function M.mic()
  if vim.g.whisper_auto_dictate == nil then
    return ''
  elseif not vim.g.whisper_auto_dictate then
    return MIC_OFF
  end
  -- Still paging in the model, so nothing can land yet.
  if package.loaded['whisper'] then
    local state = require 'whisper.state'
    if state.is_recording() and not state.is_model_loaded() then
      return MIC .. ' Loading'
    end
  end
  return MIC
end

-- Owns the pulse timer's lifetime, so this is the component that has to stay in
-- the lualine spec; M.mic can be moved anywhere.
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
