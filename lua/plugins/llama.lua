-- Fill-in-the-middle completion against a local llama.cpp server.
return {
  {
    'ggml-org/llama.vim',
    event = 'VeryLazy',
    init = function()
      vim.g.llama_config = {
        show_info = false,
        keymap_fim_accept_line = '<Tab>',
        keymap_fim_accept_full = '<S-Tab>',
        -- Disable llama's <leader>ll* maps so <leader>ll stays free (reload_file).
        keymap_fim_trigger = '',
        keymap_fim_accept_word = '',
        keymap_inst_trigger = '',
        keymap_inst_rerun = '',
        keymap_inst_continue = '',
        keymap_debug_toggle = '',
      }
    end,
    config = function()
      -- Grey out the FIM ghost text, and keep it grey across colorscheme changes.
      local function set_hl()
        vim.api.nvim_set_hl(0, 'llama_hl_fim_hint', { fg = '#808080', italic = true })
      end
      set_hl()
      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('llama_hl', { clear = true }),
        callback = set_hl,
      })
    end,
  },
}
