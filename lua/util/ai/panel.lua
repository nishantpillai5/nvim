-- The shared toggleterm panel for single-terminal TUI backends (OMP, pi): one
-- hidden vertical split each, spawned on demand, reachable without focus.

local M = {}

local ESC_TIMEOUT = 200 -- ms in which a second <Esc> means "leave terminal mode", not "another escape"

---@param opts { id: number, name: string, exe: string, width: number }
function M.panel(opts)
  local term = nil

  local function size()
    return math.floor(vim.o.columns * opts.width)
  end

  local esc_timer = nil

  -- core/keymaps.lua binds <Esc> in terminal mode, which would swallow it
  -- before the TUI's dialogs see it.
  local function double_esc()
    -- Only nil when out of file descriptors.
    esc_timer = esc_timer or assert(vim.uv.new_timer())
    if esc_timer:is_active() then
      esc_timer:stop()
      return [[<C-\><C-n>]]
    end
    -- Empty callback: the handle's own active/idle state is the whole signal.
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
    vim.keymap.set('t', 'jk', [[<C-\><C-n>]], { buffer = bufnr, silent = true, desc = 'escape terminal mode' })
  end

  -- Loaded explicitly: core/lazy.lua requires this file while collecting specs,
  -- long before toggleterm's usual loaders have had a chance to run.
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
      on_create = function(self)
        set_terminal_keys(self.bufnr)
      end,
    }
  end

  -- The handle rather than a boolean, so callers can write to a live session.
  local function alive()
    if term ~= nil and term.bufnr ~= nil and vim.api.nvim_buf_is_valid(term.bufnr) then
      return term
    end
  end

  -- toggleterm float-tests a not-yet-opened terminal with win_gettype(0), so
  -- opening from a float throws "Invalid terminal direction".
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
      -- Only if nothing else moved focus since: the prompt box goes current
      -- right after show() returns, and this would steal it back.
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

  -- Replaces any running session: the command is fixed when the job spawns.
  local function start(args, focus)
    kill()
    term = new(opts.exe .. (args and ' ' .. args or ''))
    if focus then
      -- --resume: its session picker is inside the TUI.
      vim.api.nvim_set_current_win(normal_win())
      term:open(size())
    else
      show(term)
    end
    -- Dropped once used, so a respawn does not replay --continue.
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

  -- Guarded: chansend throws on a dead channel, and close_on_exit is off so the
  -- buffer outlives the process.
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
    -- No bracketed paste, so a raw newline submits each line as its own turn.
    submit = function(text)
      return send_raw((text:gsub('%s*\r?\n%s*', ' ')) .. '\r')
    end,
    -- No nvim-side picker, so both session keys open the TUI's own.
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
