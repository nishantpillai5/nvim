return {
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    dependencies = { 'MunifTanjim/nui.nvim', 'rcarriga/nvim-notify' },
    keys = {
      {
        '<leader>zn',
        function()
          require('noice').cmd 'disable'
        end,
        desc = 'noice_disable',
      },
      -- Was `Telescope notify`; noice keeps its own history.
      { '<leader>fz', '<cmd>Noice history<cr>', desc = 'notifications' },
    },
    opts = {
      lsp = {
        override = {
          ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
          ['vim.lsp.util.stylize_markdown'] = true,
          -- The nvim-cmp override from the old config is gone with nvim-cmp.
        },
      },
      presets = {
        bottom_search = false,
        command_palette = false,
        long_message_to_split = true,
        lsp_doc_border = true,
      },
      views = {
        cmdline_popup = {
          border = { style = 'single', padding = { 0, 1 } },
          filter_options = {},
          win_options = { winhighlight = 'NormalFloat:NormalFloat' },
        },
      },
      -- Hand the completion menu back to Neovim. noice renders it itself when
      -- this is on (it takes ext_popupmenu over vim.ui_attach), and it anchors
      -- the insert-mode menu at a hardcoded `row = 1 + offset` from the cursor
      -- with `offset` already at its maximum -- which lands its top row on the
      -- Claude prompt box and hides the line you are typing. Neovim's own menu
      -- clears the box's border at every terminal height, and takes its height
      -- from 'pumheight' -- which the box lowers while it is open, since Neovim
      -- reads that option to decide whether the menu fits below the cursor.
      -- Trade-off: cmdline completion is drawn natively too, rather than in
      -- noice's styled menu.
      popupmenu = { enabled = false },
      routes = {
        -- "written" after every save is noise.
        {
          filter = { event = 'msg_show', kind = '', find = 'written' },
          opts = { skip = true },
        },
      },
    },
  },
}
