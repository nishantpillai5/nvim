require 'core.options'
require 'core.filetypes'
require 'core.keymaps'
require 'core.autocmds'
require 'core.commands'

-- Plugins load on top of the base config.
require 'core.lazy'

-- After lazy: vim.lsp.enable reads lsp/*.lua eagerly, and those files may
-- require plugin modules.
require 'core.lsp'
