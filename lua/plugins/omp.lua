-- Oh My Pi (`omp`) as one of the AI backends behind <leader>a -- <leader>ab
-- cycles which, and the tabline says which is live. Both backends can be enabled
-- at once; they run separate agents in separate terminals and share nothing but
-- the keymaps. See util/ai/init.lua.
--
-- The plugin itself is only a context bridge: it follows the cursor and pushes
-- "<file>:<line>" -- or "<file>:<start>-<end>" while a visual selection is
-- active -- over a unix socket to every OMP session started in the same cwd, so
-- the agent always knows what you are looking at. There is no attach-file or
-- attach-selection key here because there is nothing to attach by hand: just
-- ask about "this function" and OMP already has the path and the lines.
--
-- Everything else below is ours. OMP is a plain TUI, so the panel it runs in is
-- this file's job, not the plugin's; composing a prompt to send into it belongs
-- to the shared box in util/ai/prompt.lua.

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

-- OMP's half of the shared <leader>a contract. Every key is declared once in
-- core/keymaps.lua and resolves the active backend at press time -- there is no
-- <leader>c group any more, so nothing here can fire at OMP while the tabline
-- says Claude.
--
-- Registered at file-body level, which core/lazy.lua runs for every module under
-- lua/plugins/ while collecting specs. See the AI section of README.md.
require('util.ai').register('omp', {
  send_raw = send_raw,
  term_buf = function()
    local t = alive()
    return t and t.bufnr
  end,
  show = function()
    local t = alive()
    if t then
      show(t)
    else
      start()
    end
  end,
  -- No bracketed paste here, so a raw newline would submit each line as its own
  -- turn: flatten a multi-line prompt to one line instead. This is the one thing
  -- the shared box gives up on OMP -- everything else in it works the same as
  -- for Claude.
  submit = function(text)
    return send_raw((text:gsub('%s*\r?\n%s*', ' ')) .. '\r')
  end,
  -- OMP has no nvim-side session picker, so both session keys point at its own
  -- in-TUI one. Focused, unlike everything else here: the picker is inside the
  -- TUI, so you have to be in it to use it.
  find_session = function()
    start('--resume', true)
  end,
  find_session_cli = function()
    start('--resume', true)
  end,
  health = function()
    vim.cmd 'checkhealth omp'
  end,
  -- Deliberately absent: scrape_suggestion, scrape_question, slash_commands,
  -- mention, attach_*, worktree_* and diff_*. The first two would otherwise read
  -- Claude's terminal; the command list would offer Claude's commands; there is
  -- nothing to attach or mention by hand because the omp.nvim bridge is already
  -- pushing the cursor's file and line; and there is no diff protocol here.
  -- util.ai.call reports each of these rather than doing nothing.
  toggle = toggle,
  continue = function()
    start '--continue'
  end,
  kill = kill,
  accept = sender '\r',
  reject = sender '\27',
  interrupt = sender '`',
  next_tab = sender '\t',
  -- Shift+Tab: cycles reasoning effort here, permission mode in Claude.
  cycle_mode = sender '\27[Z',
  -- app.model.select is alt+m, which terminals send as ESC then the letter.
  model = sender '\27m',
})

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
    -- No `keys`: every mapping is declared in core/keymaps.lua and dispatched
    -- through util.ai. The <leader>c group this file used to own is retired --
    -- it drove OMP regardless of which backend was active, which is exactly the
    -- confusion the indicator exists to remove. `event = 'VeryLazy'` above is
    -- what loads this now, and it has to stay eager anyway: the cursor bridge
    -- must be tracking before a session starts, not from the first keypress.
    config = function()
      require('omp').setup()
    end,
  },
}
