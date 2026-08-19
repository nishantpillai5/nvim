return {
  {
    'rcarriga/nvim-notify',
    event = 'VeryLazy',
    opts = {
      stages = 'static',
      timeout = 2000,
      render = 'compact',
      top_down = true,
    },
    config = function(_, opts)
      require('notify').setup(opts)
      vim.notify = require 'notify'
    end,
  },
}
