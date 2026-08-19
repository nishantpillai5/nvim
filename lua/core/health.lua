-- `:checkhealth core` reports which of this config's environment variables are
-- set and which fell back to a default.
local M = {}

M.check = function()
  local env = require 'util.env'

  vim.health.start 'core: environment'
  vim.health.info('OS detected as ' .. env.OS)

  local keys = vim.tbl_keys(env.defaults)
  table.sort(keys)

  for _, key in ipairs(keys) do
    local value = os.getenv(key)
    if value == nil then
      vim.health.warn(key .. ' unset, defaulted to => "' .. tostring(env.defaults[key]) .. '"')
    else
      vim.health.ok(key .. ' => "' .. value .. '"')
    end
  end
end

return M
