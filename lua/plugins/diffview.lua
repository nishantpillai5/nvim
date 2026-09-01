local git = require 'util.git'
local pick = require 'util.pick'

-- Close the current diffview instead of opening another one on top.
local function toggle_diffview(open)
  return function()
    if require('diffview.lib').get_current_view() then
      vim.cmd.DiffviewClose()
    else
      open()
    end
  end
end

-- `spec` returns nil when a base ref could not be resolved (util.git's
-- require_* variants have already said why), so there is nothing to open.
local function diffview_open(spec)
  return toggle_diffview(function()
    local args = spec()
    if args then
      vim.cmd('DiffviewOpen ' .. args)
    end
  end)
end

return {
  {
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewFileHistory' },
    keys = {
      { '<leader>gj', toggle_diffview(vim.cmd.DiffviewOpen), desc = 'diff_from_head' },
      {
        '<leader>gk',
        diffview_open(function()
          local base = git.require_fork_point()
          return base and base .. '...HEAD'
        end),
        desc = 'diff_from_fork',
      },
      {
        '<leader>gl',
        diffview_open(function()
          return 'origin/' .. git.main_branch() .. '...HEAD'
        end),
        desc = 'diff_from_main',
      },
      {
        '<leader>g;',
        toggle_diffview(function()
          pick.branch(function(branch)
            vim.cmd('DiffviewOpen origin/' .. branch .. '...HEAD')
          end)
        end),
        desc = 'diff_from_branch',
      },
      {
        '<leader>gH',
        toggle_diffview(function()
          vim.cmd 'DiffviewFileHistory %'
        end),
        desc = 'history',
      },
      {
        '<leader>gfj',
        toggle_diffview(function()
          vim.cmd 'DiffviewOpen -- %'
        end),
        desc = 'file_diff_from_head',
      },
      {
        -- Note: merge_base here, not fork_point -- matching the old config.
        '<leader>gfk',
        diffview_open(function()
          local base = git.require_merge_base()
          return base and base .. '...HEAD -- %'
        end),
        desc = 'file_diff_from_fork',
      },
      {
        '<leader>gfl',
        diffview_open(function()
          return 'origin/' .. git.main_branch() .. '...HEAD -- %'
        end),
        desc = 'file_diff_from_main',
      },
      {
        '<leader>gf;',
        toggle_diffview(function()
          pick.branch(function(branch)
            vim.cmd('DiffviewOpen origin/' .. branch .. '...HEAD -- %')
          end)
        end),
        desc = 'file_diff_from_branch',
      },
      {
        '<leader>gzh',
        toggle_diffview(function()
          vim.cmd 'DiffviewFileHistory % -g --range=stash'
        end),
        desc = 'stash_file_history',
      },
      {
        '<leader>gzH',
        toggle_diffview(function()
          vim.cmd 'DiffviewFileHistory -g --range=stash'
        end),
        desc = 'stash_history',
      },
    },
  },
}
