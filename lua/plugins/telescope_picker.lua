return {
  {
    'OliverChao/telescope-picker-list.nvim',
    dependencies = {
      'nvim-telescope/telescope.nvim',
      'Snikimonkd/telescope-git-conflicts.nvim',
      'xiyaowong/telescope-emoji.nvim',
      '2KAbhishek/nerdy.nvim',
      'jemag/telescope-diff.nvim',
      'nishantpillai5/telescope-color-names.nvim',
    },
    keys = {
      {
        '<leader>Fe',
        function()
          local telescope = require 'telescope'
          -- Load whatever is actually installed, then the aggregator. The old
          -- config repeated this pcall block thirteen times, including for
          -- plugins this config doesn't have (dap, project, git_worktree, rest,
          -- yank_history, chezmoi).
          for module, extension in pairs {
            ['telescope._extensions.emoji'] = 'emoji',
            ['telescope._extensions.diff'] = 'diff',
            ['telescope._extensions.conflicts'] = 'conflicts',
            ['nerdy'] = 'nerdy',
            ['telescope._extensions.color_names'] = 'color_names',
            ['telescope._extensions.project'] = 'project',
            ['yanky'] = 'yank_history',
            ['notify'] = 'notify',
            ['noice'] = 'noice',
          } do
            if pcall(require, module) then
              pcall(telescope.load_extension, extension)
            end
          end
          telescope.load_extension 'picker_list'
          telescope.extensions.picker_list.picker_list()
        end,
        desc = 'extensions',
      },
    },
  },
}
