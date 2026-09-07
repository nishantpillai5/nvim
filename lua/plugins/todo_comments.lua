-- A fork, per the old config: circular todos aren't merged upstream.
return {
  {
    'nishantpillai5/todo-comments.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = { 'nvim-lua/plenary.nvim' },
    keys = {
      {
        ']t',
        function()
          require('todo-comments').jump_next { wrap = true }
        end,
        desc = 'todo',
      },
      {
        '[t',
        function()
          require('todo-comments').jump_prev { wrap = true }
        end,
        desc = 'todo',
      },
      {
        ']T',
        function()
          require('todo-comments').jump_next { last = true }
        end,
        desc = 'todo_last',
      },
      {
        '[T',
        function()
          require('todo-comments').jump_prev { last = true }
        end,
        desc = 'todo_first',
      },
      { '<leader>fT', '<cmd>TodoTelescope<cr>', desc = 'todos' },
    },
    opts = function()
      -- Highlight the user's own TODO prefix
      return {
        keywords = {
          [require('util.env').TODO_CUSTOM] = { icon = '󰬕', color = 'info' },
        },
      }
    end,
  },
}
