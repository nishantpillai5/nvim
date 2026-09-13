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
      -- noice ships its own telescope extension, so load it here rather than
      -- in telescope's config, which can run before noice exists.
      {
        '<leader>fz',
        function()
          local telescope = require 'telescope'
          telescope.load_extension 'noice'
          telescope.extensions.noice.noice()
        end,
        desc = 'notifications',
      },
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
