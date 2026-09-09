-- Replaces nvim-spectre; same three keys the old config bound. `maplocalleader`
-- is space here, so grug-far's buffer-local keymaps (`<localleader>r` replace,
-- `q` qflist, `c` close) shadow the global `<leader>` groups inside its buffer.
return {
  {
    'MagicDuck/grug-far.nvim',
    cmd = { 'GrugFar', 'GrugFarWithin' },
    keys = {
      {
        '<leader>r/',
        function()
          require('grug-far').open { prefills = { paths = vim.fn.expand '%' } }
        end,
        desc = 'replace_in_file',
      },
      {
        '<leader>r/',
        function()
          require('grug-far').with_visual_selection { prefills = { paths = vim.fn.expand '%' } }
        end,
        mode = 'x',
        desc = 'replace_in_file',
      },
      {
        -- One reused buffer, closest to spectre's single toggled panel.
        '<leader>r?',
        function()
          require('grug-far').toggle_instance { instanceName = 'replace', staticTitle = 'Find and Replace' }
        end,
        desc = 'replace_toggle',
      },
      {
        '<leader>rw',
        function()
          require('grug-far').open { prefills = { search = vim.fn.expand '<cword>' } }
        end,
        desc = 'replace_word',
      },
      {
        '<leader>rw',
        function()
          require('grug-far').with_visual_selection()
        end,
        mode = 'x',
        desc = 'replace_selection',
      },
    },
    opts = {},
  },
}
