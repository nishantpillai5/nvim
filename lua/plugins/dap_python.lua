-- Registers the `python` adapter, which makes neotest's <leader>id work. Off in
-- enabled.lua: it needs debugpy in NVIM_PYTHON's own environment.
return {
  {
    'mfussenegger/nvim-dap-python',
    dependencies = { 'mfussenegger/nvim-dap' },
    ft = 'python',
    config = function()
      require('dap-python').setup(require('util.env').NVIM_PYTHON)
    end,
  },
}
