-- The shared toggleterm panel for single-terminal TUI backends (OMP, pi).
-- Each backend file calls M.panel{...} once at file-body level and registers
-- the returned ops (plus its own senders) with util.ai. The panel owns the
-- whole terminal lifecycle: one hidden vertical split per backend, spawned on
-- demand, reachable without moving focus.

local M = {}

local ESC_TIMEOUT = 200 -- ms in which a second <Esc> means "leave terminal mode", not "another escape"

---@param opts { id: number, name: string, exe: string, width: number }
function M.panel(opts)
  -- The one terminal for this backend, or nil when none has been started this
  -- session.
  local term = nil

  local function size()
    return math.floor(vim.o.columns * opts.width)
  end

  -- Reused across presses, and there is only ever one panel per backend.
  local esc_timer = nil

  -- core/keymaps.lua binds <Esc> in terminal mode, which would swallow it
  -- before the TUI's dialogs see it. In this buffer only, the first <Esc> goes
  -- through and a second within ESC_TIMEOUT leaves terminal mode.
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
      desc = ('escape to %s, twice to leave terminal mode'):format(opts.name),
    })
    -- The insert-mode escape this config uses everywhere, for leaving in one go.
    vim.keymap.set('t', 'jk', [[<C-\><C-n>]], { buffer = bufnr, silent = true, desc = 'escape terminal mode' })
  end

  -- Required lazily: core/lazy.lua requires every file under lua/plugins/ to
  -- collect specs, long before toggleterm is on the runtimepath. The numbered
  -- terminals' keys and the bridge plugins are its usual loaders, and a config
  -- where neither is enabled reaches here first -- so load it explicitly.
  local function new(cmd)
    -- lazy matches specs by short name, as util.ai's ensure_loaded does.
    pcall(function()
      require('lazy').load { plugins = { 'nvim-toggleterm.lua' } }
    end)
    return require('toggleterm.terminal').Terminal:new {
      cmd = cmd,
      id = opts.id, -- toggleterm slot, well clear of the numbered terminals <leader>o
      hidden = true, -- keep it out of the numbered list toggleterm cycles through
      direction = 'vertical',
      display_name = opts.name,
      close_on_exit = false, -- leave the panel up when the TUI exits, so its last output is readable
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

  -- toggleterm resolves the split origin from the current window, and probes
  -- win_gettype(0) to float-test a not-yet-opened terminal -- so opening from a
  -- float (the prompt box) throws "Invalid terminal direction". A normal window
  -- first; the last one stands when there is nothing else, which there always is.
  local function normal_win()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == '' then
        return win
      end
    end
    return vim.api.nvim_get_current_win()
  end

  -- Without focus: you are normally still typing in the file being edited.
  local function show(t)
    if t:is_open() then
      return
    end
    local origin = normal_win()
    vim.api.nvim_set_current_win(origin)
    t:open(size())
    vim.cmd 'stopinsert'
    vim.schedule(function()
      -- Only when nothing else moved focus since: the prompt box sets its float
      -- current right after show() returns, and this restore would steal it back.
      if
        vim.api.nvim_win_is_valid(origin)
        and t.window
        and vim.api.nvim_win_is_valid(t.window)
        and vim.api.nvim_get_current_win() == t.window
      then
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
    term = new(opts.exe .. (args and ' ' .. args or ''))
    if focus then
      -- --resume, whose session picker is inside the TUI; leave focus on the panel.
      vim.api.nvim_set_current_win(normal_win())
      term:open(size())
    else
      show(term)
    end
    -- Dropped once in argv, so a respawn starts plain rather than replaying
    -- --continue or the opening prompt.
    term.cmd = opts.exe
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
      vim.notify(('No %s terminal running'):format(opts.name), vim.log.levels.WARN)
      return false
    end
    local ok, written = pcall(vim.fn.chansend, t.job_id, keys)
    if not ok or written == 0 then
      vim.notify(('%s terminal channel is closed'):format(opts.name), vim.log.levels.WARN)
      return false
    end
    return true
  end

  -- One key, one byte sequence: the backend's keymaps are all "press this in the TUI".
  local function sender(keys)
    return function()
      send_raw(keys)
    end
  end

  return {
    term_buf = function()
      local t = alive()
      return t and t.bufnr
    end,
    send_raw = send_raw,
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
    -- No nvim-side picker, so both session keys open the TUI's own. Focused,
    -- unlike the rest: the picker is inside the TUI.
    find_session = function()
      start('--resume', true)
    end,
    find_session_cli = function()
      start('--resume', true)
    end,
    toggle = toggle,
    start = start,
    continue = function()
      start '--continue'
    end,
    kill = kill,
    sender = sender,
    alive = alive,
  }
end

return M
