-- Typing practice, for when the day is already lost.
return {
  {
    'kwakzalver/duckytype.nvim',
    cmd = 'DuckyType',
    keys = {
      { '<leader>zOt', '<cmd>DuckyType english_common<cr>', desc = 'typing_test_eng' },
      { '<leader>zOT', '<cmd>DuckyType cpp_keywords<cr>', desc = 'typing_test_code' },
    },
    opts = {},
  },
}
