vim.opt_local.commentstring = '<!-- %s -->'

local notes = require('util.env').DIR_NOTES
local in_notes = vim.fs.normalize(vim.fn.expand '%:p'):lower():find(vim.fs.normalize(notes):lower(), 1, true) ~= nil

-- Conceal markup only inside the notes directory, where it's prose to read
-- rather than source to edit.
if in_notes then
  vim.opt_local.conceallevel = 1
end

-- Notes keep worked hours as `09:00-17:00`, optionally with an explicit break
-- as `(b45)`. The virtual text is the span minus that break, 30 minutes when
-- none is written.
if in_notes then
  local ns = vim.api.nvim_create_namespace 'markdown_time_diff'

  local function update_time_diffs(buf)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
      local h1, m1, h2, m2 = line:match '(%d+):(%d+)-(%d+):(%d+)'
      if h1 then
        local brk = tonumber(line:match '%(b(%d+)%)') or 30
        local diff = math.abs((tonumber(h1) * 60 + tonumber(m1)) - (tonumber(h2) * 60 + tonumber(m2))) - brk
        vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
          virt_text = { { ('%dh %dm (b%d)'):format(math.floor(diff / 60), diff % 60, brk), 'Comment' } },
          virt_text_pos = 'eol',
        })
      end
    end
  end

  -- Buffer-local, and cleared first: an ftplugin runs again whenever the
  -- filetype is re-set, which a `:edit` of the same file does.
  local group = vim.api.nvim_create_augroup('markdown_time_diff', { clear = false })
  vim.api.nvim_clear_autocmds { group = group, buffer = 0 }
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = group,
    buffer = 0,
    desc = 'worked-hours virtual text for HH:MM-HH:MM lines',
    callback = function(args)
      update_time_diffs(args.buf)
    end,
  })

  update_time_diffs(vim.api.nvim_get_current_buf())
end
