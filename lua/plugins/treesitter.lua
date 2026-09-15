-- Parsers, plus the FileType autocmd that turns their highlighting on -- the
-- `main` branch starts nothing by itself. The same parsers back every plugin
-- that queries the tree (treesj, hop's `S`, indent-blankline's scope,
-- codecompanion).
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

      -- start() throws where the filetype has no parser installed, which is
      -- every buffer this config never listed -- so the regex syntax stays the
      -- fallback. Where it succeeds it clears &syntax itself.
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('treesitter_highlight', { clear = true }),
        desc = 'start treesitter highlighting where a parser exists',
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },
}
