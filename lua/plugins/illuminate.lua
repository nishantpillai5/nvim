return {
  {
    'RRethy/vim-illuminate',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      require('illuminate').configure {
        providers = { 'lsp', 'treesitter', 'regex' },
        filetypes_denylist = { 'fugitive', 'dashboard' },
      }
    end,
  },
}
