return {
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    keys = {
      { '<leader>gB', '<cmd>Gitsigns blame<cr>', desc = 'blame_buffer' },
    },
    opts = {
      current_line_blame_opts = { delay = 100 },
      on_attach = function(bufnr)
        local gs = require 'gitsigns'
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, noremap = true, silent = true, desc = desc })
        end

        -- In a diff, keep vim's own ]c / [c behaviour.
        map('n', ']c', function()
          if vim.wo.diff then
            vim.cmd.normal { ']c', bang = true }
          else
            gs.nav_hunk 'next'
          end
        end, 'next_hunk')
        map('n', '[c', function()
          if vim.wo.diff then
            vim.cmd.normal { '[c', bang = true }
          else
            gs.nav_hunk 'prev'
          end
        end, 'prev_hunk')

        map('n', '<leader>ghs', gs.stage_hunk, 'stage')
        map('n', '<leader>ghr', gs.reset_hunk, 'reset')
        map('v', '<leader>ghs', function()
          gs.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, 'stage')
        map('v', '<leader>ghr', function()
          gs.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, 'reset')
        map('n', '<leader>ghS', gs.stage_buffer, 'stage_buffer')
        map('n', '<leader>ghu', gs.undo_stage_hunk, 'undo_stage')
        map('n', '<leader>ghR', gs.reset_buffer, 'reset_buffer')
        map('n', '<leader>gRj', gs.reset_buffer, 'reset_file')
        map('n', '<leader>ghd', gs.preview_hunk, 'diff')
        map('n', '<leader>ghb', function()
          gs.blame_line { full = true }
        end, 'blame')
        map('n', '<leader>gV', gs.toggle_deleted, 'virtual_deleted')
        map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>', 'select_hunk')

        -- Feed hunk marks to the scrollbar.
        require('scrollbar.handlers.gitsigns').setup()
      end,
    },
  },
}
