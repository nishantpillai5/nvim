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
      if vim.fs.normalize(vim.uv.cwd() or '') == notes then
        local map = function(lhs, rhs, desc)
          vim.keymap.set('n', lhs, rhs, { desc = desc, silent = true })
        end
        map('<leader>ff', ':Obsidian quick_switch<cr>', 'files(notes)')
        map('<leader>?', ':Obsidian search<cr>', 'find_global(notes)')
        map('<leader>fs', ':Obsidian toc<cr>', 'symbols(notes)')
        map('<leader>fS', ':Obsidian tags<cr>', 'tags(notes)')
      end

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
