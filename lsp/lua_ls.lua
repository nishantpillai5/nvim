-- Neovim discovers `lsp/<name>.lua` on the runtimepath and merges it into
-- `vim.lsp.config` when `vim.lsp.enable('<name>')` runs. No nvim-lspconfig.
-- lazydev.nvim supplies the workspace library, so there's no on_init hook here.
return {
  cmd = { 'lua-language-server' },
  filetypes = { 'lua' },
  root_markers = { '.luarc.json', '.luarc.jsonc', '.stylua.toml', 'stylua.toml', '.git' },
  settings = {
    Lua = {
      runtime = { version = 'LuaJIT' },
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
    },
  },
}
