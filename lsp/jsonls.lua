-- The schema catalog is attached in `on_init`, which runs once the server has
-- started, so schemastore.nvim stays out of startup. A top-level require would
-- load it immediately, because vim.lsp.enable reads this file eagerly.
-- It mutates `client.settings`, not the config table: Neovim pushes
-- client.settings to the server via workspace/didChangeConfiguration.
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
