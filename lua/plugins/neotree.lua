-- Windows a file opened from the tree should not replace. aerial is the
-- addition: it docks beside the tree, so it was in the way of every open.
local KEEP_OPEN = { 'terminal', 'Trouble', 'qf', 'edgy', 'aerial' }

return {
  {
    'nvim-neo-tree/neo-tree.nvim',
    -- v3.x is upstream's stable line; `main` is where contributors work.
    branch = 'v3.x',
    dependencies = { 'nvim-lua/plenary.nvim', 'MunifTanjim/nui.nvim', 'nvim-tree/nvim-web-devicons' },
    cmd = 'Neotree',
    keys = {
      { '<leader>ee', '<cmd>Neotree reveal focus<cr>', desc = 'explorer' },
      {
        '<leader>eE',
        function()
          vim.cmd('Neotree reveal focus dir=' .. vim.fn.fnameescape(vim.uv.cwd()))
        end,
        desc = 'explorer_cwd',
      },
      { '<leader>eb', '<cmd>Neotree reveal focus buffers<cr>', desc = 'buffers' },
      { '<leader>eg', '<cmd>Neotree reveal focus git_status<cr>', desc = 'git' },
    },
    opts = {
      open_files_do_not_replace_types = KEEP_OPEN,
      -- The root stays where the tree was opened; <leader>eE re-roots it at cwd,
      -- which is what makes that key worth having next to <leader>ew.
      bind_to_cwd = false,
      close_if_last_window = true,
      filesystem = {
        follow_current_file = { enabled = true },
        -- netrw keeps <leader>eF.
        hijack_netrw_behavior = 'disabled',
      },
      git_status = {
        window = {
          mappings = {
            ['s'] = 'git_add_file',
            ['u'] = 'git_unstage_file',
            ['c'] = 'git_commit',
          },
        },
      },
      window = {
        mappings = {
          ['o'] = 'system_open',
          ['s'] = 'open_split',
          ['v'] = 'open_vsplit',
          ['O'] = { 'show_help', nowait = false, config = { title = 'Order by', prefix_key = 'o' } },
          ['Oc'] = { 'order_by_created', nowait = false },
          ['Od'] = { 'order_by_diagnostics', nowait = false },
          ['Og'] = { 'order_by_git_status', nowait = false },
          ['Om'] = { 'order_by_modified', nowait = false },
          ['On'] = { 'order_by_name', nowait = false },
          ['Os'] = { 'order_by_size', nowait = false },
          ['Ot'] = { 'order_by_type', nowait = false },
        },
      },
      commands = {
        -- vim.ui.open picks the platform's opener, as <leader>eO does.
        system_open = function(state)
          local path = state.tree:get_node():get_id()
          if (vim.uv.fs_stat(path) or {}).type == 'file' then
            path = vim.fs.dirname(path)
          end
          vim.ui.open(path)
        end,
      },
    },
  },
}
