-- Group labels for the prefixes this config actually binds. Add entries here as
-- new topic files land; a group for a prefix with no keys shows an empty menu.
return {
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = function()
      return {
        icons = { rules = false, group = '' },
        sort = { 'local', 'order', 'alphanum', 'mod', 'lower', 'icase' },
        -- Windows terminals mis-handle which-key's automatic triggers.
        triggers = require('util.env').OS == 'windows' and {
          { '<auto>', mode = 'nixsotc' },
          { '<leader>', mode = { 'n', 'v' } },
        } or nil,
        spec = {
          { '<leader>', group = 'Leader' },
          { '<leader>a', group = 'Agent', mode = { 'n', 'v' } },
          { '<leader>c', group = 'Chat', mode = { 'n', 'v' } },
          { '<leader>e', group = 'Explorer' },
          { '<leader>f', group = 'Find' },
          { '<leader>fg', group = 'Git' },
          { '<leader>F', group = 'Find_Telescope' },
          { '<leader>g', group = 'Git', mode = { 'n', 'v' } },
          { '<leader>gc', group = 'Debugprint', mode = { 'n', 'v' } },
          { '<leader>gf', group = 'File_diff' },
          { '<leader>gh', group = 'Hunk', mode = { 'n', 'v' } },
          { '<leader>go', group = 'Open', mode = { 'n', 'v' } },
          { '<leader>gx', group = 'Conflict' },
          { '<leader>gR', group = 'Reset' },
          { '<leader>gz', group = 'Stash' },
          { '<leader>h', group = 'Grapple' },
          { '<leader>ey', group = 'Yank' },
          { '<leader>i', group = 'Config' },
          { '<leader>l', group = 'LSP', mode = { 'n', 'v' } },
          { '<leader>o', group = 'Tasks' },
          { '<leader>oR', group = 'Run_Cmd' },
          { '<leader>ow', group = 'Save' },
          { '<leader>r', group = 'Refactor', mode = { 'n', 'v' } },
          { '<leader>w', group = 'Workspace' },
          { '<leader>ww', group = 'Worktree' },
          { '<leader>z', group = 'Visual', mode = { 'n', 'v' } },
          { '<leader>zO', group = 'Run' },
          { '<leader>zp', group = 'Pomodoro' },
          -- trailblazer sets these itself, with no desc to read.
          { 'm', group = 'Marks' },
          { 'mD', desc = 'delete_all' },
          { 'mn', desc = 'nearest' },
          { 'mp', desc = 'paste_last' },
          { 'mP', desc = 'paste_all' },
          { 'mx', desc = 'back' },
          { '<leader>m', desc = 'toggle_trail_mark_list' },
          { 'g', group = 'G_Operator' },
          { 'gr', group = 'LSP' },
          { 'z', group = 'Fold' },
          { ']', group = 'Next' },
          { '[', group = 'Prev' },
        },
      }
    end,
  },
}
