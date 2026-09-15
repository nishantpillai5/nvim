-- AI ghost-text completion against llama-server (~/.models/coder.sh, port 8012).
-- The FIM provider posts prefix+suffix, so no chat scaffolding applies.
return {
  {
    'milanglacier/minuet-ai.nvim',
    event = { 'InsertEnter', 'BufReadPost' },
    config = function(_, opts)
      require('minuet').setup(opts)
    end,
    -- Dim grey ghost text, kept stable across colorscheme changes.
    init = function()
      local function set_hl()
        vim.api.nvim_set_hl(0, 'MinuetVirtualText', { fg = '#5f5f5f', italic = true })
      end
      set_hl()
      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('minuet_hl', { clear = true }),
        callback = set_hl,
      })
    end,
    opts = {
      provider = 'openai_fim_compatible',
      frontend = 'virtualtext',
      request_timeout = 15, -- curl --max-time, so it has to cover a cold model load
      -- The main latency lever: ~1 ms of prefill per prompt token, measured.
      context_window = 1500,
      -- Parallel requests per keystroke for FIM, not alternatives in one prompt.
      n_completions = 1,
      throttle = 750,
      debounce = 250,
      virtualtext = {
        -- Empty list disables auto-trigger; '*' = all filetypes.
        auto_trigger_ft = { '*' },
        keymap = {
          accept = '<Tab>',
          accept_line = '<S-Tab>',
          prev = '<A-[>',
          next = '<A-]>',
          dismiss = '<A-e>',
        },
      },
      provider_options = {
        openai_fim_compatible = {
          -- Env-var name (minuet looks it up); TERM always exists, no auth needed.
          api_key = 'TERM',
          end_point = 'http://127.0.0.1:8012/v1/completions',
          -- Empty so the statusline shows nothing until the server names the model
          -- (lualine.lua). llama-server ignores it; vLLM needs its served name.
          model = '',
          name = 'llama.cpp',
          optional = {
            max_tokens = 64, -- hard ceiling; `stop` should end it well before this
            -- Without these an instruct model writes whole functions past the
            -- cursor, emitting the FIM markers as text instead of ending the turn.
            stop = {
              '\n\n',
              '<|fim_prefix|>',
              '<|fim_suffix|>',
              '<|fim_middle|>',
              '<|file_sep|>',
              '<|endoftext|>',
            },
          },
        },
      },
    },
  },
}
