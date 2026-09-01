return {
  {
    'cbochs/grapple.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    cmd = 'Grapple',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    keys = {
      { '<leader>ha', '<cmd>Grapple tag<cr>', desc = 'grapple_add' },
      { '<leader>hh', '<cmd>Grapple toggle_tags<cr>', desc = 'grapple_list' },
      { '<A-PageUp>', '<cmd>Grapple cycle_tags prev<cr>', desc = 'grapple_prev' },
      { '<A-PageDown>', '<cmd>Grapple cycle_tags next<cr>', desc = 'grapple_next' },
      {
        '<leader>wh',
        function()
          local scopes = {
            { key = 'git_branch', desc = 'Git root directory and branch' },
            { key = 'git', desc = 'Git root directory' },
            { key = 'cwd', desc = 'Current working directory' },
            { key = 'global', desc = 'Global scope' },
            { key = 'lsp', desc = 'LSP root directory' },
            { key = 'static', desc = 'Initial working directory' },
          }
          vim.ui.select(scopes, {
            prompt = 'Current scope: ' .. require('grapple').app().settings.scope .. ' | Change scope to:',
            format_item = function(item)
              return ('%s: %s'):format(item.key, item.desc)
            end,
          }, function(selected)
            if selected then
              require('grapple').use_scope(selected.key)
            end
          end)
        end,
        desc = 'grapple_select_scope',
      },
    },
    opts = {
      scope = 'git_branch',
      win_opts = { width = 0.8 },
      -- No `integrations` key here: grapple.nvim has no such option and silently
      -- ignored it. Tags persist through grapple's own save_path, not through
      -- resession -- plugins/resession.lua's dependency on grapple is only about
      -- load order.
    },
  },
}
