-- Speech to text via whisper.cpp. <leader>nd comes from `keybind`; the lazy key
-- is only a stub. <leader>ad arms dictation into Claude's prompt box, starting
-- whisper-stream once so the 3.1GB model is resident before the first box.

-- Whisper's stock silence captions, matched with punctuation and spaces stripped.
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

-- Which flow owns the running whisper-stream. One process and one insert
-- position, so whichever attached second would re-point the other's words.
local buffer_session = false

local function buffer_dictating()
  return buffer_session and require('whisper.state').is_recording()
end

local function arm()
  require 'whisper'
  if buffer_dictating() then
    vim.notify('buffer dictation is running -- <leader>nd to stop it', vim.log.levels.WARN)
    return false
  end
  local state = require 'whisper.state'
  -- A disarm still winding down: reuse the resident model rather than reload it.
  if state.is_recording() then
    return true
  end
  -- <C-g>: whisper maps its trigger into the arming buffer and never puts the
  -- old mapping back, and <Tab> is claudecode's.
  local conf = cfg { manual_trigger_key = '<C-g>' }
  if not require('whisper.model').model_exists(conf.model) then
    vim.notify('whisper: ' .. conf.model .. ' is not downloaded', vim.log.levels.ERROR)
    return false
  end
  local audio = require 'whisper.audio'
  audio.start_recording(conf)
  skip_pending()
  audio.stop_polling(conf)
  return state.is_recording()
end

local function disarm()
  if package.loaded['whisper'] and require('whisper.state').is_recording() then
    skip_pending()
    require('whisper.audio').stop_recording()
  end
end

local function attach(bufnr)
  local state = require 'whisper.state'
  if not state.is_recording() then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  state.set_insert_position { buf = bufnr, row = cursor[1], col = cursor[2] }
  state.set_recording_buffer(bufnr)
  last_words = {}
  skip_pending()
  require('whisper.audio').start_polling(cfg())
  -- Breathe now rather than at lualine's next 1s tick.
  require('util.whisper').start()
end

local function detach()
  if not (package.loaded['whisper'] and require('whisper.state').is_recording()) then
    return
  end
  skip_pending()
  require('whisper.audio').stop_polling(cfg())
end

local function auto_dictate(bufnr)
  if vim.b[bufnr].whisper_auto_dictate then
    return
  end
  vim.b[bufnr].whisper_auto_dictate = true

  -- Deferred: the box moves the cursor past a prefilled @mention after
  -- startinsert, and attach pins the insert position.
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_get_current_buf() == bufnr then
      attach(bufnr)
    end
  end)

  vim.api.nvim_create_autocmd({ 'BufLeave', 'BufWipeout' }, {
    buffer = bufnr,
    once = true,
    desc = 'stop dictating when the Claude prompt box goes away',
    callback = detach,
  })
end

return {
  {
    'Avi-D-coder/whisper.nvim',
    cmd = { 'WhisperToggle', 'WhisperDownloadModel' },
    keys = {
      { '<leader>nd', mode = { 'n', 'i', 'v' }, desc = 'dictation' },
    },
    init = function()
      vim.g.whisper_auto_dictate = false

      vim.keymap.set('n', '<leader>ad', function()
        if vim.g.whisper_auto_dictate then
          disarm()
          vim.g.whisper_auto_dictate = false
          vim.notify 'Claude dictation off'
        elseif arm() then
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
      -- 0 selects VAD mode: transcribe on pause. length is the utterance buffer.
      step_ms = 0,
      length_ms = 10000,
      vad_thold = 0.6,
      poll_interval_ms = 100,
    },
    config = function(_, opts)
      require('whisper').setup(opts)

      local audio = require 'whisper.audio'

      -- All three entry points resolve toggle_recording at call time
      -- (whisper/init.lua:9), so one patch covers <leader>nd and both commands.
      local toggle_recording = audio.toggle_recording
      ---@diagnostic disable-next-line: duplicate-set-field
      audio.toggle_recording = function(conf)
        if vim.g.whisper_auto_dictate then
          vim.notify('Claude dictation holds the mic -- <leader>ad to turn it off', vim.log.levels.WARN)
          return
        end
        buffer_session = not require('whisper.state').is_recording()
        toggle_recording(conf)
      end

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
