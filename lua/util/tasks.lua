-- Helpers shared by the overseer spec and the lualine task indicator.
-- Each `_G.*` hook lets a project-local exrc file override the default.
local M = {}

function M.get_cmd(task)
  if type(task.cmd) == 'string' then
    return task.cmd
  end
  return table.concat(task.cmd, ' ')
end

function M.filter_build_tasks(task)
  if _G.filter_build_tasks ~= nil then
    return _G.filter_build_tasks(task)
  end
  return M.get_cmd(task):lower():find 'build' ~= nil
end

function M.filter_run_tasks(task)
  if _G.filter_run_tasks ~= nil then
    return _G.filter_run_tasks(task)
  end
  return M.get_cmd(task):lower():find 'run' ~= nil
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
