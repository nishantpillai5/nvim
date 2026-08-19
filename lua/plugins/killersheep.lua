-- GOTY.
return {
  {
    'seandewar/killersheep.nvim',
    cmd = 'KillKillKill',
    keys = {
      { '<leader>zOs', '<cmd>KillKillKill<cr>', desc = 'sheep_game' },
    },
    opts = {
      gore = true,
      keymaps = {
        move_left = 'j',
        move_right = 'k',
        shoot = '<Space>',
      },
    },
  },
}
