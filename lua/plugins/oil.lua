return {
  {
    'stevearc/oil.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    -- `cmd` matters as much as `keys`: without it :Oil does not exist until the
    -- keymap fires, and the dashboard's Explorer shortcut runs :Oil directly.
    cmd = 'Oil',
    keys = {
      { '<leader>ef', '<cmd>Oil<cr>', desc = 'oil' },
    },
    -- oil's win_options.winbar takes a vimscript expression, so the function it
    -- calls has to be reachable from v:lua -- hence the global.
    init = function()
      _G.oil_winbar = function()
        -- statusline_winid is only set while a statusline/winbar is being
        -- evaluated; fall back so the function is safe to call directly.
        local winid = vim.g.statusline_winid
        local bufnr = (winid and winid ~= 0) and vim.api.nvim_win_get_buf(winid) or vim.api.nvim_get_current_buf()
        local dir = require('oil').get_current_dir(bufnr)
        if not dir then
          -- No local directory, e.g. over ssh: fall back to the buffer name.
          return vim.api.nvim_buf_get_name(bufnr)
        end
        -- `dir` carries a trailing slash, so when it *is* the cwd, ':.' yields ''
        -- rather than '.'. Both mean "here", and both need the absolute form.
        local rel = vim.fn.fnamemodify(dir, ':~:.')
        if rel == '' or rel == '.' then
          return vim.fn.fnamemodify(dir, ':~')
        end
        return rel
      end
    end,
    config = function()
      local detail = false

      require('oil').setup {
        -- netrw stays the default handler for `:e <dir>`; oil is opened explicitly.
        default_file_explorer = false,
        columns = { 'icon' },
        delete_to_trash = true,
        watch_for_changes = true,
        use_default_keymaps = false,
        keymaps = {
          ['g?'] = { 'actions.show_help', mode = 'n', desc = 'oil_help' },
          ['<CR>'] = 'actions.select',
          ['zp'] = { 'actions.preview', desc = 'oil_preview' },
          ['zv'] = { 'actions.select', opts = { vertical = true }, desc = 'oil_select_vertical' },
          ['zs'] = { 'actions.select', opts = { horizontal = true }, desc = 'oil_select_horizontal' },
          ['<C-c>'] = { 'actions.close', mode = 'n' },
          ['<C-r>'] = 'actions.refresh',
          ['zr'] = { 'actions.refresh', desc = 'oil_refresh' },
          ['-'] = { 'actions.parent', mode = 'n', desc = 'oil_parent' },
          ['_'] = { 'actions.open_cwd', mode = 'n', desc = 'oil_open_cwd' },
          ['~'] = { 'actions.cd', mode = 'n', desc = 'oil_cwd' },
          ['zo'] = { 'actions.change_sort', mode = 'n', desc = 'oil_order_by' },
          ['gx'] = 'actions.open_external',
          ['z.'] = { 'actions.toggle_hidden', mode = 'n', desc = 'oil_toggle_hidden' },
          ['zt'] = { 'actions.toggle_trash', mode = 'n', desc = 'oil_toggle_trash' },
          ['zd'] = {
            desc = 'oil_toggle_detail',
            callback = function()
              detail = not detail
              require('oil').set_columns(detail and { 'permissions', 'size', 'mtime', 'icon' } or { 'icon' })
            end,
          },
        },
        win_options = {
          winbar = '%!v:lua.oil_winbar()',
        },
      }
    end,
  },
}
