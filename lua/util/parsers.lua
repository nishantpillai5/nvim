-- The treesitter parsers this config installs. A module rather than a local in
-- plugins/treesitter.lua so the Dockerfile's build step can install exactly this
-- list and block until it finishes, without repeating it:
--
--   nvim --headless '+lua require("nvim-treesitter").install(require("util.parsers")):wait(900000)' +qa
--
-- json covers the jsonc filetype core/filetypes.lua sends .json files to --
-- `vim.treesitter.language.get_lang 'jsonc'` resolves to json, and there is no
-- separate jsonc parser to install.
return {
  'bash',
  'c',
  'cpp',
  'diff',
  'gitignore',
  'graphql',
  'html',
  'http',
  'javascript',
  'json',
  'lua',
  'markdown',
  'markdown_inline',
  'properties',
  'python',
  'regex',
  'typescript',
  'vim',
  'vimdoc',
  'xml',
}
