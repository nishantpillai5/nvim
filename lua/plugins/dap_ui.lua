-- The docked debugger views: scopes, breakpoints, stacks, watches, console and
-- REPL. edgy.lua already has a slot for each of those filetypes, so they dock
-- rather than splitting wherever they land.

-- While the views are open, K evaluates instead of hovering. The old config set
-- this buffer-locally at toggle time, which meant it stopped working the moment
-- you moved to another buffer -- inspecting values across files is the whole
-- point, so the mappings are global here and removed again on close. Deleting
-- them restores Neovim's built-in K: hover on an LSP buffer, keywordprg
-- otherwise (core/lsp.lua adds no mapping of its own).
local dapui_open = false

local function set_eval_keys(enable)
  if enable then
    vim.keymap.set('n', 'K', function()
      require('dapui').eval(vim.fn.expand '<cWORD>')
    end, { desc = 'dap_eval' })
    -- With no argument dapui evaluates the visual selection.
    vim.keymap.set('v', 'K', function()
      require('dapui').eval()
    end, { desc = 'dap_eval' })
  else
    pcall(vim.keymap.del, 'n', 'K')
    pcall(vim.keymap.del, 'v', 'K')
  end
end

local function toggle()
  require('dapui').toggle()
  dapui_open = not dapui_open
  vim.notify('dapui_open: ' .. tostring(dapui_open))
  set_eval_keys(dapui_open)
end

return {
  {
    'rcarriga/nvim-dap-ui',
    dependencies = { 'mfussenegger/nvim-dap', 'nvim-neotest/nvim-nio' },
    keys = {
      { '<leader>bb', toggle, desc = 'toggle_view' },
      {
        '<leader>bK',
        function()
          require('dapui').eval(vim.fn.expand '<cWORD>')
        end,
        desc = 'hover',
      },
    },
    opts = {},
  },
}
