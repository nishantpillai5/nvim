return {
  {
    'tpope/vim-fugitive',
    cmd = { 'Git', 'G' },
    keys = {
      {
        '<leader>gs',
        function()
          -- Toggle: close an open status window, else open one.
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            if pcall(vim.api.nvim_win_get_var, win, 'fugitive_status') then
              vim.api.nvim_win_close(win, false)
              return
            end
          end
          vim.cmd 'Git'
          vim.cmd 'normal! gg'
        end,
        desc = 'status',
      },
      {
        '<leader>gb',
        function()
          vim.ui.input({ prompt = 'Branch name: ' }, function(input)
            if input and input ~= '' then
              vim.cmd('Git branch ' .. input)
            end
          end)
        end,
        desc = 'branch',
      },
      { '<leader>g"', '<cmd>vertical Git log<cr>', desc = 'log' },
      { '<leader>gza', '<cmd>Git stash apply<cr>', desc = 'apply' },
      { '<leader>gzs', '<cmd>Git stash push --staged<cr>', desc = 'staged' },
      { '<leader>gzp', '<cmd>Git stash pop<cr>', desc = 'pop' },
      {
        '<leader>gzz',
        function()
          vim.ui.input({ prompt = 'Stash message: ' }, function(input)
            if input and input ~= '' then
              vim.cmd('Git stash push -m "' .. input .. '"')
            end
          end)
        end,
        desc = 'stash',
      },
      {
        '<leader>gzZ',
        function()
          vim.ui.input({ prompt = 'Stash message: ' }, function(input)
            if input and input ~= '' then
              vim.cmd('Git stash push --include-untracked -m "' .. input .. '"')
            end
          end)
        end,
        desc = 'stash_untracked',
      },
      {
        '<leader>gr',
        function()
          -- Rebuild the status buffer in place.
          local came_from_elsewhere = vim.bo.filetype ~= 'fugitive'
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.bo[buf].filetype == 'fugitive' then
              vim.api.nvim_buf_delete(buf, { force = true })
              vim.cmd 'Git'
              vim.cmd 'normal! gg'
              if came_from_elsewhere then
                vim.cmd 'wincmd p'
              end
              return
            end
          end
        end,
        desc = 'reload',
      },
    },
    config = function()
      -- Push/pull only inside the status buffer. These shadow the global
      -- <leader>p / <leader>P clipboard maps for that buffer only.
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('fugitive_buffer_keys', { clear = true }),
        pattern = 'fugitive',
        callback = function(args)
          vim.keymap.set('n', '<leader>P', '<cmd>Git push<cr>', { buffer = args.buf, desc = 'push' })
          vim.keymap.set('n', '<leader>p', '<cmd>Git pull --rebase<cr>', { buffer = args.buf, desc = 'pull' })
        end,
      })
    end,
  },
}
