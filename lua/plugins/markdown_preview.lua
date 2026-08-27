return {
  {
    'iamcco/markdown-preview.nvim',
    ft = 'markdown',
    cmd = {
      'MarkdownPreview',
      'MarkdownPreviewStop',
      'MarkdownPreviewToggle',
      'MarkdownPreviewToggleTheme',
    },
    build = function()
      vim.fn['mkdp#util#install_sync'](true)
    end,
    keys = {
      { '<leader>zP', '<cmd>MarkdownPreviewToggle<cr>', ft = 'markdown', desc = 'markdown_preview' },
    },
    init = function()
      vim.g.mkdp_theme = 'dark'
    end,
    config = function()
      vim.api.nvim_create_user_command('MarkdownPreviewToggleTheme', function()
        vim.g.mkdp_theme = vim.g.mkdp_theme == 'dark' and 'light' or 'dark'
        -- The page reads the theme as it opens, so re-open rather than toggle.
        vim.cmd 'MarkdownPreview'
      end, { desc = 'Switch the markdown preview page between dark and light' })
    end,
  },
}
