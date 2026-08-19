-- Shortcut actions must resolve when pressed, so each points at something this
-- config actually has.
return {
  {
    'nvimdev/dashboard-nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      theme = 'hyper',
      change_to_vcs_root = false,
      shortcuts_left_side = false,
      shortcut_type = 'number',
      config = {
        header = require('util.ascii').logo(),
        week_header = { enable = false },
        packages = { enable = true },
        project = { enable = false, limit = 1 },
        mru = { cwd_only = true, limit = 5 },
        shortcut = {
          { desc = ' Files', group = 'Label', action = 'Telescope find_files', key = 'f' },
          -- Was `Neotree reveal focus`; this config uses oil.
          { desc = ' Explorer', group = 'Label', action = 'Oil', key = 'e' },
          {
            desc = ' Recent',
            group = 'Label',
            action = 'Telescope oldfiles only_cwd=true',
            key = 'r',
          },
          {
            desc = '󱇳 Scope',
            group = 'Label',
            action = function()
              require('util.scope').select()
            end,
            key = 'w',
          },
          {
            desc = ' Project',
            group = 'Label',
            action = function()
              require('telescope').load_extension 'project'
              require('telescope').extensions.project.project()
            end,
            key = 'W',
          },
          { desc = '󰒲 Lazy', group = '@property', action = 'Lazy', key = 'l' },
          { desc = ' Mason', group = '@property', action = 'Mason', key = 'm' },
          { desc = ' Quit', group = 'Label', action = 'qa', key = 'q' },
        },
        footer = {},
      },
    },
  },
}
