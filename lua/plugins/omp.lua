-- Oh My Pi (`omp`) as one of the AI backends behind <leader>a; see util/ai.
--
-- The plugin itself is only a context bridge, pushing "<file>:<line>" over a
-- unix socket to every OMP session in the same cwd. Hence no attach key here --
-- there is nothing to attach by hand. The panel is shared with the other TUI
-- backends; see util/ai/panel.

local panel = require('util.ai.panel').panel {
  id = 99, -- toggleterm slot, well clear of the numbered terminals <leader>o
  name = 'omp',
  exe = 'omp',
  width = 0.45, -- share of the columns the panel takes, matching the Claude panel
}

-- OMP's half of the shared <leader>a contract, registered at file-body level --
-- which core/lazy.lua runs while collecting specs, so this lands before load.
require('util.ai').register('omp', {
  send_raw = panel.send_raw,
  term_buf = panel.term_buf,
  show = panel.show,
  submit = panel.submit,
  find_session = panel.find_session,
  find_session_cli = panel.find_session_cli,
  health = function()
    vim.cmd 'checkhealth omp'
  end,
  -- Deliberately absent: scrape_*, slash_commands, mention, attach_*, worktree_*
  -- and diff_*. Inheriting them would read Claude's terminal or offer Claude's
  -- commands; util.ai.call reports each rather than doing nothing.
  toggle = panel.toggle,
  continue = panel.continue,
  kill = panel.kill,
  accept = panel.sender '\r',
  reject = panel.sender '\27',
  interrupt = panel.sender '`',
  next_tab = panel.sender '\t',
  -- Shift+Tab: cycles reasoning effort here, permission mode in Claude.
  cycle_mode = panel.sender '\27[Z',
  -- app.model.select is alt+m, which terminals send as ESC then the letter.
  model = panel.sender '\27m',
})

return {
  {
    'rauls-kjarners/omp.nvim',
    -- Eager: the bridge must track the cursor before a session starts.
    event = 'VeryLazy',
    -- No toggleterm dependency: util/ai/panel loads it on first use.
    -- The plugin's other half is an OMP extension in ~/.omp, kept in step here.
    build = 'omp plugin install omp.nvim',
    -- No `keys`: every mapping is declared in core/keymaps.lua and dispatched
    -- through util.ai, so `event = 'VeryLazy'` above is what loads this.
    config = function()
      require('omp').setup()
    end,
  },
}
