-- The `(Trouble)` slots in plugins/edgy.lua dock these by mode, so no window
-- options are set here. References are off `gr`, which 0.11 owns.
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
      -- gitsigns fills the loclist; the autocmd below turns it into one.
      { '<leader>tg', '<cmd>Gitsigns setloclist<cr>', desc = 'git' },
      -- `:TodoTrouble` is todo-comments' own, and the fork ships this source.
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
      -- Registered up front rather than in `config`, or the session's first
      -- :copen beats the plugin to it; the `Trouble` command below loads it.
      vim.api.nvim_create_autocmd('BufRead', {
        group = vim.api.nvim_create_augroup('trouble_list_takeover', { clear = true }),
        callback = function(ev)
          if vim.bo[ev.buf].buftype ~= 'quickfix' then
            return
          end
          -- A loclist window has a file window behind it; a quickfix one does not.
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
