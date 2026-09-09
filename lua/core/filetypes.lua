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
  pattern = {
    -- Log files, in place of vim-log-highlighting: the runtime already carries
    -- that plugin's syntax file (`$VIMRUNTIME/syntax/log.vim`, MTDL9 credited as
    -- former maintainer), but its `log` extension entry resolves only four
    -- vendor names -- upstream, upstreaminstall, usserver, usw2kagt -- and
    -- leaves a plain `app.log` with no filetype at all. The negative priority is
    -- what keeps those four: patterns below zero are consulted only after the
    -- extension table has already failed.
    ['.*%.[lL][oO][gG]'] = { 'log', { priority = -10 } },
    ['.*_[lL][oO][gG]'] = { 'log', { priority = -10 } },
  },
}
