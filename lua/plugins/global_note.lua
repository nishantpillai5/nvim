-- Scratch notes that live in DIR_NOTES rather than the project: one global, one
-- per project, one per git branch. The old config also carried a
-- `git_project_name` helper that nothing called; it is not here.
local env = require 'util.env'

-- Basename of the cwd, used to name the project- and branch-local notes.
local function project_name()
  local cwd = vim.uv.cwd()
  if not cwd then
    vim.notify('Unable to get the project name', vim.log.levels.WARN)
    return nil
  end
  return vim.fs.basename(cwd)
end

return {
  {
    'backdround/global-note.nvim',
    keys = {
      {
        '<leader>na',
        function()
          require('global-note').toggle_note()
        end,
        desc = 'note_global',
      },
      {
        '<leader>nN',
        function()
          require('global-note').toggle_note 'project_local'
        end,
        desc = 'note_project',
      },
      {
        '<leader>nn',
        function()
          require('global-note').toggle_note 'git_branch_local'
        end,
        desc = 'note_git_branch',
      },
    },
    opts = {
      filename = 'project.md',
      directory = env.DIR_NOTES,
      title = 'GLOBAL NOTE',
      additional_presets = {
        project_local = {
          command_name = 'PROJECT NOTE',
          filename = function()
            local name = project_name()
            return name and 'project.' .. name .. '.md' or nil
          end,
          title = project_name,
        },
        git_branch_local = {
          command_name = 'GIT BRANCH NOTE',
          filename = function()
            local name, branch = project_name(), require('util.git').branch()
            if not name or not branch then
              return nil
            end
            -- Slashes in a branch name would read as directories.
            return 'project.' .. name .. '.' .. branch:gsub('[^%w-]', '-') .. '.md'
          end,
          title = function()
            local name, branch = project_name(), require('util.git').branch()
            if not name then
              return nil
            end
            return branch and name .. ' | ' .. branch or name
          end,
        },
      },
    },
  },
}
