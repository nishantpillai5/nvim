local M = {}

M.icon = ' '

local function neoscopes()
  local ok, mod = pcall(require, 'neoscopes')
  return ok and mod or nil
end

function M.current()
  local mod = neoscopes()
  if not mod then
    return nil
  end
  local ok, scope = pcall(mod.get_current_scope)
  return (ok and scope) or nil
end

function M.name()
  local scope = M.current()
  return scope and scope.name or nil
end

function M.dirs()
  local mod = neoscopes()
  if not mod or not M.current() then
    return nil
  end
  local ok, dirs = pcall(mod.get_current_dirs)
  return ok and dirs or nil
end

-- A no-op when no scope is selected, so every keymap can route through it.
function M.apply(opts)
  opts = opts or {}
  local dirs = M.dirs()
  if not dirs or vim.tbl_isempty(dirs) then
    return opts
  end
  opts.prompt_prefix = M.icon .. '> '
  opts.search_dirs = dirs
  opts.follow = true
  opts.no_ignore = true
  return opts
end

-- Returns opts, extra rg args and extra search dirs, for live_grep over a list.
function M.constrain(opts)
  -- As in M.apply: the no-scope path returns opts untouched, so a nil here
  -- would only blow up once a scope was active.
  opts = opts or {}
  local scope = M.current()
  if not scope then
    return opts, {}, {}
  end

  local glob_args, search_dirs = {}, {}
  local FILE_URI = '^file:///'

  for _, dir in ipairs(scope.dirs or {}) do
    if dir then
      if dir:find(FILE_URI) then
        table.insert(glob_args, '--glob')
        table.insert(glob_args, (dir:gsub(FILE_URI, '')))
      else
        table.insert(search_dirs, dir)
      end
    end
  end

  for _, file in ipairs(scope.files or {}) do
    if file then
      table.insert(glob_args, '--glob')
      table.insert(glob_args, file)
    end
  end

  opts.prompt_prefix = M.icon .. '> '
  return opts, glob_args, search_dirs
end

-- Empty when no scope is selected: lualine draws an empty component as nothing
-- at all, padding included, so '' hides it rather than leaving a hole.
function M.status()
  local name = M.name()
  return name and (M.icon .. name) or ''
end

function M.select()
  local mod = neoscopes()
  if not mod then
    vim.notify('neoscopes not available', vim.log.levels.WARN)
    return
  end
  if _G.select_workspace ~= nil then
    _G.select_workspace()
  else
    mod.select()
  end
end

function M.clear()
  local mod = neoscopes()
  if mod then
    mod.clear()
  end
end

return M
