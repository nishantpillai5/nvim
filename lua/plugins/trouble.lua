-- The five `(Trouble)` slots in plugins/edgy.lua dock these by mode -- diagnostics
-- and the qf/loclist lists at the bottom, lsp and telescope on the right -- so no
-- window options are set here. Two deliberate departures from the old config:
-- `auto_refresh` keeps its default, so a list follows the fixes rather than going
-- stale, and references moved off `gr` because 0.11 owns the `gr*` prefix.
return {
  {
    'folke/trouble.nvim',
    cmd = 'Trouble',
    keys = {
      -- `last` is a real pseudo-mode: it resolves to whichever mode was open.
      { '<leader>tt', '<cmd>Trouble last toggle<cr>', desc = 'toggle' },
      { '<leader>td', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', desc = 'diagnostics' },
      { '<leader>tD', '<cmd>Trouble diagnostics toggle<cr>', desc = 'diagnostics_global' },
      { '<leader>tq', '<cmd>Trouble qflist toggle<cr>', desc = 'quickfix' },
      { '<leader>tL', '<cmd>Trouble loclist toggle<cr>', desc = 'loclist' },
      { '<leader>tl', '<cmd>Trouble lsp toggle focus=false<cr>', desc = 'lsp' },
      { '<leader>tr', '<cmd>Trouble lsp_references toggle<cr>', desc = 'references' },
      -- Populated by the T / t mappings in plugins/telescope.lua.
      { '<leader>tf', '<cmd>Trouble telescope toggle<cr>', desc = 'finder' },
      -- Not trouble's own list: gitsigns fills the loclist, the autocmd below
      -- turns it into one.
      { '<leader>tg', '<cmd>Gitsigns setloclist<cr>', desc = 'git' },
      -- `:TodoTrouble` is todo-comments' own command (its plugin/todo.vim), and
      -- the fork ships the `todo` source trouble reads.
      { '<leader>tT', '<cmd>TodoTrouble<cr>', desc = 'todos' },
      {
        '<M-j>',
        function()
          require('trouble').next { jump = true }
        end,
        desc = 'trouble_next',
      },
      {
        '<M-k>',
        function()
          require('trouble').prev { jump = true }
        end,
        desc = 'trouble_prev',
      },
    },
    opts = {},
    init = function()
      -- Quickfix and location lists open as trouble instead. This has to be
      -- registered up front rather than in `config`, or the first :copen of a
      -- session would beat the plugin to it -- the `Trouble` command in the
      -- callback is what loads it.
      vim.api.nvim_create_autocmd('BufRead', {
        group = vim.api.nvim_create_augroup('trouble_list_takeover', { clear = true }),
        callback = function(ev)
          if vim.bo[ev.buf].buftype ~= 'quickfix' then
            return
          end
          -- A loclist window has a file window behind it; the quickfix one does not.
          local is_loclist = vim.fn.getloclist(0, { filewinid = 1 }).filewinid ~= 0
          vim.schedule(function()
            if is_loclist then
              vim.cmd.lclose()
              vim.cmd 'Trouble loclist open'
            else
              vim.cmd.cclose()
              vim.cmd 'Trouble qflist open'
            end
          end)
        end,
      })
    end,
  },
}
