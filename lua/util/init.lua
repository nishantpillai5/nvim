local M = {}

-- Project root: nearest .git above the given buffer, else the cwd.
function M.root_dir(bufnr)
  return vim.fs.root(bufnr or 0, '.git') or vim.uv.cwd()
end

return M
