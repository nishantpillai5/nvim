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
-- stays isolated. Neovim creates 'undodir' on demand but NOT 'backupdir' -- with
-- that directory missing a write just skips its backup silently -- so make it.
vim.o.undofile = true
vim.o.undodir = vim.fs.joinpath(vim.fn.stdpath 'state', 'undo')
vim.o.backupdir = vim.fs.joinpath(vim.fn.stdpath 'state', 'backup')
vim.fn.mkdir(vim.o.backupdir, 'p')

-- Search
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.inccommand = 'split'

-- Scrolling
vim.o.scrolloff = 8

-- Completion
vim.o.completeopt = 'menu,menuone,noselect,fuzzy,popup'
vim.o.pumheight = 12

-- Global border for every floating window
vim.o.winborder = 'rounded'

-- Splits
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.splitkeep = 'screen'

-- Force show tabline
vim.o.showtabline = 2

-- One statusline for the whole editor, matching lualine's globalstatus.
vim.o.laststatus = 3

-- How long a pending mapping waits. which-key shows its menu after this.
vim.o.timeoutlen = 300

-- Last command in the statusline rather than the command line
vim.o.showcmdloc = 'last'

vim.g.have_nerd_font = true
vim.g.python3_host_prog = env.NVIM_PYTHON

-- In the container (docker-compose.yml sets NVIM_CONTAINER) there is no display
-- server, so xclip and wl-clipboard would have nothing to talk to and the `"+`
-- maps in core/keymaps.lua would be inert. OSC 52 sends the yank to the host's
-- terminal instead. Copy is widely supported; paste needs the terminal to answer
-- the query, which many do not, so `<leader>p` may still come up empty.
if vim.env.NVIM_CONTAINER then
  vim.g.clipboard = 'osc52'
end
