-- Filetype overrides. These replace the `FileType`/`BufRead` autocmds the old
-- config used for the same job -- `vim.filetype.add` runs at detection time, so
-- nothing has to re-fire after the buffer is already set up.
vim.filetype.add {
  extension = {
    -- Comments are common in json config files; jsonc tolerates them.
    json = 'jsonc',
    -- strudel; the plugin sets these too, this way they hold without it.
    str = 'javascript',
    std = 'javascript',
  },
}
