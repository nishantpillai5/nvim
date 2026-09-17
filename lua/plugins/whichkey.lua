-- Only the prefixes this config binds: a group with no keys shows an empty menu.
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
          { '<leader>;', group = 'Strudel' },
          { '<leader>a', group = 'Agent', mode = { 'n', 'v' } },
          { '<leader>b', group = 'Breakpoint' },
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
          { '<leader>i', group = 'Test' },
          { '<leader>l', group = 'LSP', mode = { 'n', 'v' } },
          { '<leader>n', group = 'Notes', mode = { 'n', 'v' } },
          { '<leader>o', group = 'Tasks' },
          { '<leader>oR', group = 'Run_Cmd' },
          { '<leader>ow', group = 'Save' },
          { '<leader>r', group = 'Refactor', mode = { 'n', 'v' } },
          { '<leader>t', group = 'Trouble' },
          { '<leader>V', group = 'Surround', mode = { 'n', 'x', 'o' } },
          { '<leader>w', group = 'Workspace' },
          { '<leader>ww', group = 'Worktree' },
          { '<leader>z', group = 'Visual', mode = { 'n', 'v' } },
          { '<leader>zO', group = 'Run' },
          { '<leader>zt', group = 'Pomodoro' },
          -- nvim-biscuits registers <leader>zC itself, from `toggle_keybind`.
          { '<leader>zC', desc = 'context_virtual' },
          -- mini.surround overwrites the descs on lazy's key stubs once loaded.
          -- `l` / `n` are its suffix_last / suffix_next.
          { '<leader>v', desc = 'surround', mode = { 'n', 'x' } },
          { '<leader>Vd', desc = 'delete' },
          { '<leader>Vdl', desc = 'delete_prev' },
          { '<leader>Vdn', desc = 'delete_next' },
          { '<leader>Vf', desc = 'find', mode = { 'n', 'x', 'o' } },
          { '<leader>Vfl', desc = 'find_prev', mode = { 'n', 'x', 'o' } },
          { '<leader>Vfn', desc = 'find_next', mode = { 'n', 'x', 'o' } },
          { '<leader>VF', desc = 'find_left', mode = { 'n', 'x', 'o' } },
          { '<leader>VFl', desc = 'find_left_prev', mode = { 'n', 'x', 'o' } },
          { '<leader>VFn', desc = 'find_left_next', mode = { 'n', 'x', 'o' } },
          { '<leader>Vh', desc = 'highlight' },
          { '<leader>Vhl', desc = 'highlight_prev' },
          { '<leader>Vhn', desc = 'highlight_next' },
          { '<leader>Vr', desc = 'replace' },
          { '<leader>Vrl', desc = 'replace_prev' },
          { '<leader>Vrn', desc = 'replace_next' },
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
          -- Bound with no desc, so which-key shows the raw rhs without these.
          { '<M-i>', desc = 'select_reference', mode = { 'x', 'o' } },
          -- llama.vim's inst_accept / inst_cancel: they take normal-mode <Tab>
          -- and <Esc> regardless, falling through when nothing is pending.
          { '<Tab>', desc = 'accept_instruction' },
          { '<Esc>', desc = 'cancel_instruction' },
          { 'y<C-G>', desc = 'yank_git_object' },
          -- matchit, which neovim ships and loads by default.
          { '%', desc = 'matching_pair', mode = { 'n', 'x', 'o' } },
          { 'a%', desc = 'matching_pair_object', mode = { 'x' } },
          { 'g%', desc = 'prev_matching_pair', mode = { 'n', 'x', 'o' } },
          { '[%', desc = 'unmatched_group_start', mode = { 'n', 'x', 'o' } },
          { ']%', desc = 'unmatched_group_end', mode = { 'n', 'x', 'o' } },
        },
      }
    end,
    config = function(_, opts)
      require('which-key').setup(opts)

      -- which-key has no hook for this: the highlight comes from `item.group`
      -- alone, and by render time a cell is a bare padded string. So remember
      -- each local item's key/desc pair -- keyed by buffer -- and recolour it.
      local locals = {}

      -- which-key internals with no stability promise, so an upstream rename
      -- costs the colour rather than every popup.
      local ok_view, view = pcall(require, 'which-key.view')
      local ok_text, text = pcall(require, 'which-key.text')

      if ok_view and ok_text and type(view.item) == 'function' and type(text.append) == 'function' then
        local item = view.item
        ---@diagnostic disable-next-line: duplicate-set-field
        view.item = function(node, o)
          local ret = item(node, o)
          local buf = node.keymap and node.keymap.buffer or 0
          if buf ~= 0 and ret and type(ret.key) == 'string' and type(ret.desc) == 'string' then
            locals[ret.key .. '\0' .. ret.desc] = buf
          end
          return ret
        end

        local append = text.append
        local key -- the key cell of the row being appended
        text.append = function(self, str, o)
          local hl = type(o) == 'string' and o or type(o) == 'table' and o.hl
          if type(str) == 'string' then
            if hl == 'WhichKey' then
              key = vim.trim(str)
            elseif hl == 'WhichKeyDesc' then
              local owner = locals[(key or '') .. '\0' .. vim.trim(str)]
              if owner and owner == vim.api.nvim_get_current_buf() then
                return append(self, str, 'WhichKeyLocal')
              end
            end
          end
          return append(self, str, o)
        end

        -- Bound the table: without this it only ever grows.
        vim.api.nvim_create_autocmd('BufDelete', {
          group = vim.api.nvim_create_augroup('whichkey_local_gc', { clear = true }),
          desc = 'forget buffer-local which-key descriptions with their buffer',
          callback = function(args)
            for k, buf in pairs(locals) do
              if buf == args.buf then
                locals[k] = nil
              end
            end
          end,
        })
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
