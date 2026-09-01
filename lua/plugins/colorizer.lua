return {
  {
    'norcalli/nvim-colorizer.lua',
    -- Not VeryLazy: setup() only registers FileType autocmds and never attaches
    -- buffers that are already open, so `nvim foo.css` would go uncolored until
    -- the next :e.
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      require('colorizer').setup(
        { 'lua', 'css', 'javascript', html = { mode = 'foreground' } },
        { mode = 'background' }
      )
    end,
  },
}
