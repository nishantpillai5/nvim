-- Parsers, plus the FileType autocmd that turns highlighting on -- the `main`
-- branch starts nothing itself. The list lives in util/parsers.lua.
return {
  {
    'nvim-treesitter/nvim-treesitter',
    -- `main` is the rewrite; landing on `master` swaps the whole API out.
    branch = 'main',
    lazy = false,
    build = ':TSUpdate',
    config = function()
      -- Async, and a no-op for parsers already on disk.
      require('nvim-treesitter').install(require 'util.parsers')

      -- start() throws where no parser is installed, so regex syntax stays the
      -- fallback; where it succeeds it clears &syntax itself.
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
