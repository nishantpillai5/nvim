local lazypath = vim.fs.joinpath(vim.fn.stdpath 'data', 'lazy', 'lazy.nvim')

if not vim.uv.fs_stat(lazypath) then
  -- Synchronous on purpose: rtp must be ready before the first require.
  local res = vim
    .system({
      'git',
      'clone',
      '--filter=blob:none',
      '--branch=stable',
      'https://github.com/folke/lazy.nvim.git',
      lazypath,
    }, { text = true })
    :wait()

  if res.code ~= 0 then
    vim.api.nvim_echo({
      { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' },
      { res.stderr or '', 'WarningMsg' },
      { '\nPress any key to exit...' },
    }, true, {})
    -- Only wait for a keypress when there's a UI to read one from; in headless
    -- Neovim getchar() would block forever instead of exiting.
    if #vim.api.nvim_list_uis() > 0 then
      vim.fn.getchar()
    end
    os.exit(1)
  end
end

vim.opt.rtp:prepend(lazypath)

-- Every spec under lua/plugins/, filtered and ordered by lua/enabled.lua.
-- Keying on the spec's own name is what keeps that list from drifting.
local plugins_dir = vim.fs.joinpath(vim.fn.stdpath 'config', 'lua', 'plugins')

local by_name = {}
for entry, entry_type in vim.fs.dir(plugins_dir) do
  local module = entry_type == 'file' and entry:match '^(.+)%.lua$'
  if module then
    for _, plugin in ipairs(require('plugins.' .. module)) do
      by_name[plugin[1]] = plugin
    end
  end
end

local spec, missing = {}, {}
for _, name in ipairs(require 'enabled') do
  if by_name[name] then
    table.insert(spec, by_name[name])
  else
    table.insert(missing, name)
  end
end

if #missing > 0 then
  -- Almost always a typo, so say so rather than silently dropping the plugin.
  vim.schedule(function()
    vim.notify('enabled.lua: no plugin spec matches ' .. table.concat(missing, ', '), vim.log.levels.WARN)
  end)
end

-- Spec first, options second: lazy reads a single table either way, but lua_ls
-- resolves that call against LazySpec, where `dev` is a per-plugin boolean.
require('lazy').setup(spec, {
  -- Plugins checked out locally are picked up from here via `dev = true`.
  dev = { path = require('util.env').NVIM_PLUGINS },
  change_detection = { notify = false },
  -- Nothing here needs luarocks, and leaving it on warns on every start.
  rocks = { enabled = false },
})
