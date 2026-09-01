-- Helpers shared by the overseer spec and the lualine task indicator.
-- Each `_G.*` hook lets a project-local exrc file override the default.
local M = {}

function M.get_cmd(task)
  if type(task.cmd) == 'string' then
    return task.cmd
  end
  if type(task.cmd) == 'table' then
    return table.concat(task.cmd, ' ')
  end
  -- Overseer's orchestrator and function strategies build tasks with no cmd at
  -- all, and this feeds the lualine indicator on every statusline refresh -- so
  -- one such task must not turn into a repeating table.concat(nil) error.
  return task.name or ''
end

-- True when a project exrc has actually defined a run/build split. Without one
-- the two filters below match everything, which makes "core" and "other"
-- indistinguishable.
function M.has_filters()
  return _G.filter_build_tasks ~= nil or _G.filter_run_tasks ~= nil
end

function M.filter_build_tasks(task)
  if _G.filter_build_tasks ~= nil then
    return _G.filter_build_tasks(task)
  end
  return true
end

function M.filter_run_tasks(task)
  if _G.filter_run_tasks ~= nil then
    return _G.filter_run_tasks(task)
  end
  return true
end

function M.task_formatter(task)
  if _G.task_formatter ~= nil then
    return _G.task_formatter(task)
  end
  return M.get_cmd(task)
end

local BUILD_CHARS = { '', '' }
local RUN_CHARS = { '󰑮', '󰜎' }

-- Advances a two-frame spinner; returns the frame and the next index.
function M.spinner(index, kind)
  local chars = kind == 'run' and RUN_CHARS or BUILD_CHARS
  local next_index = (index % #chars) + 1
  return chars[next_index], next_index
end

return M
