-- The notes vault, at `util.env`'s DIR_NOTES. Loads for markdown files inside
-- it, or on the first `<leader>n` mapping.
local env = require 'util.env'
local notes = vim.fs.normalize(env.DIR_NOTES)

return {
  {
    'obsidian-nvim/obsidian.nvim',
    version = '*',
    event = {
      'BufReadPre ' .. notes .. '/**.md',
      'BufNewFile ' .. notes .. '/**.md',
    },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    keys = {
      { '<leader>nf', ':Obsidian quick_switch<cr>', desc = 'find' },
      { '<leader>fN', ':Obsidian quick_switch<cr>', desc = 'notes' },
      { '<leader>n?', ':Obsidian search<cr>', desc = 'search' },
      { '<leader>nj', ':Obsidian today<cr>', desc = 'journal_today' },
      { '<leader>nJ', ':Obsidian dailies<cr>', desc = 'journal_list' },
      { '<leader>nl', ':Obsidian links<cr>', desc = 'links' },
      { '<leader>nL', ':Obsidian backlinks<cr>', desc = 'backlinks' },
      { '<leader>nr', ':Obsidian rename<cr>', desc = 'rename' },
      { '<leader>np', ':Obsidian paste_img<cr>', desc = 'paste_img' },
      { '<leader>nc', ':Obsidian new<cr>', desc = 'create' },
      { '<leader>nC', ':Obsidian new_from_template<cr>', desc = 'create_from_template' },
      { '<leader>nt', ':Obsidian tags<cr>', desc = 'tags' },
      { '<leader>ni', ':Obsidian template<cr>', desc = 'insert_template' },

      { '<leader>nl', ':Obsidian link<cr>', mode = 'v', desc = 'link_existing' },
      { '<leader>nL', ':Obsidian link_new<cr>', mode = 'v', desc = 'link_create' },
      { '<leader>nc', ':Obsidian extract_note<cr>', mode = 'v', desc = 'create' },
    },
    opts = {
      legacy_commands = false,
      ui = { enable = true },
      checkbox = { order = { ' ', 'x', '>' } },
      workspaces = { { name = 'notes', path = env.DIR_NOTES } },
      templates = {
        folder = 'templates',
        date_format = '%Y.%m.%d.%a',
        time_format = '%H:%M',
      },
      daily_notes = {
        folder = 'journal',
        date_format = '%Y.%m.%d',
        template = 'daily.md',
      },
      -- The old config's `nvim_cmp = true` is gone from obsidian upstream:
      -- completion now comes from its own in-process `obsidian-ls` LSP server, so
      -- it lands in the native menu core/lsp.lua already autotriggers. min_chars
      -- is all that is left to carry over.
      completion = { min_chars = 2 },
      picker = {
        name = 'telescope.nvim',
        note_mappings = { new = '<C-x>', insert_link = '<C-l>' },
        tag_mappings = { tag_note = '<C-x>', insert_tag = '<C-l>' },
      },
    },
    config = function(_, opts)
      require('obsidian').setup(opts)

      -- With the vault as cwd there is no code to find, so the four general
      -- finders become obsidian's. Done here rather than in telescope.lua
      -- because the override only makes sense once obsidian is loaded.
      --
      -- Applied and *undone* on DirChanged: these are global maps, so setting
      -- them once at load meant a :cd out of the vault left <leader>ff still
      -- searching notes for the rest of the session. maparg/mapset round-trips
      -- whatever telescope had there (including lazy's not-yet-loaded stub).
      local OVERRIDES = {
        { '<leader>ff', ':Obsidian quick_switch<cr>', 'files(notes)' },
        { '<leader>?', ':Obsidian search<cr>', 'find_global(notes)' },
        { '<leader>fs', ':Obsidian toc<cr>', 'symbols(notes)' },
        { '<leader>fS', ':Obsidian tags<cr>', 'tags(notes)' },
      }
      local saved = nil

      -- Resolved on both sides: vim.uv.cwd() reports the real path, so a vault
      -- reached through a symlink (~/notes -> a cloud folder, /tmp -> /private/tmp
      -- on macOS) would never compare equal to the configured one.
      local function same_dir(a, b)
        if a == '' or b == '' then
          return false
        end
        return (vim.uv.fs_realpath(a) or a) == (vim.uv.fs_realpath(b) or b)
      end

      local function sync_note_finders()
        local in_vault = same_dir(vim.fs.normalize(vim.uv.cwd() or ''), notes)
        if in_vault and not saved then
          saved = {}
          for _, o in ipairs(OVERRIDES) do
            saved[o[1]] = vim.fn.maparg(o[1], 'n', false, true)
            vim.keymap.set('n', o[1], o[2], { desc = o[3], silent = true })
          end
        elseif not in_vault and saved then
          for _, o in ipairs(OVERRIDES) do
            pcall(vim.keymap.del, 'n', o[1])
            local prev = saved[o[1]]
            if type(prev) == 'table' and not vim.tbl_isempty(prev) then
              pcall(vim.fn.mapset, 'n', false, prev)
            end
          end
          saved = nil
        end
      end

      sync_note_finders()
      vim.api.nvim_create_autocmd('DirChanged', {
        group = vim.api.nvim_create_augroup('obsidian_note_finders', { clear = true }),
        desc = 'point the general finders at the vault only while cwd is the vault',
        callback = sync_note_finders,
      })

      vim.api.nvim_create_autocmd('User', {
        group = vim.api.nvim_create_augroup('obsidian_note', { clear = true }),
        pattern = 'ObsidianNoteEnter',
        desc = 'toggle a checkbox from anywhere on its line',
        callback = function(ev)
          vim.keymap.set({ 'n', 'v' }, 'mc', ':Obsidian toggle_checkbox<cr>', {
            buffer = ev.buf,
            desc = 'smart_action(obsidian)',
            silent = true,
          })
        end,
      })
    end,
  },
}
