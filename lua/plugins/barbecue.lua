return {
  {
    'utilyre/barbecue.nvim',
    name = 'barbecue',
    version = '*',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = { 'SmiteshP/nvim-navic', 'nvim-tree/nvim-web-devicons' },
    opts = {
      theme = { basename = { bold = true } },
      show_basename = true,
      show_dirname = false,
      show_navic = false,
      show_modified = true,
    },
  },
}
