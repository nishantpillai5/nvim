-- Oh My Pi (`omp`) as one of the AI backends behind <leader>a; see util/ai.
--
-- The plugin itself is only a context bridge, pushing "<file>:<line>" over a
-- unix socket to every OMP session in the same cwd. Hence no attach key here --
-- there is nothing to attach by hand. The panel below is ours: OMP is a plain
-- TUI, so nothing but the bridge comes from the plugin.

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

-- core/keymaps.lua binds <Esc> in terminal mode, which would swallow it before
-- OMP's dialogs see it. In this buffer only, the first <Esc> goes through and a
-- second within ESC_TIMEOUT leaves terminal mode.
local function double_esc()
  -- Only nil when out of file descriptors, where there is no useful fallback.
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

-- Required lazily: core/lazy.lua requires every file under lua/plugins/ to
-- collect specs, long before toggleterm is on the runtimepath.
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

-- The terminal if its buffer is still around, else nil. Returns the handle
-- rather than a boolean so callers can write to a session they know is live.
local function alive()
  if term ~= nil and term.bufnr ~= nil and vim.api.nvim_buf_is_valid(term.bufnr) then
    return term
  end
end

-- Without focus: you are normally still typing in the file the bridge reports.
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

-- Replaces any running session: the command is fixed when the job spawns, so
-- flags cannot be applied to a live one.
local function start(args, focus)
  kill()
  term = new('omp' .. (args and ' ' .. args or ''))
  if focus then
    term:open(size()) -- for --resume, whose session picker is inside the TUI
  else
    show(term)
  end
  -- Dropped once in argv, so a respawn starts plain rather than replaying
  -- --continue or the opening prompt.
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

-- Raw bytes to the pty without moving focus. Guarded because chansend throws on
-- a channel whose job has exited, and close_on_exit is off so the buffer outlives
-- the process.
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

-- OMP's half of the shared <leader>a contract, registered at file-body level --
-- which core/lazy.lua runs while collecting specs, so this lands before load.
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
  -- No bracketed paste, so a raw newline would submit each line as its own turn.
  submit = function(text)
    return send_raw((text:gsub('%s*\r?\n%s*', ' ')) .. '\r')
  end,
  -- No nvim-side picker, so both keys open OMP's own. Focused, unlike the rest:
  -- the picker is inside the TUI.
  find_session = function()
    start('--resume', true)
  end,
  find_session_cli = function()
    start('--resume', true)
  end,
  health = function()
    vim.cmd 'checkhealth omp'
  end,
  -- Deliberately absent: scrape_*, slash_commands, mention, attach_*, worktree_*
  -- and diff_*. Inheriting them would read Claude's terminal or offer Claude's
  -- commands; util.ai.call reports each rather than doing nothing.
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
    -- Eager: the bridge must track the cursor before a session starts.
    event = 'VeryLazy',
    dependencies = { 'akinsho/nvim-toggleterm.lua' },
    -- The plugin's other half is an OMP extension in ~/.omp, kept in step here.
    build = 'omp plugin install omp.nvim',
    -- No `keys`: every mapping is declared in core/keymaps.lua and dispatched
    -- through util.ai, so `event = 'VeryLazy'` above is what loads this.
    config = function()
      require('omp').setup()
    end,
  },
}
