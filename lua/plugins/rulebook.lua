-- Matches a diagnostic to its rule by `source` and `code`, so only diagnostics
-- carrying both are actionable -- the LSP client and nvim-lint both set them.
-- `setup` is optional and only needed to add sources, so there is no `opts`.
return {
  {
    'chrisgrieser/nvim-rulebook',
    keys = {
      {
        '<leader>li',
        function()
          require('rulebook').ignoreRule()
        end,
        desc = 'ignore_rule',
      },
      {
        '<leader>lI',
        function()
          require('rulebook').suppressFormatter()
        end,
        mode = { 'n', 'x' },
        desc = 'ignore_formatter',
      },
      {
        '<leader>lF',
        function()
          require('rulebook').lookupRule()
        end,
        desc = 'lookup_diagnostic_code',
      },
      {
        '<leader>lY',
        function()
          require('rulebook').yankDiagnosticCode()
        end,
        desc = 'yank_diagnostic_code',
      },
    },
  },
}
