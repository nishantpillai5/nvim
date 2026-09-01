-- The whisper indicator for lualine, as one component: `filename mic`. The mic
-- says whether anything holds the microphone; it breathes, and the filename
-- appears naming the buffer, only while words are actually landing.
local M = {}

-- The mic breathes by alternating fill while words land -- one icon, and
-- readable without colour. The slashed mic says only that nothing holds the
-- microphone: Claude dictation and buffer dictation are mutually exclusive (see
-- plugins/whisper.lua), so a live session is a live session either way and there
-- is nothing left for a second shape to distinguish.
local MIC, MIC_HOLLOW, MIC_OFF = '󰍬', '󰍮', '󰍭'
local THROB = { MIC, MIC_HOLLOW }
-- Per frame, so a full breath is twice this. Also the rate the whole tabline
-- recomputes at while transcribing, so it is not worth pushing much lower.
local PULSE_MS = 400

-- Floats are wrapped in this config's list brackets rather than given an icon of
-- their own -- one icon is the point. A buffer name can't tell a float from a
-- split, and floats are usually scratch buffers with no name at all.
local FLOAT = { '｢', '｣' }

---@type uv.uv_timer_t?
local pulse
-- Index into THROB, advanced by the pulse timer rather than read off the clock:
-- lualine also refreshes on its own timer and on events, and those extra renders
-- have to repeat the current frame instead of jittering the breath.
local frame = 1

-- Whisper is only *writing* while its poll timer is alive. arm() in
-- plugins/whisper.lua leaves `recording` true with the timer stopped and a stale
-- insert position, so is_recording() on its own would name a buffer that never
-- receives a word. is_processing() covers the manual trigger, which polls with
-- defer_fn instead of the timer.
function M.is_writing()
  if not package.loaded['whisper'] then
    return false
  end
  local state = require 'whisper.state'
  return state.is_recording() and (state.get_poll_timer() ~= nil or state.is_processing())
end

-- The buffer text will land in. A missing or dead insert position is not an
-- error: audio.insert_streaming_text falls back to insert.insert_text, which
-- writes at the cursor of whatever buffer is current.
local function target_buf()
  local pos = package.loaded['whisper'] and require('whisper.state').get_insert_position()
  if pos and pos.buf and vim.api.nvim_buf_is_valid(pos.buf) then
    return pos.buf
  end
  return vim.api.nvim_get_current_buf()
end

-- A window showing `buf`, preferring a floating one, plus whether it floats. Nil
-- when the buffer is being written to while hidden.
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

-- Floats name themselves in their border title, which beats a scratch buffer's
-- number. `title` is either a string or a list of [text, highlight] chunks.
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

-- lualine caches the rendered tabline and recomputes it on its own 1s timer, so
-- `redrawtabline` would only repaint the same frame: the breath has to ask
-- lualine for a refresh. This timer runs only while whisper is writing.
function M.start()
  if pulse then
    return
  end
  frame = 1
  pulse = assert(vim.uv.new_timer())
  pulse:start(
    PULSE_MS,
    PULSE_MS,
    vim.schedule_wrap(function()
      if M.is_writing() then
        frame = frame % #THROB + 1
      else
        M.stop()
      end
      -- Queued rather than forced: lualine coalesces refreshes on a 16ms timer
      -- of its own. The component lives in the tabline.
      pcall(function()
        require('lualine').refresh { place = { 'tabline' } }
      end)
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
  frame = 1
end

-- The one icon. A nil flag means whisper is not in this config at all, which is
-- the only case the component renders nothing for.
local function mic()
  if vim.g.whisper_auto_dictate == nil then
    return ''
  end

  local recording, model_loaded = false, true
  if package.loaded['whisper'] then
    local state = require 'whisper.state'
    recording, model_loaded = state.is_recording(), state.is_model_loaded()
  end

  -- Nothing armed for Claude and no buffer session running: the mic is free.
  if not recording and not vim.g.whisper_auto_dictate then
    return MIC_OFF
  end
  -- Still paging in the 3.1GB model. Said in words rather than breathed, because
  -- nothing can land yet.
  if recording and not model_loaded then
    return MIC .. ' Loading'
  end
  return M.is_writing() and THROB[frame] or MIC
end

-- `filename mic` while writing, bare mic otherwise. Also owns the pulse timer's
-- lifetime, so the indicator needs nothing in the lualine spec but this one
-- component.
function M.status()
  local parts = {}

  if M.is_writing() then
    M.start()
    local buf = target_buf()
    local win, floating = window_for(buf)
    local label = (floating and win and float_title(win)) or buf_label(buf)
    parts[1] = floating and (FLOAT[1] .. label .. FLOAT[2]) or label
  else
    M.stop()
  end

  local icon = mic()
  if icon ~= '' then
    table.insert(parts, icon)
  end
  return table.concat(parts, ' ')
end

return M
