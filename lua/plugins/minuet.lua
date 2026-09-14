-- AI ghost-text completion against the local Magnitude model (OpenAI-compatible
-- endpoint of the magnitude-service, no separate process).
return {
  {
    'milanglacier/minuet-ai.nvim',
    event = { 'InsertEnter', 'BufReadPost' },
    config = true,
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
      provider = 'openai_compatible',
      frontend = 'virtualtext',
      request_timeout = 15, -- 27B model over local inference; be patient
      -- Latency tuning (model does ~800 prompt-tok/s, so context size is the
      -- main cost): default 16000 chars (~4k tokens) = ~5s before first token.
      context_window = 4000, -- ~1k tokens of surrounding code; TTFT stays <0.5s
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
        openai_compatible = {
          -- Env-var name (minuet looks it up); TERM always exists, no auth needed.
          api_key = 'TERM',
          end_point = 'http://127.0.0.1:10100/inference/v1/chat/completions',
          model = 'qwen3.8-27b:gguf:q4',
          name = 'Magnitude',
          optional = {
            max_tokens = 64, -- ghost text is short; cap generation time
            -- Skip the reasoning phase; otherwise every completion waits on
            -- a wall of reasoning_content before the first real token.
            reasoning_effort = 'none',
          },
        },
      },
    },
  },
}
