return {
  {
    'stevearc/aerial.nvim',
    -- So `nerd_font = 'auto'` finds devicons; the treesitter backend needs
    -- only parsers, not the nvim-treesitter module.
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    cmd = { 'AerialToggle', 'AerialNavToggle', 'AerialInfo' },
    keys = {
      -- aerial reads `focus = not params.bang`, so the plain command focuses.
      { '<leader>es', '<cmd>AerialToggle<cr>', desc = 'symbols' },
      { '<leader>eS', '<cmd>AerialNavToggle<cr>', desc = 'symbols_nav' },
    },
    opts = {
      -- The default gives every window its own, and edgy docks one sidebar.
      attach_mode = 'global',
      show_guides = true,
      keymaps = {
        -- Freed for tmux-style window navigation, as in overseer.lua: aerial's
        -- buffer-local <C-j>/<C-k> beat the global maps inside the pane.
        ['<C-h>'] = false,
        ['<C-j>'] = false,
        ['<C-k>'] = false,
        ['<C-l>'] = false,
        ['J'] = 'actions.down_and_scroll',
        ['K'] = 'actions.up_and_scroll',
        ['s'] = 'actions.jump_split',
        ['v'] = 'actions.jump_vsplit',
      },
    },
  },
}
