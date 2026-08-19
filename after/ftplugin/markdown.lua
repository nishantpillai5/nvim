vim.opt_local.commentstring = '<!-- %s -->'

-- Conceal markup only inside the notes directory, where it's prose to read
-- rather than source to edit.
local notes = require('util.env').DIR_NOTES
if vim.fs.normalize(vim.fn.expand '%:p'):lower():find(vim.fs.normalize(notes):lower(), 1, true) then
  vim.opt_local.conceallevel = 1
end
