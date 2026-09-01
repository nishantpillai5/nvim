-- Speech to text via whisper.cpp. <leader>nd comes from `keybind`; the lazy key
-- is only a stub. <leader>ad arms dictation into Claude's prompt box.
--
-- Arming does not start whisper-stream: in VAD mode it holds the mic open and
-- runs large-v3 over the trailing window every time it hears anything at all
-- (stream.cpp:302), box or not. So the stream is spawned by the first prompt box
-- and torn down IDLE_MS after the last one closes, which within a session leaves
-- it warm across turns and charges only the first box for the load.

-- Whisper's stock captions for silence, matched against a whole line with
-- punctuation and spaces stripped.
local HALLUCINATED = {
  thankyou = true,
  thankyouverymuch = true,
  thanksforwatching = true,
  thankyouforwatching = true,
  thanksforlistening = true,
  pleasesubscribe = true,
  you = true,
  bye = true,
}

-- Long enough to span a Claude turn, short enough that walking away closes the
-- mic. It only buys back ~0.5s of load, so erring long costs more.
local IDLE_MS = 120000

-- VAD mode re-transcribes the last `length_ms` on every fire and never clears
-- the buffer (stream.cpp:305), so chunks arrive carrying the previous tail.
local last_words = {}

local function normalise(word)
  return (word:lower():gsub('%p', ''))
end

