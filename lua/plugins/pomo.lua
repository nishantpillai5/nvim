return {
  {
    'epwalsh/pomo.nvim',
    version = '*',
    dependencies = { 'rcarriga/nvim-notify' },
    cmd = { 'TimerStart', 'TimerRepeat', 'TimerSession' },
    keys = {
      { '<leader>zps', '<cmd>TimerSession pomodoro<cr>', desc = 'start' },
      { '<leader>zpr', '<cmd>TimerResume<cr>', desc = 'resume' },
      { '<leader>zpp', '<cmd>TimerPause<cr>', desc = 'pause' },
      {
        '<leader>zpf',
        function()
          -- Loaded on demand rather than in config, so pomo doesn't pull
          -- telescope in at startup.
          require('telescope').load_extension 'pomodori'
          require('telescope').extensions.pomodori.timers()
        end,
        desc = 'find',
      },
    },
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      notifiers = {
        { name = 'Default', opts = { sticky = false } },
      },
      sessions = {
        pomodoro = {
          { name = 'Work', duration = '25m' },
          { name = 'Short Break', duration = '5m' },
        },
      },
    },
  },
}
