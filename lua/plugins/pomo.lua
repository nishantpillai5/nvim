return {
  {
    'epwalsh/pomo.nvim',
    version = '*',
    dependencies = { 'rcarriga/nvim-notify' },
    cmd = { 'TimerStart', 'TimerRepeat', 'TimerSession' },
    keys = {
      { '<leader>zts', '<cmd>TimerSession pomodoro<cr>', desc = 'start' },
      { '<leader>ztr', '<cmd>TimerResume<cr>', desc = 'resume' },
      { '<leader>ztp', '<cmd>TimerPause<cr>', desc = 'pause' },
      {
        '<leader>ztf',
        function()
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
