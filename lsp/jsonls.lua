-- In `on_init`, or vim.lsp.enable's eager read of this file pulls
-- schemastore.nvim into startup. It mutates `client.settings`, which Neovim
-- pushes to the server, not the config table.
return {
  cmd = { 'vscode-json-language-server', '--stdio' },
  filetypes = { 'json', 'jsonc' },
  root_markers = { '.git' },
  settings = {
    json = { validate = { enable = true } },
  },
  on_init = function(client)
    client.settings = vim.tbl_deep_extend('force', client.settings or {}, {
      json = { schemas = require('schemastore').json.schemas() },
    })
  end,
}
