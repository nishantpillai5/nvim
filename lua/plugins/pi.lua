-- pi, one of the AI backends behind <leader>a; see util/ai. No bridge plugin, so
-- the panel is the whole backend and the empty spec list below is deliberate.

local panel = require('util.ai.panel').panel {
  id = 98, -- toggleterm slot, well clear of the numbered terminals <leader>o and of OMP's 99
  name = 'pi',
  exe = 'pi',
  width = 0.45, -- share of the columns the panel takes, matching the other panels
}

-- Registered at file-body level, which core/lazy.lua runs while collecting
-- specs -- so the ops exist before anything loads.
require('util.ai').register('pi', {
  send_raw = panel.send_raw,
  term_buf = panel.term_buf,
  show = panel.show,
  submit = panel.submit,
  find_session = panel.find_session,
  find_session_cli = panel.find_session_cli,
  -- scrape_*, slash_commands, mention, attach_*, worktree_*, diff_*, health and
  -- next_tab are deliberately absent; util.ai.call reports each.
  toggle = panel.toggle,
  continue = panel.continue,
  kill = panel.kill,
  accept = panel.sender '\r', -- tui.select.confirm
  reject = panel.sender '\27', -- tui.select.cancel
  interrupt = panel.sender '\27', -- app.interrupt
  -- Shift+Tab: app.thinking.cycle, the thinking-level analogue of OMP's.
  cycle_mode = panel.sender '\27[Z',
  -- app.model.select is ctrl+l, not an alt-key like OMP's.
  model = panel.sender '\12',
})

return {}
