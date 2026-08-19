return {
  {
    'olimorris/codecompanion.nvim',
    version = '^19.0.0',
    event = 'VeryLazy',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    keys = {
      { '<leader>cc', '<cmd>CodeCompanionChat<cr>', mode = { 'n', 'v' }, desc = 'chat' },
      { '<leader>cl', '<cmd>CodeCompanion<cr>', mode = { 'n', 'v' }, desc = 'inline_chat' },
      {
        '<leader>c;',
        function()
          local prompt = vim.fn.input 'Enter custom prompt: '
          if prompt ~= '' then
            vim.cmd('CodeCompanionCmd ' .. prompt)
          end
        end,
        mode = { 'n', 'v' },
        desc = 'cmd',
      },
    },
    opts = {
      adapters = {
        http = {
          ['llama-server'] = function()
            return require('codecompanion.adapters').extend('openai_compatible', {
              env = {
                url = 'http://localhost:8012',
                api_key = 'TERM', -- no auth needed; any non-empty string works
                chat_url = '/v1/chat/completions',
              },
              schema = {
                model = {
                  -- Just a label; it needn't match the served model name.
                  default = 'Qwen Coder Next',
                },
              },
            })
          end,
        },
      },
      interactions = {
        chat = { adapter = 'llama-server' },
        inline = { adapter = 'llama-server' },
        cmd = { adapter = 'llama-server' },
      },
    },
  },
}
