-- Native LSP wiring. Nothing here needs a plugin: Neovim 0.12 supplies
-- vim.lsp.config / vim.lsp.enable, vim.lsp.completion and vim.diagnostic.
--
-- Server definitions live in <config>/lsp/<name>.lua. vim.lsp.enable reads them
-- eagerly, so this module is required after lazy.nvim is set up.
local SERVERS = {
  'lua_ls',
  'clangd',
  'pyright',
  'ts_ls',
  'jsonls',
  'yamlls',
  'bashls',
}

-- Mason package names for the servers above, plus the formatters conform.lua
-- and the linters lint.lua reference. Installed by :MasonInstallAll.
local MASON_PACKAGES = {
  -- servers
  'lua-language-server',
  'clangd',
  'pyright',
  'typescript-language-server',
  'json-lsp',
  'yaml-language-server',
  'bash-language-server',
  -- formatters (plugins/conform.lua)
  'stylua',
  'prettier',
  'clang-format',
  'black',
  'isort',
  -- linters (plugins/lint.lua)
  'eslint_d',
  'cppcheck',
  -- debug adapters (plugins/dap.lua): cpptools ships OpenDebugAD7 for the
  -- cppdbg adapter, debugpy backs dap-python and neotest's <leader>id.
  'cpptools',
  'debugpy',
}

vim.diagnostic.config {
  virtual_text = true,
  signs = false,
  severity_sort = true,
  underline = true,
  -- 0.11+: opening the float on ]d / [d jumps.
  jump = { float = true },
}

local function on_attach(client, bufnr)
  -- Native completion. autotrigger fires while typing; without it the same menu
  -- is available on <C-x><C-o>.
  if client:supports_method 'textDocument/completion' then
    vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
  end

  local function map(lhs, rhs, desc, mode)
    vim.keymap.set(mode or 'n', lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
  end

  -- 0.11+ already binds grn (rename), gra (code action), grr (references),
  -- gri (implementation), grt (type definition), gO (document symbols), K
  -- (hover), and <C-s> (signature help, insert mode). What follows are the
  -- <leader>l equivalents from the old config, kept for muscle memory.
  map('<leader>la', vim.lsp.buf.code_action, 'action', { 'n', 'v' })
  map('<leader>lr', vim.lsp.buf.rename, 'rename')
  map('<leader>rl', vim.lsp.buf.rename, 'rename_with_lsp')
  map('<leader>lh', vim.lsp.buf.hover, 'hints_view(K)')
  map('<leader>ld', vim.diagnostic.open_float, 'diagnostic_view')
  map('<leader>lS', function()
    vim.lsp.buf.format { async = true }
  end, 'format_with_lsp', { 'n', 'v' })

  map('<leader>lH', function()
    local filter = { bufnr = bufnr }
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled(filter), filter)
  end, 'hints_toggle')

  map('<leader>lD', function()
    local current = vim.diagnostic.config() or {}
    vim.diagnostic.config { virtual_text = not current.virtual_text, signs = false }
  end, 'diagnostics_toggle')

  map('<leader>lx', function()
    vim.cmd.LspRestart(client.name)
    vim.notify('LSP restarted: ' .. client.name)
  end, 'refresh')
end

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('core_lsp_attach', { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client then
      on_attach(client, args.buf)
    end
  end,
})

vim.lsp.inlay_hint.enable()

-- Registers all servers; each is started only when its filetype and root
-- markers match.
vim.lsp.enable(SERVERS)

vim.api.nvim_create_user_command('MasonInstallAll', function()
  vim.cmd('MasonInstall ' .. table.concat(MASON_PACKAGES, ' '))
end, { desc = 'Install every server, formatter and linter this config uses' })
