-- Each entry is the exact lazy.nvim spec name in lua/plugins/<file>.lua, so the
-- two cannot drift; a name matching no spec is reported at startup. Comment a
-- line out to drop that plugin's spec, keymaps, commands and config.
--
-- Caveat: something another spec lists in `dependencies` is still installed when
-- disabled here, just without the config in its file.

return {
  -- Theme ---------------------------------------------------------------------
  'Mofiqul/vscode.nvim',

  -- LSP, completion, formatting, linting --------------------------------------
  'nvim-treesitter/nvim-treesitter',
  'nvim-treesitter/nvim-treesitter-context',
  'code-biscuits/nvim-biscuits',
  'mason-org/mason.nvim',
  'folke/lazydev.nvim',
  'b0o/schemastore.nvim',
  'stevearc/conform.nvim',
  'mfussenegger/nvim-lint',
  'chrisgrieser/nvim-rulebook',
  'folke/trouble.nvim',

  -- UI ------------------------------------------------------------------------
  'nvim-tree/nvim-web-devicons',
  'nvim-lualine/lualine.nvim',
  'nvimdev/dashboard-nvim',
  'folke/which-key.nvim',
  'folke/noice.nvim',
  'rcarriga/nvim-notify',
  'folke/snacks.nvim',
  'folke/edgy.nvim',
  'utilyre/barbecue.nvim',
  'petertriho/nvim-scrollbar',
  'kevinhwang91/nvim-hlslens',
  'nvim-zh/colorful-winsep.nvim',
  'lukas-reineke/indent-blankline.nvim',

  -- Editing -------------------------------------------------------------------
  'chrisgrieser/nvim-spider',
  'smoka7/hop.nvim',
  'mawkler/demicolon.nvim',
  'LeonHeidelbach/trailblazer.nvim',
  'monaqa/dial.nvim',
  'windwp/nvim-autopairs',
  'gbprod/yanky.nvim',
  'mbbill/undotree',
  'Wansmer/treesj',
  'echasnovski/mini.surround',
  'nishantpillai5/todo-comments.nvim',
  'andrewferrier/debugprint.nvim',
  'kevinhwang91/nvim-ufo',
  'RRethy/vim-illuminate',
  'catgoose/nvim-colorizer.lua',
  'folke/zen-mode.nvim',
  'alexghergh/nvim-tmux-navigation',
  'MagicDuck/grug-far.nvim',

  -- Files and navigation ------------------------------------------------------
  'nvim-neo-tree/neo-tree.nvim',
  'stevearc/oil.nvim',
  'cbochs/grapple.nvim',
  'rgroli/other.nvim',
  'stevearc/aerial.nvim',

  -- Finder --------------------------------------------------------------------
  'nvim-telescope/telescope.nvim',
  'OliverChao/telescope-picker-list.nvim',
  'jemag/telescope-diff.nvim',
  'nishantpillai5/telescope-git-hunk',

  -- Debugging and testing -----------------------------------------------------
  'mfussenegger/nvim-dap',
  'rcarriga/nvim-dap-ui',
  'nvim-telescope/telescope-dap.nvim',
  'Weissle/persistent-breakpoints.nvim',
  -- 'mfussenegger/nvim-dap-python',
  'nvim-neotest/neotest',

  -- Terminal and tasks --------------------------------------------------------
  'akinsho/nvim-toggleterm.lua',
  'nishantpillai5/toggleterm-manager.nvim',
  'stevearc/overseer.nvim',
  'andythigpen/nvim-coverage',

  -- Workspaces ----------------------------------------------------------------
  'klen/nvim-config-local',
  'smartpde/neoscopes',
  'stevearc/resession.nvim',
  'nvim-telescope/telescope-project.nvim',
  'aymericbeaumet/vim-symlink',

  -- Notes ---------------------------------------------------------------------
  'obsidian-nvim/obsidian.nvim',
  'iamcco/markdown-preview.nvim',
  'MeanderingProgrammer/render-markdown.nvim',
  'backdround/global-note.nvim',
  'mattn/calendar-vim',
  'nfrid/due.nvim',
  'Avi-D-coder/whisper.nvim',

  -- AI ------------------------------------------------------------------------
  -- 'ggml-org/llama.vim', -- replaced by minuet-ai.nvim (needs llama.cpp, which we don't run)
  'milanglacier/minuet-ai.nvim',
  'coder/claudecode.nvim',
  -- 'olimorris/codecompanion.nvim',
  -- 'rauls-kjarners/omp.nvim',

  -- Git -----------------------------------------------------------------------
  'tpope/vim-fugitive',
  'kdheepak/lazygit.nvim',
  'lewis6991/gitsigns.nvim',
  'sindrets/diffview.nvim',
  'isakbm/gitgraph.nvim',
  'nishantpillai5/git-blame.nvim',
  'linrongbin16/gitlinker.nvim',
  'akinsho/git-conflict.nvim',
  'polarmutex/git-worktree.nvim',
  'purarue/gitsigns-yadm.nvim',

  -- Fun and diagnostics ---------------------------------------------------------
  'epwalsh/pomo.nvim',
  'NStefan002/screenkey.nvim',
  'aikhe/wrapped.nvim',
  'kwakzalver/duckytype.nvim',
  'gruvw/strudel.nvim',
  'eandrju/cellular-automaton.nvim',
  'seandewar/killersheep.nvim',
}
