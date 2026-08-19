return {
  {
    'chrisgrieser/nvim-spider',
    keys = {
      {
        'W',
        function()
          require('spider').motion 'w'
        end,
        mode = { 'n', 'o', 'x' },
        desc = 'spider_w',
      },
      {
        'E',
        function()
          require('spider').motion 'e'
        end,
        mode = { 'n', 'o', 'x' },
        desc = 'spider_e',
      },
      {
        'B',
        function()
          require('spider').motion 'b'
        end,
        mode = { 'n', 'o', 'x' },
        desc = 'spider_b',
      },
    },
    opts = {
      skipInsignificantPunctuation = true,
      consistentOperatorPending = false,
      subwordMovement = true,
      customPatterns = {},
    },
  },
}
