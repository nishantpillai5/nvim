-- Python debugging: registers the `python` adapter and the usual launch
-- configurations, and is what makes neotest's <leader>id work on python tests.
--
-- Off by default in enabled.lua, as it was in the old config. It needs debugpy
-- installed in NVIM_PYTHON's environment (`:MasonInstallAll` covers Mason's own
-- copy; `<venv>/bin/python -m pip install debugpy` covers this one).
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
