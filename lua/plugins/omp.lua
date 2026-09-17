-- Oh My Pi (`omp`), one of the AI backends behind <leader>a; see util/ai. The
-- plugin is only a context bridge, so there is no attach key here.

local panel = require('util.ai.panel').panel {
  id = 99, -- toggleterm slot, well clear of the numbered terminals <leader>o
  name = 'omp',
  exe = 'omp',
  width = 0.45, -- share of the columns the panel takes, matching the Claude panel
}

-- Registered at file-body level, which core/lazy.lua runs while collecting
-- specs -- so the ops exist before the plugin loads.
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
  -- scrape_*, slash_commands, mention, attach_*, worktree_* and diff_* are
  -- deliberately absent: they would read Claude's terminal.
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
    -- No toggleterm dependency: util/ai/panel loads it on first use. The
    -- plugin's other half is an OMP extension in ~/.omp.
    build = 'omp plugin install omp.nvim',
    -- No `keys`: core/keymaps.lua declares them all, so VeryLazy loads this.
    config = function()
      require('omp').setup()
    end,
  },
}
