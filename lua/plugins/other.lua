return {
  {
    'rgroli/other.nvim',
    main = 'other-nvim',
    keys = {
      { '<leader>hA', '<cmd>Other<cr>', desc = 'alternate_file' },
    },
    opts = function()
      -- `_G.other_mappings` lets a project-local exrc file add its own pairs.
      local mappings = { 'c' }
      vim.list_extend(mappings, _G.other_mappings or {})
      return { mappings = mappings }
    end,
  },
}
