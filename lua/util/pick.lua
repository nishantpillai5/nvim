local M = {}

-- Pick a branch with telescope, then act on its name. Shared by the telescope
-- and diffview keymaps, which both need it.
function M.branch(fn)
  require('telescope.builtin').git_branches {
    attach_mappings = function(_, map)
      local select = function(prompt_bufnr)
        local entry = require('telescope.actions.state').get_selected_entry()
        require('telescope.actions').close(prompt_bufnr)
        if entry then
          fn(entry.name)
        end
      end
      map('i', '<CR>', select)
      map('n', '<CR>', select)
      return true
    end,
  }
end

return M
