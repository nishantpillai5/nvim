-- The docked debugger views; edgy.lua has a slot for each filetype. While they
-- are open K evaluates instead of hovering, mapped globally rather than per
-- buffer because inspecting values across files is the point.
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
