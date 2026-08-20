-- Parsers, and nothing else. The `main` branch does not start highlighting on
-- its own, and the old config never asked it to either -- the parsers are here
-- for the plugins that query the tree (treesj, hop's `S`, indent-blankline's
-- scope, codecompanion), not to replace the theme's regex syntax. Adding
-- `vim.treesitter.start()` to a FileType autocmd is all that switching
-- highlighting on would take.
--
-- The list itself lives in util/parsers.lua, so the container build can install
-- it synchronously without repeating it.
return {
  {
    'nvim-treesitter/nvim-treesitter',
    -- `main` is the rewrite, and the only branch with `install()`. Named
    -- explicitly because landing on `master` swaps the whole API out quietly.
    branch = 'main',
    lazy = false,
    build = ':TSUpdate',
    config = function()
      -- Async, and a no-op for parsers already on disk.
      require('nvim-treesitter').install(require 'util.parsers')
    end,
  },
}
