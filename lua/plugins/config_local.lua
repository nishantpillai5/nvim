-- Project-local config, loaded early so the `_G.*` hooks other plugins read are
-- in place before those plugins configure themselves.
return {
  {
    'klen/nvim-config-local',
    lazy = false,
    priority = 999,
    main = 'config-local',
    opts = {
      config_files = { '.vscode/.nvim.lua', '.nvim.lua', '.nvimrc', '.exrc' },
      silent = true,
    },
  },
}
