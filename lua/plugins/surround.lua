return {
  {
    'echasnovski/mini.surround',
    version = '*',
    keys = {
      { '<leader>v', mode = { 'n', 'x' }, desc = 'surround' },
      { '<leader>Vd', desc = 'delete' },
      { '<leader>Vf', desc = 'find' },
      { '<leader>VF', desc = 'find_left' },
      { '<leader>Vh', desc = 'highlight' },
      { '<leader>Vr', desc = 'replace' },
      { '<leader>Vn', desc = 'update_n_lines' },
    },
    opts = {
      search_method = 'cover_or_nearest',
      mappings = {
        add = '<leader>v',
        delete = '<leader>Vd',
        find = '<leader>Vf',
        find_left = '<leader>VF',
        highlight = '<leader>Vh',
        replace = '<leader>Vr',
        update_n_lines = '<leader>Vn',
        suffix_last = 'l',
        suffix_next = 'n',
      },
    },
  },
}
