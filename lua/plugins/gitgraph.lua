return {
  {
    'isakbm/gitgraph.nvim',
    dependencies = { 'sindrets/diffview.nvim' },
    keys = {
      {
        '<leader>gg',
        function()
          vim.cmd 'vsplit'
          require('gitgraph').draw({}, { all = false, max_count = 5000 })
        end,
        desc = 'graph',
      },
      {
        '<leader>gG',
        function()
          vim.cmd 'vsplit'
          require('gitgraph').draw({}, { all = true, max_count = 5000 })
        end,
        desc = 'graph_all',
      },
    },
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      ---@diagnostic disable-next-line: missing-fields
      symbols = { merge_commit = '', commit = '' },
      format = {
        timestamp = '%H:%M:%S %d-%m-%Y',
        fields = { 'hash', 'timestamp', 'author', 'branch_name', 'tag' },
      },
      hooks = {
        on_select_commit = function(commit)
          vim.notify('Changes from ' .. commit.msg)
          vim.cmd(':DiffviewOpen ' .. commit.hash .. '^!')
        end,
        on_select_range_commit = function(from, to)
          vim.notify('Changes from ' .. from.msg .. ' to ' .. to.msg)
          vim.cmd(':DiffviewOpen ' .. from.hash .. '~1..' .. to.hash)
        end,
      },
    },
  },
}
