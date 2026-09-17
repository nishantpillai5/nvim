-- A module rather than a local in plugins/treesitter.lua, so the Dockerfile's
-- build step can install exactly this list and block until it finishes:
--
--   nvim --headless '+lua require("nvim-treesitter").install(require("util.parsers")):wait(900000)' +qa
--
-- json covers the jsonc filetype, which has no parser of its own; latex is the
-- injected language snacks.image looks for to find equations.
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
  'latex',
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
