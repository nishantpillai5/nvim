-- The whisper indicator for lualine, as one component: `filename pulse mic`.
-- The mic on its own says whether Claude's prompt box is armed (<leader>ad in
-- plugins/whisper.lua); the filename and the pulse show up only while words are
-- actually landing, and name the buffer they land in.
local M = {}

local MIC, MIC_OFF = '󰍬', '󰍭'

-- A breathing wave rather than a spinner, so it reads as a level next to the
-- static mic. The frame is picked from the clock, so the pulse keeps its speed
-- whatever rate lualine happens to be refreshing at.
local FRAMES = { '󰕿', '󰖀', '󰕾', '󰖀' }
-- A full breath per cycle. Also the rate the whole tabline recomputes at while
-- transcribing, so it is not worth pushing much lower.
local PULSE_MS = 200

-- Floating targets (Claude's prompt box, any snacks input) get a marker: a
-- buffer name alone can't tell a float from a split, and floats are usually
-- scratch buffers with no name at all.
local FLOAT_ICON = ''

---@type uv.uv_timer_t?
local pulse

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
-- `redrawtabline` would only repaint the same frame: the pulse has to ask lualine
-- for a refresh. This timer runs only while whisper is writing.
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
        -- Queued rather than forced: lualine coalesces refreshes on a 16ms
        -- timer of its own. The component lives in the tabline.
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

-- The mic half. A nil flag means whisper is not in this config at all, which is
-- the one case the component renders nothing at all for.
local function mic()
  if vim.g.whisper_auto_dictate == nil then
    return ''
  elseif not vim.g.whisper_auto_dictate then
    return MIC_OFF
  end
  -- Armed but still paging in the 3.1GB model: nothing can land yet, so there is
  -- no pulse to pair this with.
  if package.loaded['whisper'] then
    local state = require 'whisper.state'
    if state.is_recording() and not state.is_model_loaded() then
      return MIC .. ' Loading'
    end
  end
  return MIC
end

-- `filename pulse mic` while writing, bare mic otherwise. Also owns the pulse
-- timer's lifetime, so the indicator needs nothing in the lualine spec but this
-- one component.
function M.status()
  local parts = {}

  if M.is_writing() then
    M.start()
    local buf = target_buf()
    local win, floating = window_for(buf)
    local label = (floating and win and float_title(win)) or buf_label(buf)
    parts[1] = (floating and (FLOAT_ICON .. ' ') or '') .. label
    parts[2] = FRAMES[math.floor(vim.uv.now() / PULSE_MS) % #FRAMES + 1]
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
