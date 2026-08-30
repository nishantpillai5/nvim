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

-- Collect every spec under lua/plugins/, keyed by its lazy.nvim name, then emit
-- only the ones lua/enabled.lua asks for, in the order it lists them. Matching
-- on the spec's own name means the list holds the real plugin strings and cannot
-- drift from the files.
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
  -- A name with no matching spec is almost always a typo. Say so, rather than
  -- silently leaving the plugin out.
  vim.schedule(function()
    vim.notify('enabled.lua: no plugin spec matches ' .. table.concat(missing, ', '), vim.log.levels.WARN)
  end)
end

-- Spec first, options second: with a single table lazy still reads it as the
-- options (it checks for a `spec` field), but lua_ls resolves that call against
-- LazySpec, where `dev` is the per-plugin boolean rather than this table.
require('lazy').setup(spec, {
  -- Plugins checked out locally are picked up from here via `dev = true`.
  dev = { path = require('util.env').NVIM_PLUGINS },
  change_detection = { notify = false },
  -- luarocks integration is off; nothing here needs it, and leaving it on warns
  -- on every start when luarocks isn't installed.
  rocks = { enabled = false },
})
