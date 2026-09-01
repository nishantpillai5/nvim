-- Machine- and user-specific values. Every key can be overridden by an
-- environment variable of the same name; `M.defaults` is the fallback, and is
-- what `:checkhealth core` reports against.
local M = {}

local uname = vim.uv.os_uname()
local is_windows = uname.sysname:find 'Windows' ~= nil
local is_mac = uname.sysname == 'Darwin'
local is_wsl = uname.sysname == 'Linux' and uname.release:lower():find 'microsoft' ~= nil

M.OS = (is_windows and 'windows') or (is_mac and 'mac') or (is_wsl and 'wsl') or 'linux'

M.defaults = {
  XDG_CONFIG_HOME = vim.fs.normalize '~/.config',
  -- 'home' | 'work' | 'present'. In the old config this also drove screen and
  -- panel layout; here it only selects the dashboard logo, since those layout
  -- knobs are now local constants in the files that use them.
  NVIM_CONTEXT = 'home',
  DIR_NOTES = vim.fs.normalize '~/notes',
  -- Follows NVIM_APPNAME, so this stays correct for every config variant.
  DIR_NVIM = vim.fn.stdpath 'config',
  NVIM_PLUGINS = vim.fs.normalize '~/.nvim/local_lazy',
  USER_PREFIX = vim.env.USER_PREFIX or vim.env.USERNAME or vim.env.USER or 'user',
  NVIM_PYTHON = vim.fs.normalize(
    is_windows and '~/.virtualenvs/neovim/Scripts/python.exe' or '~/.virtualenvs/neovim/bin/python3'
  ),
}

for key, default in pairs(M.defaults) do
  local value = vim.env[key]
  -- An exported-but-empty variable is not an override: '' is truthy in Lua, so
  -- `export DIR_NOTES=` would otherwise hand obsidian, calendar and global-note
  -- an empty vault path instead of the default.
  M[key] = (value ~= nil and value ~= '') and value or default
end

-- Prefix for the `gco` custom comment, e.g. "NISH: ".
M.TODO_CUSTOM = M.USER_PREFIX:sub(1, 4):upper()

return M
