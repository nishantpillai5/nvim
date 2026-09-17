-- `vim.filetype.add` runs at detection time, so unlike a FileType autocmd
-- nothing has to re-fire after the buffer is already set up.
vim.filetype.add {
  extension = {
    -- Comments are common in json config files; jsonc tolerates them.
    json = 'jsonc',
    -- strudel; the plugin sets these too, this way they hold without it.
    str = 'javascript',
    std = 'javascript',
  },
  pattern = {
    -- The runtime's own `log` extension entry resolves only four vendor names
    -- and leaves a plain `app.log` untyped. The negative priority keeps those
    -- four: patterns below zero are consulted only after the extension table.
    ['.*%.[lL][oO][gG]'] = { 'log', { priority = -10 } },
    ['.*_[lL][oO][gG]'] = { 'log', { priority = -10 } },
  },
}
