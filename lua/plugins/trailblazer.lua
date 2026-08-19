return {
  {
    'LeonHeidelbach/trailblazer.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    keys = {
      { '<leader>wm', '<cmd>TrailBlazerLoadSession<cr>', desc = 'load_marks' },
    },
    config = function()
      require('trailblazer').setup {
        auto_save_trailblazer_state_on_exit = true,
        trail_options = {
          current_trail_mark_mode = 'buffer_local_line_sorted',
          multiple_mark_symbol_counters_enabled = false,
          trail_mark_in_text_highlights_enabled = true,
          mark_symbol = '',
          newest_mark_symbol = '',
          cursor_mark_symbol = '',
          next_mark_symbol = '',
          previous_mark_symbol = '',
        },
        -- trailblazer binds these itself; their which-key labels live in
        -- plugins/whichkey.lua since there is no desc to read off them.
        force_mappings = {
          nv = {
            motions = {
              track_back = 'mx',
              move_to_nearest = 'mn',
              toggle_trail_mark_list = '<leader>m',
            },
            actions = {
              delete_all_trail_marks = 'mD',
              paste_at_last_trail_mark = 'mp',
              paste_at_all_trail_marks = 'mP',
            },
          },
        },
      }

      local actions = require 'trailblazer.trails.actions'
      local common = require 'trailblazer.trails.common'
      local motions = require 'trailblazer.trails.motions'

      local function map(lhs, rhs, desc)
        vim.keymap.set('n', lhs, rhs, { noremap = true, silent = true, desc = desc })
      end

      -- Mark the cursor position, then clear any other mark on the same line so
      -- one line never carries more than a single mark.
      map('mm', function()
        local win = vim.api.nvim_get_current_win()
        local buf = vim.api.nvim_get_current_buf()
        local pos = vim.api.nvim_win_get_cursor(win)
        actions.new_trail_mark(win, buf, pos)

        local line = vim.api.nvim_get_current_line()
        for col = 0, #line - 1 do
          if col ~= pos[2] then
            common.delete_trail_mark_at_pos(win, buf, { pos[1], col })
          end
        end
      end, 'mark')

      map('md', function()
        actions.delete_all_trail_marks(vim.api.nvim_get_current_buf())
      end, 'delete_in_buffer')

      map('<C-PageDown>', function()
        motions.peek_move_next_down()
        vim.cmd 'normal! zz'
      end, 'next_mark')

      map('<C-PageUp>', function()
        motions.peek_move_previous_up()
        vim.cmd 'normal! zz'
      end, 'previous_mark')
    end,
  },
}
