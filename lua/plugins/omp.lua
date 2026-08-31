-- Oh My Pi (`omp`) as an alternative to claudecode.nvim, on <leader>c instead of
-- <leader>a. Both can be enabled at once; they run separate agents in separate
-- terminals and share nothing.
--
-- The plugin itself is only a context bridge: it follows the cursor and pushes
-- "<file>:<line>" -- or "<file>:<start>-<end>" while a visual selection is
-- active -- over a unix socket to every OMP session started in the same cwd, so
-- the agent always knows what you are looking at. There is no attach-file or
-- attach-selection key here because there is nothing to attach by hand: just
-- ask about "this function" and OMP already has the path and the lines.
--
-- Everything else below is ours. OMP is a plain TUI, so the panel it runs in and
-- getting a prompt into it are this file's job, not the plugin's.

local ID = 99 -- toggleterm slot, well clear of the numbered terminals <leader>o; cycles
local WIDTH = 0.45 -- share of the columns the panel takes, matching the Claude panel

-- The one OMP terminal, or nil when none has been started this session.
local term = nil

local function size()
  return math.floor(vim.o.columns * WIDTH)
end

local ESC_TIMEOUT = 200 -- ms in which a second <Esc> means "leave terminal mode", not "another escape"

-- Reused across presses, and there is only ever one OMP terminal.
local esc_timer = nil

-- <Esc> closes OMP's own dialogs, but lua/core/keymaps.lua binds it in terminal
-- mode to leave terminal-insert, so Neovim swallows it before OMP sees it. In
-- this buffer only -- every other terminal keeps <Esc> as its exit -- the first
-- <Esc> goes through to OMP and a second one within ESC_TIMEOUT leaves terminal
-- mode instead.
local function double_esc()
  -- Only ever nil if the process is out of file descriptors, in which case
  -- there is nothing sensible to fall back to.
  esc_timer = esc_timer or assert(vim.uv.new_timer())
  if esc_timer:is_active() then
    esc_timer:stop()
    return [[<C-\><C-n>]]
  end
  -- An empty callback: the handle's own active/idle state is the whole signal.
  esc_timer:start(ESC_TIMEOUT, 0, function() end)
  return '<Esc>'
end

local function set_terminal_keys(bufnr)
  vim.keymap.set('t', '<Esc>', double_esc, {
    buffer = bufnr,
    expr = true,
    silent = true,
    desc = 'escape to omp, twice to leave terminal mode',
  })
  -- The insert-mode escape this config uses everywhere, for leaving in one go.
  vim.keymap.set('t', 'jk', [[<C-\><C-n>]], { buffer = bufnr, silent = true, desc = 'escape terminal mode' })
end

-- Required lazily: lua/core/lazy.lua requires every file under lua/plugins/ to
-- collect its specs, long before toggleterm is on the runtimepath.
local function new(cmd)
  return require('toggleterm.terminal').Terminal:new {
    cmd = cmd,
    id = ID,
    hidden = true, -- keep it out of the numbered list toggleterm cycles through
    direction = 'vertical',
    display_name = 'omp',
    close_on_exit = false, -- leave the panel up when omp exits, so its last output is readable
    auto_scroll = true, -- the panel is usually unfocused, where Neovim won't follow output itself
    -- Once per buffer, and again if the job is respawned into a new one.
    on_create = function(self)
      set_terminal_keys(self.bufnr)
    end,
  }
end

-- The terminal if its buffer is still around, otherwise nil. toggleterm
-- re-spawns the job on the next open once the buffer is gone, which is fine --
-- but the prompt below has to know whether there is a live session to write to.
-- Handing back the terminal rather than a boolean is what lets each caller work
-- through a handle it knows is non-nil.
local function alive()
  if term ~= nil and term.bufnr ~= nil and vim.api.nvim_buf_is_valid(term.bufnr) then
    return term
  end
end

-- Open the panel without taking focus: you are normally still typing in the file
-- the bridge is telling OMP about.
local function show(t)
  if t:is_open() then
    return
  end
  local origin = vim.api.nvim_get_current_win()
  t:open(size())
  vim.cmd 'stopinsert'
  vim.schedule(function()
    if vim.api.nvim_win_is_valid(origin) and vim.api.nvim_get_current_win() ~= origin then
      vim.api.nvim_set_current_win(origin)
    end
  end)
end

local function kill()
  if term then
    term:shutdown()
  end
  term = nil
end

