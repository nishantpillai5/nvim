return {
  {
    'stevearc/aerial.nvim',
    -- Listed so `nerd_font = 'auto'` finds devicons on the runtimepath; the
    -- treesitter backend needs only parsers, not the nvim-treesitter module.
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    cmd = { 'AerialToggle', 'AerialNavToggle', 'AerialInfo' },
    keys = {
      -- No bang: aerial reads `focus = not params.bang`, so the plain command
      -- is the one that focuses the pane.
      { '<leader>es', '<cmd>AerialToggle<cr>', desc = 'symbols' },
      { '<leader>eS', '<cmd>AerialNavToggle<cr>', desc = 'symbols_nav' },
    },
    opts = {
      -- One pane tracking the current buffer. The default gives every window
      -- its own, and edgy docks a single sidebar.
      attach_mode = 'global',
      show_guides = true,
      keymaps = {
        -- Freed up for tmux-style window navigation, as in overseer.lua: aerial
        -- binds <C-j>/<C-k> buffer-locally to its scroll actions, which beat
        -- the global maps inside the pane. They move to J/K, and the split
        -- jumps join the s/v the task list and the tree already use.
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
