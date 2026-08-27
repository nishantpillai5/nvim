-- Group labels for the prefixes this config actually binds. Add entries here as
-- new topic files land; a group for a prefix with no keys shows an empty menu.
return {
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = function()
      return {
        icons = { rules = false, group = '' },
        sort = { 'order', 'alphanum', 'mod', 'lower', 'icase' },
        -- Windows terminals mis-handle which-key's automatic triggers.
        triggers = require('util.env').OS == 'windows' and {
          { '<auto>', mode = 'nixsotc' },
          { '<leader>', mode = { 'n', 'v' } },
        } or nil,
        spec = {
          { '<leader>', group = 'Leader' },
          { '<leader>a', group = 'Agent', mode = { 'n', 'v' } },
          { '<leader>b', group = 'Breakpoint' },
          { '<leader>c', group = 'OMP', mode = { 'n', 'v' } },
          { '<leader>e', group = 'Explorer' },
          { '<leader>f', group = 'Find' },
          { '<leader>fb', group = 'Breakpoint' },
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
          -- Tests, plus the two buffer-local source_config mappings that only
          -- exist under the config directory (core/keymaps.lua).
          { '<leader>i', group = 'Test' },
          { '<leader>l', group = 'LSP', mode = { 'n', 'v' } },
          { '<leader>n', group = 'Notes', mode = { 'n', 'v' } },
          { '<leader>o', group = 'Tasks' },
          { '<leader>oR', group = 'Run_Cmd' },
          { '<leader>ow', group = 'Save' },
          { '<leader>r', group = 'Refactor', mode = { 'n', 'v' } },
          { '<leader>V', group = 'Surround' },
          { '<leader>w', group = 'Workspace' },
          { '<leader>ww', group = 'Worktree' },
          { '<leader>z', group = 'Visual', mode = { 'n', 'v' } },
          { '<leader>zO', group = 'Run' },
          { '<leader>zp', group = 'Pomodoro' },
          -- nvim-biscuits registers <leader>zC itself, from `toggle_keybind`.
          { '<leader>zC', desc = 'context_virtual' },
          -- mini.surround installs its own mappings once loaded, overwriting
          -- the descs on lazy's key stubs with its own sentence-case ones.
          { '<leader>v', desc = 'surround', mode = { 'n', 'x' } },
          { '<leader>Vd', desc = 'delete' },
          { '<leader>Vf', desc = 'find' },
          { '<leader>VF', desc = 'find_left' },
          { '<leader>Vh', desc = 'highlight' },
          { '<leader>Vr', desc = 'replace' },
          { '<leader>Vn', desc = 'update_n_lines' },
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
    config = function(_, opts)
      require('which-key').setup(opts)

      -- Colour buffer-local descriptions instead. which-key has no hook for it:
      -- the highlight comes from `item.group` alone, and by render time a cell is
      -- a bare padded string. So remember each local item's key/description pair
      -- and recolour it on the way out -- rows go key, separator, icon, desc.
      local locals = {}

      local view = require 'which-key.view'
      local item = view.item
      view.item = function(node, o)
        local ret = item(node, o)
        if node.keymap and (node.keymap.buffer or 0) ~= 0 then
          locals[ret.key .. '\0' .. ret.desc] = true
        end
        return ret
      end

      local text = require 'which-key.text'
      local append = text.append
      local key -- the key cell of the row being appended
      text.append = function(self, str, o)
        local hl = type(o) == 'string' and o or type(o) == 'table' and o.hl
        if type(str) == 'string' then
          if hl == 'WhichKey' then
            key = vim.trim(str)
          elseif hl == 'WhichKeyDesc' and locals[(key or '') .. '\0' .. vim.trim(str)] then
            return append(self, str, 'WhichKeyLocal')
          end
        end
        return append(self, str, o)
      end

      -- Re-set on colorscheme, which clears it.
      local function set_hl()
        vim.api.nvim_set_hl(0, 'WhichKeyLocal', { fg = require('vscode.colors').get_colors().vscBlueGreen })
      end

      set_hl()
      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('whichkey_local_hl', { clear = true }),
        desc = 'keep buffer-local which-key descriptions coloured',
        callback = set_hl,
      })
    end,
  },
}
