-- Live-coding music: drives a browser Strudel session from a .str buffer. The
-- plugin ships a node project (hence `build`), so node and npm must be on PATH.
--
-- The buffer keys hook the path patterns, not the filetype -- .str and .std are
-- javascript (core/filetypes.lua), and these do not belong in every js buffer.
local STR_FILES = { '*.str', '*.std' }

local BUFFER_KEYS = {
  { '<leader>;q', 'quit', 'quit' },
  { '<leader>;x', 'toggle', 'toggle' },
  { '<leader><leader>', 'update', 'update' },
  { '<leader>;X', 'stop', 'stop' },
  { '<leader>;s', 'set_buffer', 'buffer' },
  { '<leader>;S', 'execute', 'buffer_and_update' },
}

local function set_buffer_keys(bufnr)
  for _, spec in ipairs(BUFFER_KEYS) do
    local lhs, fn, desc = spec[1], spec[2], spec[3]
    vim.keymap.set('n', lhs, function()
      require('strudel')[fn]()
    end, { buffer = bufnr, silent = true, desc = desc })
  end
end

return {
  {
    'gruvw/strudel.nvim',
    build = 'npm install',
    event = { { event = { 'BufRead', 'BufNewFile' }, pattern = STR_FILES } },
    -- All seven, so any of them loads the plugin rather than only the launch.
    cmd = {
      'StrudelLaunch',
      'StrudelQuit',
      'StrudelToggle',
      'StrudelUpdate',
      'StrudelStop',
      'StrudelSetBuffer',
      'StrudelExecute',
    },
    keys = {
      {
        '<leader>zm',
        function()
          require('strudel').launch()
        end,
        desc = 'launch',
      },
    },
    config = function()
      require('strudel').setup {
        start_on_launch = false,
        sync_cursor = false,
        -- ui = { hide_menu_panel = true, hide_top_bar = true, hide_error_display = true },
      }

      vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
        group = vim.api.nvim_create_augroup('strudel_buffer_keys', { clear = true }),
        pattern = STR_FILES,
        desc = 'strudel buffer-local keys',
        callback = function(args)
          set_buffer_keys(args.buf)
        end,
      })

      -- The buffer that opened Strudel is already read; the autocmd missed it.
      local ext = vim.fn.expand '%:e'
      if ext == 'str' or ext == 'std' then
        set_buffer_keys(0)
      end
    end,
  },
}
