-- `_G.fav_dirs` is the per-project half: a repo's .nvim.lua is loaded before
-- this runs, and whatever it sets there wins.
local function select_fav(callback)
  local env = require 'util.env'
  local dirs = vim.tbl_extend('force', {
    config = env.XDG_CONFIG_HOME,
    notes = env.DIR_NOTES,
    nvim = env.DIR_NVIM,
  }, _G.fav_dirs or {})

  local names = vim.tbl_keys(dirs)
  table.sort(names)

  vim.ui.select(names, {
    prompt = 'Favourite directories',
    format_item = function(name)
      return ('%s  (%s)'):format(name, vim.fn.fnamemodify(dirs[name], ':~'))
    end,
  }, function(name)
    if name then
      -- A hand-written .nvim.lua entry may still be '~/...'.
      callback(vim.fn.expand(dirs[name]))
    end
  end)
end

return {
  {
    'stevearc/oil.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    cmd = 'Oil',
    keys = {
      { '<leader>ef', '<cmd>Oil<cr>', desc = 'oil' },
      {
        '<leader>fe',
        function()
          select_fav(function(dir)
            require('oil').open(dir)
          end)
        end,
        desc = 'fav_dirs',
      },
      {
        '<leader>fE',
        function()
          select_fav(vim.ui.open)
        end,
        desc = 'fav_dirs_external',
      },
    },
    -- win_options.winbar takes a vimscript expression, so this has to be
    -- reachable from v:lua.
    init = function()
      _G.oil_winbar = function()
        -- Only set while a winbar is being evaluated, so this stays callable.
        local winid = vim.g.statusline_winid
        local bufnr = (winid and winid ~= 0) and vim.api.nvim_win_get_buf(winid) or vim.api.nvim_get_current_buf()
        local dir = require('oil').get_current_dir(bufnr)
        if not dir then
          -- No local directory, e.g. over ssh: fall back to the buffer name.
          return vim.api.nvim_buf_get_name(bufnr)
        end
        -- `dir` has a trailing slash, so ':.' yields '' for the cwd, not '.'.
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
