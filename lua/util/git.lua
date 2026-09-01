local M = {}

-- Repo root for nvim's cwd, which is where every command below runs.
local function cwd_root()
  local cwd = vim.uv.cwd()
  if not cwd then
    return '.'
  end
  local info = M.dir_info(cwd)
  return (info and info.root) or cwd
end

-- Run git and report failure rather than letting it pass silently, then let open
-- buffers notice what changed on disk. argv, so nothing goes through a shell and
-- no argument needs quoting.
function M.run(args, ok_msg)
  local cmd = vim.list_extend({ 'git' }, args)
  local res = vim.system(cmd, { text = true, cwd = cwd_root() }):wait()
  if res.code == 0 then
    if ok_msg then
      vim.notify(ok_msg)
    end
    vim.cmd.checktime()
    return true
  end
  local err = vim.trim(res.stderr or '')
  vim.notify(err ~= '' and err or 'git failed', vim.log.levels.ERROR)
  return false
end

-- Keyed by repo root: one nvim session moves between repos, and `main` for one is
-- wrong for another. Only *successful* lookups are cached -- the old code cached
-- the 'main' fallback too, so a single call made outside a repo (or before
-- origin/HEAD existed) pinned 'main' for the rest of the session.
local cached_main = {}

-- Default branch of `origin`, e.g. "main". The old config piped rev-parse
-- through sed and returned vim.fn.system's output verbatim, keeping the trailing
-- newline -- git then rejected the ref with "ambiguous argument 'main\n'".
function M.main_branch()
  local root = cwd_root()
  if cached_main[root] then
    return cached_main[root]
  end

  local res = vim.system({ 'git', 'rev-parse', '--abbrev-ref', 'origin/HEAD' }, { text = true, cwd = root }):wait()
  if res.code == 0 then
    local name = vim.trim(res.stdout or ''):gsub('^origin/', '')
    if name ~= '' then
      cached_main[root] = name
      return name
    end
  end

  -- Not cached: origin/HEAD may just not be set up in this repo yet.
  return 'main'
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

-- Callers splice these refs straight into a command string, where a nil is an
-- E5108 rather than a message -- so offer reporting variants and let the caller
-- bail on nil.
local function report(base, kind, branch)
  if not base then
    vim.notify(('No %s with %s'):format(kind, branch), vim.log.levels.ERROR)
  end
  return base
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

-- Statusline-safe repo facts, read off disk rather than shelled out, and cached
-- because these run on every redraw -- many times a second. The TTL is the whole
-- invalidation story on purpose: a branch can change from outside nvim, so no
-- set of autocmds is authoritative, and a second of staleness on a statusline
-- costs nothing.
local DIR_TTL_MS = 1000
local dir_cache = {}

-- First line of a file, or nil. Deliberately not vim.fn.readfile, which raises
-- E484 on an unreadable path -- inside a statusline component that means the
-- error repeats on every redraw.
local function read_first_line(path)
  local fd = vim.uv.fs_open(path, 'r', 438)
  if not fd then
    return nil
  end
  local stat = vim.uv.fs_fstat(fd)
  local data = stat and vim.uv.fs_read(fd, math.min(stat.size, 4096), 0) or nil
  vim.uv.fs_close(fd)
  return data and data:match '^[^\r\n]*' or nil
end

local function resolve_dir(dir)
  local root = vim.fs.root(dir, '.git')
  if not root then
    return nil
  end

  local dotgit = vim.fs.joinpath(root, '.git')
  local gitdir, worktree = dotgit, nil
  local stat = vim.uv.fs_stat(dotgit)
  if stat and stat.type == 'file' then
    -- Linked worktree or submodule: `.git` is a file pointing at the real git
    -- dir, e.g. `gitdir: /repo/.git/worktrees/NAME`.
    local target = (read_first_line(dotgit) or ''):match 'gitdir: (.+)$'
    if target then
      gitdir = vim.fs.normalize(vim.startswith(target, '/') and target or vim.fs.joinpath(root, target))
      worktree = target:match 'worktrees/(.+)$'
    else
      gitdir = nil
    end
  end

  local branch
  if gitdir then
    local head = read_first_line(vim.fs.joinpath(gitdir, 'HEAD')) or ''
    -- Detached HEAD falls back to a short sha, the same width lualine uses.
    branch = head:match 'ref: refs/heads/(.+)$' or (head ~= '' and head:sub(1, 6) or nil)
  end

  return { root = root, gitdir = gitdir, worktree = worktree, branch = branch }
end

-- Repo facts for `dir`: working-tree root, real git dir, linked-worktree name,
-- and branch (or short sha when detached). nil when `dir` is not in a repo.
function M.dir_info(dir)
  if not dir then
    return nil
  end
  local now = vim.uv.now()
  local hit = dir_cache[dir]
  if hit and now - hit.at < DIR_TTL_MS then
    return hit.info
  end
  local info = resolve_dir(dir)
  dir_cache[dir] = { at = now, info = info }
  return info
end

function M.require_merge_base(branch)
  branch = (branch and branch ~= '') and branch or M.main_branch()
  return report(M.merge_base(branch), 'merge base', branch)
end

function M.require_fork_point(branch)
  branch = (branch and branch ~= '') and branch or M.main_branch()
  return report(M.fork_point(branch), 'fork point or merge base', branch)
end

return M