-- Start OMP with `args`, replacing any session already running -- the command is
-- fixed when the job spawns, so flags cannot be applied to a live one.
local function start(args, focus)
  kill()
  term = new('omp' .. (args and ' ' .. args or ''))
  if focus then
    term:open(size()) -- for --resume, whose session picker is inside the TUI
  else
    show(term)
  end
  -- The flags have reached the argv now. Drop them, so a respawn -- the panel
  -- reopened after omp exited, or after the buffer was wiped -- starts a plain
  -- session rather than replaying --continue or the opening prompt.
  term.cmd = 'omp'
end

local function toggle()
  local t = alive()
  if not t then
    return start()
  end
  if t:is_open() then
    t:close()
  else
    show(t)
  end
end

-- Write raw bytes straight to the running OMP terminal's pty without moving
-- focus, so its dialogs can be answered from whatever buffer you are in.
-- Returns false (and notifies) when there is no live session -- chansend throws
-- on a channel whose job has exited, and with close_on_exit off the buffer
-- outlives the process.
local function send_raw(keys)
  local t = alive()
  if not t then
    vim.notify('No OMP terminal running', vim.log.levels.WARN)
    return false
  end
  local ok, written = pcall(vim.fn.chansend, t.job_id, keys)
  if not ok or written == 0 then
    vim.notify('OMP terminal channel is closed', vim.log.levels.WARN)
    return false
  end
  return true
end

-- One key, one byte sequence: the keymaps below are all "press this in OMP".
local function sender(keys)
  return function()
    send_raw(keys)
  end
end

local function prompt()
  local text = vim.fn.input 'omp: '
  if vim.trim(text) == '' then
    return
  end
  -- A running TUI reads the line off its pty; CR submits it, "\n" does not.
  local t = alive()
  if t and send_raw(text .. '\r') then
    show(t)
  else
    -- Nothing to write to: hand the text to omp as its opening message instead
    -- of racing the TUI's startup with a write it is not yet reading.
    start(vim.fn.shellescape(text))
  end
end

return {
  {
    'rauls-kjarners/omp.nvim',
    -- Not lazy on the keys below: the bridge has to be tracking the cursor
    -- before you start an OMP session, not from the first time you press one.
    event = 'VeryLazy',
    dependencies = { 'akinsho/nvim-toggleterm.lua' },
    -- The other half of the plugin is an OMP extension, published to npm and
    -- installed into ~/.omp rather than here -- this keeps the two halves in
    -- step on install and update. Drop it if you'd rather install by hand.
    build = 'omp plugin install omp.nvim',
    -- Letter for letter with claudecode.nvim's <leader>a set, so both agents
    -- drive the same. Claude's prompt and answer keys are global (<leader><leader>,
    -- <leader>j, <leader>k) and it owns those, so their counterparts sit in this
    -- group. Claude's diff keys have no OMP equivalent -- there is no diff
    -- protocol here -- and its attach keys are unnecessary; see the note above.
    keys = {
      { '<leader>cc', toggle, mode = { 'n', 'v' }, desc = 'toggle' },
      { '<leader>cp', prompt, mode = { 'n', 'v' }, desc = 'prompt' },

      -- Answer OMP's dialogs from wherever you are: <CR> takes the highlighted
      -- option, <Esc> cancels the dialog -- it no longer interrupts the turn,
      -- app.interrupt having been rebound to ` in the omp config.
      { '<leader>cj', sender '\r', mode = { 'n', 'v' }, desc = 'accept_prompt' },
      { '<leader>ck', sender '\27', mode = { 'n', 'v' }, desc = 'reject_prompt' },
      { '<leader>cl', sender '`', mode = { 'n', 'v' }, desc = 'interrupt' },
      -- Next option in a dialog; the answer keys above then act on whatever is
      -- highlighted by the time you press them.
      { '<leader>c;', sender '\t', mode = { 'n', 'v' }, desc = 'next_question' },
      -- Shift+Tab is the terminal back-tab sequence: ESC [ Z, which OMP's input
      -- layer matches literally. It cycles reasoning effort, where the same key
      -- cycles permission mode in Claude.
      { '<leader>cm', sender '\27[Z', mode = { 'n', 'v' }, desc = 'cycle_effort' },
      -- app.model.select is alt+m, which terminals send as ESC then the letter.
      { '<leader>cM', sender '\27m', mode = { 'n', 'v' }, desc = 'model' },

      { '<leader>cx', kill, mode = { 'n', 'v' }, desc = 'kill' },

      {
        '<leader>cs',
        function()
          start '--continue'
        end,
        desc = 'session_continue',
      },
      {
        '<leader>cf',
        function()
          start('--resume', true)
        end,
        desc = 'find_session',
      },
      { '<leader>ch', '<cmd>checkhealth omp<cr>', desc = 'health' },
    },
    config = function()
      require('omp').setup()
    end,
  },
}
