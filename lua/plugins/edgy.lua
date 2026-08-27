-- Docked window layout. A few slots below are for plugins that aren't in this
-- config yet (trouble, neo-tree, vista): an `ft` that never appears simply never
-- matches, so the full layout is kept and each panel starts docking the moment
-- its plugin lands.
--
-- SIDEBAR_POSITION was a global env knob in the old config; it only matters here.
local SIDEBAR_POSITION = 'right' -- 'left' | 'right'

local SIZES = {
  bottom_height = 0.2,
  bottom_height_2 = 0.25,
  left_width = 0.1,
  left_width_2 = 0.15,
  left_width_3 = 0.2,
  right_width = 0.15,
  right_width_2 = 0.2,
}

-- vim.startswith replaces the old common.utils.starts_with helper.
local function trouble_mode_is(win, prefix)
  return vim.w[win].trouble and vim.startswith(vim.w[win].trouble.mode, prefix)
end

local bottom = {
  { title = 'Git (Fugitive)', ft = 'fugitive', size = { height = SIZES.bottom_height } },
  { title = 'REPL (DAP)', ft = 'dap-repl', size = { height = SIZES.bottom_height_2 } },
  { title = 'Console (DAP)', ft = 'dapui_console', size = { height = SIZES.bottom_height_2 } },
  {
    title = 'Diagnostics (Trouble)',
    ft = 'trouble',
    size = { height = SIZES.bottom_height },
    filter = function(_, win)
      return trouble_mode_is(win, 'diagnostics')
    end,
  },
  {
    title = 'List (Trouble)',
    ft = 'trouble',
    size = { height = SIZES.bottom_height },
    filter = function(_, win)
      return vim.w[win].trouble and (vim.w[win].trouble.mode == 'loclist' or vim.w[win].trouble.mode == 'quickfix')
    end,
  },
  {
    title = 'Preview (Trouble)',
    ft = 'trouble',
    size = { height = SIZES.bottom_height_2 },
    filter = function(_, win)
      return vim.w[win].trouble and vim.w[win].trouble_preview
    end,
  },
}

local left = {
  { title = 'Explorer (Neotree)', ft = 'neo-tree', size = { width = SIZES.left_width_2 } },
  { title = 'Symbols (Vista)', ft = 'vista', size = { width = SIZES.left_width_2 } },
  { title = 'Scopes (DAP)', ft = 'dapui_scopes', size = { width = SIZES.left_width_3 } },
  { title = 'Breakpoints (DAP)', ft = 'dapui_breakpoints', size = { width = SIZES.left_width_3 } },
  { title = 'Stacks (DAP)', ft = 'dapui_stacks', size = { width = SIZES.left_width_3 } },
  { title = 'Watches (DAP)', ft = 'dapui_watches', size = { width = SIZES.left_width_3 } },
  { title = 'Calendar', ft = 'calendar', size = { width = SIZES.left_width } },
}

local right = {
  { title = 'Tasks (Overseer)', ft = 'OverseerList', size = { width = SIZES.right_width } },
  { title = 'Tests (Neotest)', ft = 'neotest-summary', size = { width = SIZES.right_width_2 } },
  {
    title = 'LSP (Trouble)',
    ft = 'trouble',
    size = { width = SIZES.right_width_2 },
    filter = function(_, win)
      return trouble_mode_is(win, 'lsp') and not vim.w[win].trouble_preview
    end,
  },
  {
    title = 'Telescope (Trouble)',
    ft = 'trouble',
    size = { width = SIZES.right_width_2 },
    filter = function(_, win)
      return trouble_mode_is(win, 'telescope') and not vim.w[win].trouble_preview
    end,
  },
}

-- With the sidebar on the right, the left-hand panels dock there too.
local right_and_left = vim.deepcopy(right)
vim.list_extend(right_and_left, left)

return {
  {
    'folke/edgy.nvim',
    event = 'VeryLazy',
    keys = {
      {
        '<leader>zx',
        function()
          require('edgy').close()
        end,
        desc = 'close_ui',
      },
      {
        '<leader>zo',
        function()
          require('edgy').close 'bottom'
        end,
        desc = 'close_panel',
      },
      {
        '<leader>ex',
        function()
          require('edgy').close(SIDEBAR_POSITION)
        end,
        desc = 'close_sidebar',
      },
      {
        '<leader>ze',
        function()
          require('edgy').close(SIDEBAR_POSITION)
        end,
        desc = 'close_sidebar',
      },
    },
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      exit_when_last = true,
      animate = { enabled = false },
      wo = { winhighlight = '' },
      keys = {
        ['<C-Right>'] = function(win)
          win:resize('width', 2)
        end,
        ['<C-Left>'] = function(win)
          win:resize('width', -2)
        end,
        ['<C-Up>'] = function(win)
          win:resize('height', 2)
        end,
        ['<C-Down>'] = function(win)
          win:resize('height', -2)
        end,
        ['<leader>zr'] = function(win)
          win.view.edgebar:equalize()
        end,
      },
      bottom = bottom,
      left = SIDEBAR_POSITION == 'left' and left or {},
      right = SIDEBAR_POSITION == 'left' and right or right_and_left,
    },
  },
}
