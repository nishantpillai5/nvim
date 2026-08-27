-- The plugin list. Each entry is the plugin's lazy.nvim spec name -- the exact
-- string in lua/plugins/<file>.lua -- so the two can never drift apart.
--
-- Comment a line out to disable that plugin: its spec is dropped, and its
-- keymaps, commands and config go with it. Nothing else needs editing. A name
-- here that matches no spec is reported at startup, so a typo fails loudly
-- rather than silently disabling the plugin.
--
-- One caveat: a plugin that another spec lists in `dependencies` still gets
-- installed when you disable it here -- lazy pulls it in to satisfy the
-- dependency, just without the config in its file. Disabling
-- nvim-telescope/telescope.nvim while any telescope-* entry is live is the case
-- to watch.

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
  'norcalli/nvim-colorizer.lua',
  'folke/zen-mode.nvim',
  'alexghergh/nvim-tmux-navigation',

  -- Files and navigation ------------------------------------------------------
  'stevearc/oil.nvim',
  'cbochs/grapple.nvim',
  'rgroli/other.nvim',

  -- Finder --------------------------------------------------------------------
  'nvim-telescope/telescope.nvim',
  'OliverChao/telescope-picker-list.nvim',
  'jemag/telescope-diff.nvim',
  'nishantpillai5/telescope-git-hunk',

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
  'backdround/global-note.nvim',
  'mattn/calendar-vim',

  -- AI ------------------------------------------------------------------------
  'ggml-org/llama.vim',
  'coder/claudecode.nvim',
  -- 'olimorris/codecompanion.nvim',
  'rauls-kjarners/omp.nvim',

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

  -- Fun and diagnostics ---------------------------------------------------------
  'epwalsh/pomo.nvim',
  'NStefan002/screenkey.nvim',
  'aikhe/wrapped.nvim',
  'kwakzalver/duckytype.nvim',
  'eandrju/cellular-automaton.nvim',
  'seandewar/killersheep.nvim',
}
