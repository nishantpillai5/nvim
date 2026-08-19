-- `_G.custom_formatters_by_ft` lets a project-local exrc file add formatters.
return {
  {
    'stevearc/conform.nvim',
    event = 'BufWritePre',
    keys = {
      {
        '<leader>ls',
        function()
          require('conform').format({ async = true, lsp_format = 'fallback', timeout_ms = 500 }, function(err)
            if not err then
              vim.notify 'Formatted'
            end
          end)
        end,
        mode = { 'n', 'v' },
        desc = 'format',
      },
    },
    opts = function()
      return {
        formatters_by_ft = vim.tbl_deep_extend('force', {
          lua = { 'stylua' },
          json = { 'prettier' },
          jsonc = { 'prettier' },
          javascript = { 'prettier' },
          typescript = { 'prettier', 'eslint_d' },
          c = { 'clang-format' },
          cpp = { 'clang-format' },
          python = { 'black', 'isort' },
          markdown = { 'prettier' },
          ['_'] = { 'trim_whitespace' },
        }, _G.custom_formatters_by_ft or {}),
      }
    end,
  },
}
