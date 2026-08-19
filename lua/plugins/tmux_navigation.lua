return {
  {
    'alexghergh/nvim-tmux-navigation',
    event = { 'BufReadPre', 'BufNewFile' },
    keys = {
      { '<C-h>', '<cmd>NvimTmuxNavigateLeft<cr>', mode = { 'n', 'v' }, desc = 'navigate_left' },
      { '<C-j>', '<cmd>NvimTmuxNavigateDown<cr>', mode = { 'n', 'v' }, desc = 'navigate_down' },
      { '<C-k>', '<cmd>NvimTmuxNavigateUp<cr>', mode = { 'n', 'v' }, desc = 'navigate_up' },
      { '<C-l>', '<cmd>NvimTmuxNavigateRight<cr>', mode = { 'n', 'v' }, desc = 'navigate_right' },
      {
        '<C-Space>',
        '<cmd>NvimTmuxNavigateLastActive<cr>',
        mode = { 'n', 'v' },
        desc = 'navigate_last_active',
      },
      { '<C-\\>', '<cmd>NvimTmuxNavigateNext<cr>', mode = { 'n', 'v' }, desc = 'navigate_next' },
    },
    opts = {
      disable_when_zoomed = true,
    },
  },
}