local function drop_overlap(text)
  local words = vim.split(text, '%s+', { trimempty = true })
  for k = math.min(#last_words, #words), 1, -1 do
    local same = true
    for i = 1, k do
      if normalise(last_words[#last_words - k + i]) ~= normalise(words[i]) then
        same = false
        break
      end
    end
    if same then
      words = vim.list_slice(words, k + 1)
      break
    end
  end
  if #words > 0 then
    last_words = vim.split(text, '%s+', { trimempty = true })
  end
  return table.concat(words, ' ')
end

local function cfg(overrides)
  return vim.tbl_extend('force', require('whisper.config').get(), overrides or {})
end

local function transcript_lines()
  local temp = require('whisper.state').get_temp_file()
  if not temp or vim.fn.filereadable(temp) ~= 1 then
    return 0
  end
  return #vim.fn.readfile(temp)
end

-- stop_polling ends in a final poll, which inserts at the cursor when its target
-- buffer is gone. Anything unread has to be written off first.
local function skip_pending()
  require('whisper.state').set_last_read_line(transcript_lines())
end

-- The require pulls the plugin in through lazy, so cfg() sees the real config.
local function model_ready()
  require 'whisper'
  local model = cfg().model
  if require('whisper.model').model_exists(model) then
    return true
  end
  vim.notify('whisper: ' .. model .. ' is not downloaded', vim.log.levels.ERROR)
  return false
end

---@type uv.uv_timer_t?
local idle

local function cancel_idle()
  if idle then
    idle:stop()
    idle:close()
    idle = nil
  end
end

local function stop_stream()
  cancel_idle()
  if package.loaded['whisper'] and require('whisper.state').is_recording() then
    skip_pending()
    require('whisper.audio').stop_recording()
  end
end

-- `timer` is captured: a box that opens and closes again in the tick before this
-- runs would otherwise be torn down by its predecessor.
local function arm_idle()
  cancel_idle()
  local timer = vim.uv.new_timer()
  idle = timer
  timer:start(
    IDLE_MS,
    0,
    vim.schedule_wrap(function()
      if idle == timer then
        stop_stream()
      end
    end)
  )
end

-- start_recording pins the insert position to the current window and starts
-- polling itself, so this needs the prompt box current and no attach after.
local function start_stream()
  if not model_ready() then
    return false
  end
  local state = require 'whisper.state'
  -- state.clear keeps model_loaded across runs, so a restart would otherwise
  -- claim the fresh process is ready the moment it spawns. lualine reads it.
  state.set_model_loaded(false)
  -- <C-g>: whisper never restores the mapping it takes, and <Tab> is claudecode's.
  require('whisper.audio').start_recording(cfg { manual_trigger_key = '<C-g>' })
  return state.is_recording()
end

local function attach(bufnr)
  local state = require 'whisper.state'
  cancel_idle()
  last_words = {}
  if not state.is_recording() then
    if not start_stream() then
      return
    end
  else
    -- A warm stream has been transcribing the room since the last box.
    local cursor = vim.api.nvim_win_get_cursor(0)
    state.set_insert_position { buf = bufnr, row = cursor[1], col = cursor[2] }
    state.set_recording_buffer(bufnr)
    skip_pending()
    require('whisper.audio').start_polling(cfg())
  end
  vim.g.whisper_dictating = true
  -- Pulse now rather than at lualine's next 1s tick.
  require('util.whisper').start()
end

local function detach()
  vim.g.whisper_dictating = false
  if not (package.loaded['whisper'] and require('whisper.state').is_recording()) then
    return
  end
  skip_pending()
  require('whisper.audio').stop_polling(cfg())
  arm_idle()
end

local function auto_dictate(bufnr)
  local state = require 'whisper.state'
  -- Returning to a box we left has to re-attach, since BufLeave detached it.
  if vim.g.whisper_dictating and state.get_recording_buffer() == bufnr then
    return
  end

  if not vim.b[bufnr].whisper_auto_dictate then
    vim.b[bufnr].whisper_auto_dictate = true
    vim.api.nvim_create_autocmd({ 'BufLeave', 'BufWipeout' }, {
      buffer = bufnr,
      desc = 'stop dictating when the Claude prompt box loses focus',
      callback = detach,
    })
  end

  -- Deferred: the box moves the cursor past a prefilled @mention after
  -- startinsert, and attach pins the insert position.
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_get_current_buf() == bufnr then
      attach(bufnr)
    end
  end)
end

return {
  {
    'Avi-D-coder/whisper.nvim',
    cmd = { 'WhisperToggle', 'WhisperDownloadModel' },
    keys = {
      { '<leader>nd', mode = { 'n', 'i', 'v' }, desc = 'stt' },
    },
    init = function()
      vim.g.whisper_auto_dictate = false
      vim.g.whisper_dictating = false

      vim.keymap.set('n', '<leader>ad', function()
        if vim.g.whisper_auto_dictate then
          vim.g.whisper_auto_dictate = false
          vim.g.whisper_dictating = false
          stop_stream()
          vim.notify 'Claude dictation off'
        elseif model_ready() then
          vim.g.whisper_auto_dictate = true
          vim.notify 'Claude dictation on'
        end
      end, { desc = 'dictation_toggle' })

      vim.api.nvim_create_autocmd('InsertEnter', {
        group = vim.api.nvim_create_augroup('whisper_claude_prompt', { clear = true }),
        desc = 'dictate into the Claude prompt box',
        callback = function(args)
          if vim.b[args.buf].claude_prompt and vim.g.whisper_auto_dictate then
            auto_dictate(args.buf)
          end
        end,
      })
    end,
    opts = {
      -- An unknown name is not an error: model.lua falls back to base.en.
      model = 'large-v3',
      keybind = '<leader>nd',
      manual_trigger_key = '<Tab>',
      -- Also strips VAD mode's [timestamp] prefixes, so it is load-bearing.
      filter_markers = true,
      notifications = false,
      -- 0 selects VAD mode: transcribe on a pause rather than every step.
      step_ms = 0,
      length_ms = 10000,
      vad_thold = 0.6,
      poll_interval_ms = 100,
    },
    config = function(_, opts)
      require('whisper').setup(opts)

      local audio = require 'whisper.audio'
      local filter_text = audio.filter_text
      ---@diagnostic disable-next-line: duplicate-set-field
      audio.filter_text = function(text)
        local out = filter_text(text)
        return HALLUCINATED[out:lower():gsub('[%p%s]', '')] and '' or out
      end

      local insert_streaming_text = audio.insert_streaming_text
      ---@diagnostic disable-next-line: duplicate-set-field
      audio.insert_streaming_text = function(text)
        local fresh = drop_overlap(text or '')
        if fresh ~= '' then
          insert_streaming_text(fresh)
        end
      end
    end,
  },
}
