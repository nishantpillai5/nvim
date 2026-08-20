local M = {}

local cached_main

-- Default branch of `origin`, e.g. "main". The old config piped rev-parse
-- through sed and returned vim.fn.system's output verbatim, keeping the trailing
-- newline -- git then rejected the ref with "ambiguous argument 'main\n'".
function M.main_branch()
  if cached_main then
    return cached_main
  end

  local res = vim.system({ 'git', 'rev-parse', '--abbrev-ref', 'origin/HEAD' }, { text = true }):wait()
  if res.code == 0 then
    local name = vim.trim(res.stdout or ''):gsub('^origin/', '')
    if name ~= '' then
      cached_main = name
    end
  end

  cached_main = cached_main or 'main'
  return cached_main
end

-- Current branch name, or nil on a detached HEAD or outside a repo.
function M.branch()
  local res = vim.system({ 'git', 'symbolic-ref', '--short', 'HEAD' }, { text = true }):wait()
  if res.code ~= 0 then
    return nil
  end
  local out = vim.trim(res.stdout or '')
  return out ~= '' and out or nil
end

function M.merge_base(branch)
  branch = (branch and branch ~= '') and branch or M.main_branch()
  local res = vim.system({ 'git', 'merge-base', 'HEAD', branch }, { text = true }):wait()
  if res.code ~= 0 then
    return nil
  end
  local out = vim.trim(res.stdout or '')
  return out ~= '' and out or nil
end

-- `--fork-point` needs reflog data and fails outright on shallow or fresh
-- clones, so fall back to the plain merge base rather than returning git's
-- error text as if it were a ref.
function M.fork_point(branch)
  branch = (branch and branch ~= '') and branch or M.main_branch()
  local res = vim.system({ 'git', 'merge-base', '--fork-point', branch, 'HEAD' }, { text = true }):wait()
  if res.code == 0 then
    local out = vim.trim(res.stdout or '')
    if out ~= '' then
      return out
    end
  end
  return M.merge_base(branch)
end

return M
