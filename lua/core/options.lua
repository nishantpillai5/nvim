-- Only non-defaults belong here. Verified against `nvim --clean` on 0.12, so
-- incsearch / autoread / showcmd / autochdir are absent: they
-- already hold these values. termguicolors is absent too -- Neovim detects
-- terminal truecolor support itself, and forcing it breaks terminals that lack it.
local env = require 'util.env'

-- Line wrap
vim.o.wrap = false

-- Line numbers
vim.o.number = true
vim.o.relativenumber = true
vim.o.signcolumn = 'auto:1-4'

-- Indent
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true
vim.o.smartindent = true

-- Also accept classic mac line endings
vim.o.fileformats = 'unix,dos,mac'

-- Show whitespace
vim.o.list = true
vim.opt.listchars:append 'space:⋅'

-- Undo / backups live under this config's own state dir, so each NVIM_APPNAME
-- stays isolated. Neovim creates the directories on demand.
vim.o.undofile = true
vim.o.undodir = vim.fs.joinpath(vim.fn.stdpath 'state', 'undo')
vim.o.backupdir = vim.fs.joinpath(vim.fn.stdpath 'state', 'backup')

-- Search
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.inccommand = 'split'

-- Scrolling
vim.o.scrolloff = 8

-- Completion. `fuzzy` and `popup` are 0.11+; together with vim.lsp.completion
-- (see core/lsp.lua) they cover what nvim-cmp used to do.
vim.o.completeopt = 'menu,menuone,noselect,fuzzy,popup'
vim.o.pumheight = 12

-- 0.12: one global border for every floating window -- hover, signature help,
-- diagnostics floats -- instead of configuring each producer separately.
vim.o.winborder = 'rounded'

-- Splits
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.splitkeep = 'screen'

-- Force show tabline
vim.o.showtabline = 2

-- One statusline for the whole editor, matching lualine's globalstatus. This
-- has to be set here, at startup, not left to lualine's own opts: dashboard-nvim
-- snapshots laststatus when it opens at VimEnter and restores that snapshot when
-- you leave it, which lands after lualine loads on VeryLazy and would put the
-- old value back. Without this, every window -- including telescope's floats --
-- draws its own statusline.
vim.o.laststatus = 3

-- How long a pending mapping waits. which-key shows its menu after this.
vim.o.timeoutlen = 300

-- Last command in the statusline rather than the command line
vim.o.showcmdloc = 'last'

vim.g.have_nerd_font = true
vim.g.python3_host_prog = env.NVIM_PYTHON
