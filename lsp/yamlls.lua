-- See lsp/jsonls.lua for why the catalog is attached in `on_init`.
return {
  cmd = { 'yaml-language-server', '--stdio' },
  filetypes = { 'yaml', 'yaml.docker-compose', 'yaml.gitlab' },
  root_markers = { '.git' },
  settings = {
    -- Built-in store off; schemastore.nvim provides the catalog instead.
    yaml = { schemaStore = { enable = false, url = '' } },
  },
  on_init = function(client)
    client.settings = vim.tbl_deep_extend('force', client.settings or {}, {
      yaml = { schemas = require('schemastore').yaml.schemas() },
    })
  end,
}
