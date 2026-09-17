-- Native LSP wiring; no plugin needed on Neovim 0.12. Server definitions live in
-- <config>/lsp/<name>.lua, read eagerly -- so this loads after lazy.nvim.
local SERVERS = {
  'lua_ls',
  'clangd',
  'pyright',
  'ts_ls',
  'jsonls',
  'yamlls',
  'bashls',
}

-- Installed by :MasonInstallAll.
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
  -- debug adapters (plugins/dap.lua): cpptools ships OpenDebugAD7 for cppdbg.
  'cpptools',
  'debugpy',
}

vim.diagnostic.config {
  virtual_text = true,
  signs = false,
  severity_sort = true,
  underline = true,
  -- 0.11+: the float opens on the ]d / [d jump.
  jump = {
    on_jump = function(_, bufnr)
      vim.diagnostic.open_float { bufnr = bufnr, scope = 'cursor', focus = false }
    end,
  },
}

local function on_attach(client, bufnr)
  -- autotrigger fires while typing; without it the menu is on <C-x><C-o>.
  if client:supports_method 'textDocument/completion' then
    vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
  end

  local function map(lhs, rhs, desc, mode)
    vim.keymap.set(mode or 'n', lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
  end

  -- 0.11+ already binds grn, gra, grr, gri, grt, gO, K and <C-s>; these are the
  -- <leader>l equivalents, kept for muscle memory.
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

-- Each server starts only when its filetype and root markers match.
vim.lsp.enable(SERVERS)

vim.api.nvim_create_user_command('MasonInstallAll', function()
  vim.cmd('MasonInstall ' .. table.concat(MASON_PACKAGES, ' '))
end, { desc = 'Install every server, formatter and linter this config uses' })
