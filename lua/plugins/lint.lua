return {
  {
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'

      lint.linters_by_ft = {
        -- cppcheck is broken upstream: mfussenegger/nvim-lint#745
        c = { 'cppcheck' },
        typescript = { 'eslint_d' },
        javascript = { 'eslint_d' },
      }

      -- nvim-lint spawns a linter whether or not its binary exists, so a missing
      -- one errors on every BufEnter / InsertLeave / BufWritePost. Resolve each
      -- linter's command up front and run only what's actually installed.
      local function available(names)
        local runnable = {}
        for _, name in ipairs(names or {}) do
          local linter = lint.linters[name]
          local cmd = linter and linter.cmd
          if type(cmd) == 'function' then
            cmd = cmd()
          end
          if cmd and vim.fn.executable(cmd) == 1 then
            table.insert(runnable, name)
          end
        end
        return runnable
      end

      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = vim.api.nvim_create_augroup('lint', { clear = true }),
        callback = function()
          local names = available(lint.linters_by_ft[vim.bo.filetype])
          if #names > 0 then
            lint.try_lint(names)
          end
        end,
      })
    end,
  },
}
