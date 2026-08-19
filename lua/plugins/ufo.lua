-- Fold text like `foo() 󰁂 12`, truncated to the window width.
local function fold_virt_text(virt_text, lnum, end_lnum, width, truncate)
  local result = {}
  local suffix = (' 󰁂 %d '):format(end_lnum - lnum)
  local target_width = width - vim.fn.strdisplaywidth(suffix)
  local cur_width = 0

  for _, chunk in ipairs(virt_text) do
    local text = chunk[1]
    local chunk_width = vim.fn.strdisplaywidth(text)
    if target_width > cur_width + chunk_width then
      table.insert(result, chunk)
    else
      text = truncate(text, target_width - cur_width)
      table.insert(result, { text, chunk[2] })
      chunk_width = vim.fn.strdisplaywidth(text)
      -- truncate() can come back narrower than asked; pad the suffix to match.
      if cur_width + chunk_width < target_width then
        suffix = suffix .. (' '):rep(target_width - cur_width - chunk_width)
      end
      break
    end
    cur_width = cur_width + chunk_width
  end

  table.insert(result, { suffix, 'MoreMsg' })
  return result
end

return {
  {
    'kevinhwang91/nvim-ufo',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = { 'kevinhwang91/promise-async' },
    init = function()
      -- ufo needs folds open and a high foldlevel to drive them itself.
      vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]
      vim.o.foldcolumn = '0'
      vim.o.foldlevel = 99
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true
    end,
    opts = {
      fold_virt_text_handler = fold_virt_text,
      open_fold_hl_timeout = 400,
      preview = {
        win_config = {
          border = { '', '─', '', '', '', '─', '', '' },
          winblend = 0,
        },
        mappings = {
          scrollU = '<C-u>',
          scrollD = '<C-d>',
          jumpTop = '[',
          jumpBot = ']',
        },
      },
    },
  },
}
