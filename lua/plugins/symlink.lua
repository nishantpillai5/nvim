-- Edits the symlink target rather than the link itself.
return {
  {
    'aymericbeaumet/vim-symlink',
    event = 'VeryLazy',
    dependencies = { 'moll/vim-bbye' },
  },
}
