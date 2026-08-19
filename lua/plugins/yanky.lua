return {
  {
    'gbprod/yanky.nvim',
    keys = {
      { 'p', '<Plug>(YankyPutAfter)', mode = { 'n', 'x' }, desc = 'yank_after' },
      { 'P', '<Plug>(YankyPutBefore)', mode = { 'n', 'x' }, desc = 'yank_before' },
      { 'gp', '<Plug>(YankyGPutAfter)', mode = { 'n', 'x' }, desc = 'yank_gput_after' },
      { 'gP', '<Plug>(YankyGPutBefore)', mode = { 'n', 'x' }, desc = 'yank_gput_before' },
      { '<c-p>', '<Plug>(YankyPreviousEntry)', desc = 'yank_prev' },
      { '<c-n>', '<Plug>(YankyNextEntry)', desc = 'yank_next' },
      {
        '<leader>fp',
        function()
          -- Load on demand so this works whichever of the two loads first.
          require('telescope').load_extension 'yank_history'
          vim.cmd 'Telescope yank_history'
        end,
        desc = 'yank',
      },
    },
    opts = {
      highlight = { timer = 200 },
    },
  },
}
