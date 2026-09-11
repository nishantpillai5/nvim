-- Claude Code as one of the AI backends behind <leader>a; see util/ai.

local function relative_time(mtime)
  local diff = os.time() - mtime
  if diff < 60 then
    return 'just now'
  elseif diff < 3600 then
    return math.floor(diff / 60) .. 'm ago'
  elseif diff < 86400 then
    return math.floor(diff / 3600) .. 'h ago'
  elseif diff < 604800 then
    return math.floor(diff / 86400) .. 'd ago'
  elseif diff < 2592000 then
    return math.floor(diff / 604800) .. 'w ago'
  elseif diff < 31536000 then
    return math.floor(diff / 2592000) .. 'mo ago'
  else
    return math.floor(diff / 31536000) .. 'y ago'
  end
end

local function extract_text(raw)
  if raw:find('<local%-command%-caveat>', 1, true) then
    return nil
  end
  local cmd_name = raw:match '<command%-name>%s*(.-)%s*</command%-name>'
  if cmd_name and cmd_name ~= '' then
    return cmd_name
  end
  local stripped = raw:gsub('<[^>]+>', ' '):gsub('%s+', ' '):match '^%s*(.-)%s*$'
  return stripped ~= '' and stripped or nil
end

-- vim.json.decode maps null to vim.NIL, which is *truthy*, so `t.a and t.a.b`
-- throws on `"a":null` -- outside any pcall, that takes the whole picker down.
local function json_field(tbl, key)
  if type(tbl) ~= 'table' then
    return nil
  end
  local v = tbl[key]
  if v == nil or v == vim.NIL then
    return nil
  end
  return v
end

-- Claude's string hash over the raw path, in base36: `(h << 5) - h + c | 0`
-- per character, which taken mod 2^32 is the `h * 31 + c` below.
local function key_hash(path)
  local h = 0
  for i = 1, #path do
    h = (h * 31 + path:byte(i)) % 0x100000000
  end
  -- Back to the signed int32 the CLI hashes with, then Math.abs.
  if h >= 0x80000000 then
    h = 0x100000000 - h
  end
  if h == 0 then
    return '0'
  end
  local digits, out = '0123456789abcdefghijklmnopqrstuvwxyz', ''
  while h > 0 do
    local d = h % 36
    out = digits:sub(d + 1, d + 1) .. out
    h = math.floor(h / 36)
  end
  return out
end

-- Non-alphanumerics become '-', and a key over 200 characters is cut with a
-- hash suffix. Mirrors the CLI exactly; one character off finds nothing.
local PROJECT_KEY_MAX = 200

local function encode_project(dir)
  local key = (dir:gsub('[^a-zA-Z0-9]', '-'))
  if #key <= PROJECT_KEY_MAX then
    return key
  end
  return key:sub(1, PROJECT_KEY_MAX) .. '-' .. key_hash(dir)
end

-- The .jsonl transcripts recorded under one project key, in glob order.
local function session_files(key)
  return vim.fn.glob(vim.fn.expand '~/.claude/projects' .. '/' .. key .. '/*.jsonl', false, true)
end

-- Session id of the most recently written transcript under `key`, or nil.
local function newest_session(key)
  local newest, newest_at = nil, -1
  for _, f in ipairs(session_files(key)) do
    local at = vim.fn.getftime(f)
    if at > newest_at then
      newest, newest_at = f, at
    end
  end
  return newest and vim.fn.fnamemodify(newest, ':t:r') or nil
end

local function build_path_map()
  local path_map = {}
  local cj = io.open(vim.fn.expand '~/.claude.json', 'r')
  if cj then
    local ok, data = pcall(vim.json.decode, cj:read '*a')
    cj:close()
    local projects = ok and json_field(data, 'projects')
    if projects then
      local home = vim.fn.expand '~'
      for actual_path, _ in pairs(projects) do
        local display = actual_path:gsub('^' .. vim.pesc(home), '~')
        path_map[encode_project(actual_path)] = display
      end
    end
  end
  return path_map
end

-- Transcripts run to tens of MB, so cache on mtime+size and parse only the head
-- -- both the ai-title and the first user message live near the top.
local TITLE_SCAN_BYTES = 512 * 1024
local title_cache = {}

local function parse_session_title(chunk)
  local ai_title, first_msg = nil, ''
  for line in chunk:gmatch '[^\n]+' do
    -- A truncated chunk's last line is incomplete JSON; the decode just fails.
    local ok, entry = pcall(vim.json.decode, line)
    if ok and type(entry) == 'table' then
      if entry.type == 'ai-title' and json_field(entry, 'aiTitle') then
        ai_title = entry.aiTitle
      elseif first_msg == '' and entry.type == 'user' then
        local content = json_field(json_field(entry, 'message'), 'content')
        local raw
        if type(content) == 'string' then
          raw = content
        elseif type(content) == 'table' then
          for _, part in ipairs(content) do
            if type(part) == 'table' and part.type == 'text' and part.text then
              raw = part.text
              break
            end
          end
        end
        if raw then
          first_msg = extract_text(raw:sub(1, 200)) or ''
        end
      end
      if ai_title and first_msg ~= '' then
        break
      end
    end
  end
  return (ai_title or first_msg):gsub('\n', ' '):sub(1, 80)
end

local function read_session_title(session_file)
  local stat = vim.uv.fs_stat(session_file)
  local key = stat and (stat.mtime.sec .. ':' .. stat.size) or nil
  local hit = title_cache[session_file]
  if key and hit and hit.key == key then
    return hit.title
  end

  local sf = io.open(session_file, 'r')
  if not sf then
    return ''
  end
  local chunk = sf:read(TITLE_SCAN_BYTES) or ''
  sf:close()

  local title = parse_session_title(chunk)
  if key then
    title_cache[session_file] = { key = key, title = title }
  end
  return title
end

-- Forward declaration: defined lower in the file, used by the session picker.
local show_no_focus

-- Forward declaration: defined next to show_no_focus.
local launch_claude

-- Directory the *next* Claude process should start in, parked by the worktree
-- maps and consumed by the cwd_provider in setup below. nil = nvim's own cwd.
local worktree_cwd

-- Forward declaration: called by show_no_focus above its assignment.
local ensure_terminal_autoscroll

-- Worktrees the repo no longer has whose transcripts outlived the directory.
-- Matched by key prefix: the encoding is lossy, so no path can be recovered.
local function orphaned_worktrees(root, live_keys)
  local prefix = encode_project(vim.fs.joinpath(root, '.claude', 'worktrees') .. '/')
  local items = {}
  for _, dir in ipairs(vim.fn.glob(vim.fn.expand '~/.claude/projects' .. '/*', false, true)) do
    local key = vim.fn.fnamemodify(dir, ':t')
    if key:sub(1, #prefix) == prefix and not live_keys[key] then
      local files = session_files(key)
      if #files > 0 then
        local newest = 0
        for _, f in ipairs(files) do
          newest = math.max(newest, vim.fn.getftime(f))
        end
        table.insert(items, {
          key = key,
          cwd = root,
          deleted = true,
          -- The name minus the shared prefix; its '/' went with the encoding.
          name = key:sub(#prefix + 1),
          mtime = newest,
        })
      end
    end
  end
  table.sort(items, function(a, b)
    return a.mtime > b.mtime
  end)
  return items
end

-- 'here' and 'worktree' share a rank -- both are this repo, so recency is the
-- better order between them -- but keep different path colours. Telescope draws
-- entry 1 at the bottom, next to the prompt, so rank 1 is where you land.
local ORIGIN_RANK = { here = 1, worktree = 1, other = 2 }

-- Green for this directory, blue for another worktree of the same repo; the
-- title stays default-white for both. An 'other' row is painted flat grey
-- instead and never reaches this table.
local ORIGIN_PATH_HL = { here = 'Comment', worktree = 'Directory' }

-- Keys belonging to a worktree of this repo, live or removed. Outside a repo
-- there are none and the picker falls back to here-vs-elsewhere.
local function worktree_keys()
  local records = require('util.git').worktrees(vim.uv.cwd() or '.')
  if not records then
    return {}
  end
  local keys, root = {}, nil
  for _, r in ipairs(records) do
    if not r.bare then
      root = root or r.path -- git lists the primary working tree first
      keys[encode_project(r.path)] = true
    end
  end
  if root then
    for _, item in ipairs(orphaned_worktrees(root, keys)) do
      keys[item.key] = true
    end
  end
  return keys
end

-- Session preview pane. Transcripts run to megabytes and the previewer re-fires
-- on every cursor move, so it reads a tail sized to the window and grows the
-- bite only when a chunk turns out to be mostly tool payloads.

local PREVIEW_TAIL_BYTES = 128 * 1024
local PREVIEW_MAX_BYTES = 4 * 1024 * 1024

-- More than one windowful so <C-u> scrolls into real history, but bounded --
-- the buffer is repainted on every cursor move.
local PREVIEW_MAX_ROWS = 500
local preview_cache = {}

-- Last `bytes` of a file, minus the partial line at the cut. Also reports
-- reaching the start, which is the signal to stop growing.
local function read_tail(path, bytes)
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return nil
  end
  local f = io.open(path, 'r')
  if not f then
    return nil
  end
  local from = math.max(0, stat.size - bytes)
  if from > 0 then
    f:seek('set', from)
  end
  local chunk = f:read '*a' or ''
  f:close()
  if from > 0 then
    -- Whatever precedes the first newline was cut mid-JSON; drop it.
    chunk = chunk:match '\n(.*)$' or ''
  end
  return chunk, from == 0
end

-- One line per tool call, so pick the argument that says what it was about.
local TOOL_ARG_KEYS = { 'command', 'file_path', 'path', 'pattern', 'query', 'url', 'description', 'prompt' }

local function tool_summary(block)
  local name = block.name or 'tool'
  local input = json_field(block, 'input')
  if type(input) == 'table' then
    for _, key in ipairs(TOOL_ARG_KEYS) do
      local val = json_field(input, key)
      if type(val) == 'string' and val ~= '' then
        local arg = val:gsub('%s+', ' '):sub(1, 60)
        return name .. '(' .. arg .. ')'
      end
    end
  end
  return name
end

-- One record -> zero or more preview rows. Skipped: sidechains, tool results
-- (bulk, and the call above says what ran), and thinking blocks.
local function render_record(entry, rows)
  if entry.type ~= 'user' and entry.type ~= 'assistant' then
    return
  end
  if entry.isSidechain or entry.isMeta then
    return
  end
  local content = json_field(json_field(entry, 'message'), 'content')
  if type(content) == 'string' then
    content = { { type = 'text', text = content } }
  elseif type(content) ~= 'table' then
    return
  end
  for _, block in ipairs(content) do
    if type(block) == 'table' then
      if block.type == 'text' and type(block.text) == 'string' then
        if entry.type == 'user' then
          -- extract_text also collapses pasted walls and drops caveat blocks.
          local text = extract_text(block.text)
          if text then
            if #rows > 0 then
              rows[#rows + 1] = { text = '', kind = 'gap' }
            end
            rows[#rows + 1] = { text = '❯ ' .. text, kind = 'user' }
          end
        else
          for _, line in ipairs(vim.split(block.text, '\n')) do
            rows[#rows + 1] = { text = line, kind = 'text' }
          end
        end
      elseif block.type == 'tool_use' then
        rows[#rows + 1] = { text = '⏺ ' .. tool_summary(block), kind = 'tool' }
      end
    end
  end
end

-- Enough rows to fill a window `height` tall, newest last.
local function session_preview_rows(path, height)
  local stat = vim.uv.fs_stat(path)
  local key = stat and (stat.mtime.sec .. ':' .. stat.size) or nil
  local hit = preview_cache[path]
  if key and hit and hit.key == key and (hit.complete or #hit.rows >= height) then
    return hit.rows
  end

  local rows, complete, bytes = {}, false, PREVIEW_TAIL_BYTES
  while true do
    local chunk, whole = read_tail(path, bytes)
    if not chunk then
      return {}
    end
    rows, complete = {}, whole
    for line in chunk:gmatch '[^\n]+' do
      local ok, entry = pcall(vim.json.decode, line)
      if ok and type(entry) == 'table' then
        render_record(entry, rows)
      end
    end
    if #rows >= height or whole or bytes >= PREVIEW_MAX_BYTES then
      break
    end
    bytes = bytes * 4
  end

  if key then
    preview_cache[path] = { key = key, rows = rows, complete = complete }
  end
  return rows
end

local preview_ns = vim.api.nvim_create_namespace 'claude_session_preview'

local PREVIEW_HL = { user = 'Special', tool = 'Comment' }

local function session_previewer()
  local previewers = require 'telescope.previewers'
  return previewers.new_buffer_previewer {
    title = 'Session',
    -- One buffer per transcript, reused rather than reparsed on every move.
    get_buffer_by_name = function(_, entry)
      return entry.file
    end,
    define_preview = function(self, entry)
      local bufnr, winid = self.state.bufnr, self.state.winid
      local valid_win = winid and vim.api.nvim_win_is_valid(winid)
      local height = valid_win and vim.api.nvim_win_get_height(winid) or 20

      local lines, kinds = {}, {}
      if entry.new or entry.file == '' then
        lines = { 'Start a new Claude session in', '', '  ' .. entry.project }
      else
        local rows = session_preview_rows(entry.file, height)
        -- Deeper than the window is tall, so there is something to scroll into.
        for i = math.max(1, #rows - PREVIEW_MAX_ROWS + 1), #rows do
          lines[#lines + 1] = rows[i].text
          kinds[#kinds + 1] = rows[i].kind
        end
        if #lines == 0 then
          lines = { '(nothing to show)' }
        end
      end

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_buf_clear_namespace(bufnr, preview_ns, 0, -1)
      -- Guarded: setting it re-fires every FileType autocmd on a reused buffer.
      if vim.bo[bufnr].filetype ~= 'markdown' then
        vim.bo[bufnr].filetype = 'markdown'
      end
      for i, kind in ipairs(kinds) do
        local hl = PREVIEW_HL[kind]
        if hl then
          vim.api.nvim_buf_set_extmark(bufnr, preview_ns, i - 1, 0, { end_row = i, hl_group = hl, hl_eol = true })
        end
      end

      if valid_win then
        -- Wrapped, so nothing is lost off the right edge.
        vim.wo[winid].wrap = true
        -- Waits a tick: telescope attaches a fresh buffer from its own scheduled
        -- callback, so a cursor set now would scroll the previous entry's.
        vim.schedule(function()
          if not (vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr) then
            return
          end
          pcall(vim.api.nvim_win_set_cursor, winid, { vim.api.nvim_buf_line_count(bufnr), 0 })
          pcall(vim.api.nvim_win_call, winid, function()
            vim.cmd 'normal! zb'
          end)
        end)
      end
    end,
  }
end

-- Bare it lists every project's sessions; `opts.key` narrows to one and
-- `opts.cwd` is where Claude then runs. Sessions under another key stay
-- resumable: `claude --resume <id>` scans ~/.claude/projects for the id.
---@param opts { key: string?, cwd: string?, title: string?, allow_new: boolean? }?
local function pick_claude_session(opts)
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'

  opts = opts or {}
  local path_map = build_path_map()
  local sessions_base = vim.fn.expand '~/.claude/projects'
  local run_cwd = opts.cwd
  local home_key = encode_project(run_cwd or vim.fn.getcwd())
  local wt_keys = worktree_keys()
  local entries = {}

  for _, project_dir in ipairs(vim.fn.glob(sessions_base .. '/*', false, true)) do
    local encoded_name = vim.fn.fnamemodify(project_dir, ':t')
    local display_project = path_map[encoded_name] or encoded_name

    if not opts.key or encoded_name == opts.key then
      for _, session_file in ipairs(vim.fn.glob(project_dir .. '/*.jsonl', false, true)) do
        local here = encoded_name == home_key
        table.insert(entries, {
          session_id = vim.fn.fnamemodify(session_file, ':t:r'),
          file = session_file,
          project = display_project,
          summary = read_session_title(session_file),
          mtime = vim.fn.getftime(session_file),
          loadable = here,
          origin = here and 'here' or (wt_keys[encoded_name] and 'worktree' or 'other'),
        })
      end
    end
  end

  -- This repo's sessions first, newest first within each group.
  table.sort(entries, function(a, b)
    local ra, rb = ORIGIN_RANK[a.origin], ORIGIN_RANK[b.origin]
    if ra ~= rb then
      return ra < rb
    end
    return a.mtime > b.mtime
  end)

  -- After the sort, so it stays pinned: an unopened worktree has no sessions and
  -- the picker would otherwise be a dead end.
  if opts.allow_new then
    local home = vim.fn.expand '~'
    table.insert(entries, 1, {
      new = true,
      -- Telescope reads `value` off every entry, so keep it a string.
      session_id = '',
      file = '',
      summary = 'Start a new session',
      project = ((run_cwd or vim.fn.getcwd()):gsub('^' .. vim.pesc(home), '~')),
      mtime = 0,
      loadable = true,
      origin = 'here',
    })
  end

  pickers
    .new({}, {
      prompt_title = opts.title or 'Claude Sessions',
      finder = finders.new_table {
        results = entries,
        entry_maker = function(entry)
          local make_display = function(e)
            local title = e.summary ~= '' and e.summary or '(no message)'
            local path_str = '  ' .. e.project
            local time_str = e.new and '' or ('  ' .. relative_time(e.mtime))
            local display = title .. path_str .. time_str
            -- Unrelated projects dim whole; this repo's keep a readable title.
            if e.origin == 'other' then
              return display, { { { 0, #display }, 'LspInlayHint' } }
            end
            return display,
              {
                { { #title, #title + #path_str }, ORIGIN_PATH_HL[e.origin] },
                { { #title + #path_str, #display }, 'Special' },
              }
          end
          return {
            value = entry.session_id,
            file = entry.file,
            display = make_display,
            ordinal = entry.summary .. ' ' .. entry.project,
            summary = entry.summary,
            project = entry.project,
            mtime = entry.mtime,
            loadable = entry.loadable,
            origin = entry.origin,
            new = entry.new,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      previewer = session_previewer(),
      attach_mappings = function(prompt_bufnr, map)
        local function resume_session()
          local selection = action_state.get_selected_entry()
          if not selection then
            return
          end
          actions.close(prompt_bufnr)
          -- `cond and nil or x` is always x in Lua, so branch explicitly.
          local cmd_args = nil
          if not selection.new then
            cmd_args = '--resume ' .. selection.value
            if not selection.loadable then
              vim.notify('Resuming a session from ' .. selection.project)
            end
          end
          launch_claude(cmd_args, run_cwd)
        end
        map('i', '<CR>', resume_session)
        map('n', '<CR>', resume_session)
        return true
      end,
    })
    :find()
end

-- Live worktrees first, then deleted ones with sessions. Claude runs with its
-- cwd in the worktree while nvim's stays put.
local function pick_worktree(cb)
  local cwd = vim.uv.cwd() or '.'
  local records = require('util.git').worktrees(cwd)
  if not records then
    vim.notify('Not a git repository', vim.log.levels.ERROR)
    return
  end

  -- Marked rather than hidden: picking the tree nvim is in is legitimate.
  local info = require('util.git').dir_info(cwd)
  local here = info and info.root and (vim.uv.fs_realpath(info.root) or info.root) or nil

  local items, live_keys, root = {}, {}, nil
  for _, r in ipairs(records) do
    if not r.bare then
      root = root or r.path -- git lists the primary working tree first
      local real = vim.uv.fs_realpath(r.path) or r.path
      local suffix = (r.branch and ('  [' .. r.branch .. ']')) or (r.detached and '  [detached]') or ''
      local name = vim.fn.fnamemodify(r.path, ':t')
      live_keys[encode_project(r.path)] = true
      table.insert(items, {
        key = encode_project(r.path),
        cwd = r.path,
        name = name,
        label = name .. suffix .. (real == here and '  (current)' or ''),
      })
    end
  end

  if root then
    for _, item in ipairs(orphaned_worktrees(root, live_keys)) do
      item.label = item.name .. '  [deleted — ' .. relative_time(item.mtime) .. ']'
      table.insert(items, item)
    end
  end

  if #items == 0 then
    vim.notify('No worktrees found', vim.log.levels.WARN)
    return
  end

  vim.ui.select(items, {
    prompt = 'Claude in worktree',
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if choice then
      cb(choice)
    end
  end)
end

-- Nothing to continue in an unopened worktree, so start fresh; and `--continue`
-- only looks at the current directory, so a deleted one's session needs its id.
local function continue_in_worktree()
  pick_worktree(function(item)
    if item.deleted then
      local id = newest_session(item.key)
      if not id then
        vim.notify('No sessions left for ' .. item.name, vim.log.levels.WARN)
        return
      end
      launch_claude('--resume ' .. id, item.cwd)
    else
      launch_claude(#session_files(item.key) > 0 and '--continue' or nil, item.cwd)
    end
  end)
end

-- <leader>aW: same, but choose which of that worktree's sessions to resume.
local function pick_worktree_session()
  pick_worktree(function(item)
    pick_claude_session {
      key = item.key,
      cwd = item.cwd,
      title = 'Claude in ' .. item.name .. (item.deleted and ' (deleted)' or ''),
      allow_new = not item.deleted,
    }
  end)
end

-- Raw bytes to the PTY without moving focus; false when no live channel.
local function send_raw(keys)
  local term = require 'claudecode.terminal'
  local bufnr = term.get_active_terminal_bufnr()
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    vim.notify('No Claude terminal running', vim.log.levels.WARN)
    return false
  end
  local chan = vim.b[bufnr] and vim.b[bufnr].terminal_job_id
  if not chan or chan == 0 then
    chan = vim.bo[bufnr].channel
  end
  if not chan or chan == 0 then
    vim.notify('No Claude terminal channel', vim.log.levels.WARN)
    return false
  end
  local ok, written = pcall(vim.fn.chansend, chan, keys)
  if not ok or written == 0 then
    vim.notify('Claude terminal channel is closed', vim.log.levels.WARN)
    return false
  end
  return true
end

-- The TUI autocompletes @file and /commands internally, which nvim cannot
-- observe, so the box reimplements both. These are the built-ins; project and
-- user command files are discovered alongside them.
local BUILTIN_SLASH = {
  'add-dir',
  'agents',
  'clear',
  'compact',
  'config',
  'context',
  'cost',
  'doctor',
  'exit',
  'export',
  'fast',
  'help',
  'hooks',
  'init',
  'install-github-app',
  'login',
  'logout',
  'mcp',
  'memory',
  'model',
  'permissions',
  'pr-comments',
  'review',
  'status',
  'statusline',
  'terminal-setup',
  'vim',
}

-- Walked fresh: the box caches the result for its own lifetime.
local function slash_command_names()
  local names, seen = {}, {}
  local function add(name)
    if name ~= '' and not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end
  for _, n in ipairs(BUILTIN_SLASH) do
    add(n)
  end
  -- Nested files namespace, matching Claude: commands/git/commit.md -> git:commit.
  local dirs = { vim.fn.getcwd() .. '/.claude/commands', vim.fn.expand '~/.claude/commands' }
  for _, dir in ipairs(dirs) do
    for _, f in ipairs(vim.fn.glob(dir .. '/**/*.md', false, true)) do
      local rel = f:sub(#dir + 2, -4) -- strip "<dir>/" prefix and ".md" suffix
      add((rel:gsub('/', ':')))
    end
  end
  return names
end

-- The greyed suggestion in Claude's input box, delimited by two horizontal
-- rules. There is no per-cell colour API for terminals, so this cannot tell a
-- suggestion from text you typed -- it assumes the input is untouched. Both
-- scrapers read a tail rather than the buffer, which carries up to 'scrollback'
-- lines; every index below is relative to that tail.
local SCRAPE_TAIL_LINES = 200

local function terminal_tail(bufnr)
  local count = vim.api.nvim_buf_line_count(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, math.max(0, count - SCRAPE_TAIL_LINES), -1, false)
end

local function get_claude_suggestion()
  local ok, term = pcall(require, 'claudecode.terminal')
  if not ok then
    return nil
  end
  local bufnr = term.get_active_terminal_bufnr()
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end
  local lines = terminal_tail(bufnr)
  local function is_rule(s)
    local stripped, n = s:gsub('\u{2500}', '')
    return n >= 10 and stripped:gsub('%s', '') == ''
  end
  -- Anchored on the last non-blank line, or two stale rules from scrollback get
  -- mistaken for the box and their contents returned as a bogus suggestion.
  local last_nonblank = 0
  for i = #lines, 1, -1 do
    if lines[i]:gsub('%s', '') ~= '' then
      last_nonblank = i
      break
    end
  end
  local bottom
  for i = #lines, 1, -1 do
    if is_rule(lines[i]) then
      bottom = i
      break
    end
  end
  if not bottom or (last_nonblank - bottom) > 8 then
    return nil
  end
  local top
  for i = bottom - 1, 1, -1 do
    if is_rule(lines[i]) then
      top = i
      break
    end
  end
  if not top then
    return nil
  end
  local content = {}
  for i = top + 1, bottom - 1 do
    content[#content + 1] = lines[i]
  end
  if #content == 0 then
    return nil
  end
  -- Drop the prompt marker, right-trim each line's box padding, trim the block.
  content[1] = content[1]:gsub('^%s*', ''):gsub('^\u{276f}%s?', ''):gsub('^>%s?', '')
  for i, l in ipairs(content) do
    content[i] = (l:gsub('%s+$', ''))
  end
  -- The empty box is padded with U+00A0, which Lua's %s does not match -- left
  -- alone it scrapes to a non-empty string and reads as a real suggestion.
  local text = table.concat(content, '\n'):gsub('\u{00a0}', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  if text == '' then
    return nil
  end
  return text
end

-- Claude's mention format: "@lua/config/claude.lua#L10-20", cwd-relative and
-- 1-indexed. nil for non-file or unnamed buffers.
local function build_mention(buf, vsel)
  if vim.bo[buf].buftype ~= '' then
    return nil
  end
  local file_path = vim.api.nvim_buf_get_name(buf)
  if file_path == '' then
    return nil
  end
  local rel = vim.fn.fnamemodify(file_path, ':.')
  if vsel[1] == vsel[2] then
    return '@' .. rel .. '#L' .. vsel[1]
  end
  return '@' .. rel .. '#L' .. vsel[1] .. '-' .. vsel[2]
end

-- AskUserQuestion prompts are scraped live from the terminal: Claude only
-- flushes one to disk *after* it is answered. The tab currently shown renders as
--
--   ←  ☐ Fruit  ☐ Colors  ✔ Submit  →   <- tab bar, one per question + Submit
--   Which fruit do you prefer?          <- the question
--   ❯ 1. Apple                          <- ❯ marks the highlighted option
--        A crisp red or green fruit.    <- description, indented
--     2. Banana
--   Enter to select · Tab/Arrow keys to navigate · Esc to cancel
--
-- Multi-select adds a "[ ]"/"[x]" per option. Answers go back as option number
-- keys, the only input that proved reliable over the PTY.

-- A horizontal-rule line (───...), used to bound the box on screen.
local function is_hr(s)
  local stripped, n = s:gsub('\u{2500}', '')
  return n >= 10 and stripped:gsub('%s', '') == ''
end

-- Parse one option line. Returns { num, label, checked } or nil. `checked` is
-- nil for single-select, true/false for a "[x]"/"[ ]" checkbox.
local function parse_option_line(line)
  -- Column the number starts at, counting ❯ as the whitespace it replaces. The
  -- scrape loop rejects numbered lines deeper than this -- i.e. inside a desc.
  local prefix = line:match '^%s*\u{276f}%s*' or line:match '^%s*' or ''
  local indent = vim.fn.strdisplaywidth(prefix)

  local body = line:gsub('^%s*\u{276f}%s*', ''):gsub('^%s*', '')
  local num, rest = body:match '^(%d+)%.%s+(.*)$'
  if not num then
    return nil
  end
  -- Only a genuine checkbox: `1. [P0] Fix it` flipped the question to
  -- multi-select, and choice_keys then pressed every *other* option's number.
  local inside, label = rest:match '^%[([^%]]*)%]%s*(.*)$'
  if inside ~= nil then
    local mark = inside:gsub('%s', '')
    if mark == '' or mark == 'x' or mark == 'X' or mark == '\u{2713}' or mark == '\u{2714}' then
      return { num = tonumber(num), label = label, checked = mark ~= '', indent = indent }
    end
  end
  return { num = tonumber(num), label = rest, indent = indent }
end

-- Returns { multiselect, question, options = { {num, pos, label, desc, checked} } }
-- for the shown tab, or nil when no such prompt is on screen.
local function scrape_claude_question()
  local ok, term = pcall(require, 'claudecode.terminal')
  if not ok then
    return nil
  end
  local bufnr = term.get_active_terminal_bufnr()
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end
  local lines = terminal_tail(bufnr)
  local last_nonblank = 0
  for i = #lines, 1, -1 do
    if lines[i]:gsub('%s', '') ~= '' then
      last_nonblank = i
      break
    end
  end
  -- Anchored on the bottom-most footer, and required right at the bottom, so a
  -- stale prompt is rejected rather than answered blind. Two of its phrases must
  -- match together: a turn ending in a todo list uses the same ☐/☑ glyphs, and
  -- either phrase alone was enough to pop a bogus answer menu.
  local hint
  for i = #lines, 1, -1 do
    if lines[i]:find('to navigate', 1, true) and lines[i]:find('to select', 1, true) then
      hint = i
      break
    end
  end
  if not hint or (last_nonblank - hint) > 8 then
    return nil
  end
  -- The tab line bounds the box on top, carrying a ☐/☑/✔ per question. Take the
  -- nearest above the hint and refuse when there is none, rather than scanning
  -- into scrollback and swallowing stray numbered lines.
  local top
  for i = hint - 1, math.max(1, hint - 60), -1 do
    if
      lines[i]:find('\u{2610}', 1, true)
      or lines[i]:find('\u{2611}', 1, true)
      or lines[i]:find('\u{2714}', 1, true)
    then
      top = i
      break
    end
  end
  if not top then
    return nil
  end

  local options, question_parts = {}, {}
  local option_indent -- set by the first option; the rest must line up with it
  for i = top + 1, hint - 1 do
    local o = parse_option_line(lines[i])
    if o and option_indent and o.indent ~= option_indent then
      o = nil -- deeper (or shallower) than the options: description text
    end
    if o then
      option_indent = option_indent or o.indent
      o.pos = #options + 1
      o.desc = ''
      options[#options + 1] = o
    elseif not is_hr(lines[i]) then
      local text = lines[i]:gsub('^%s+', ''):gsub('%s+$', '')
      if text ~= '' then
        if #options == 0 then
          question_parts[#question_parts + 1] = text -- question text (above the options)
        else
          local last = options[#options]
          last.desc = last.desc == '' and text or (last.desc .. ' ' .. text)
        end
      end
    end
  end
  if #options == 0 then
    return nil
  end
  local multiselect = false
  for _, o in ipairs(options) do
    if o.checked ~= nil then
      multiselect = true
      break
    end
  end
  return {
    multiselect = multiselect,
    question = table.concat(question_parts, ' '),
    options = options,
  }
end

local function claude_win()
  local bufnr = require('claudecode.terminal').get_active_terminal_bufnr()
  if not bufnr then
    return nil
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
      return win
    end
  end
  return nil
end

-- Tests only the command part of "term://{cwd}//{pid}:{command}", so a shell
-- opened inside a .claude/ dir is not matched.
local function is_claude_terminal(buf)
  if vim.bo[buf].buftype ~= 'terminal' then
    return false
  end
  local name = vim.api.nvim_buf_get_name(buf)
  local cmd = name:match ':([^:]*)$' or name
  return cmd:find('claude', 1, true) ~= nil
end

-- Only consulted when no window shows one, so the sweep is off the common tick.
local function any_claude_terminal()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if is_claude_terminal(buf) then
      return true
    end
  end
  return false
end

show_no_focus = function(cmd_args)
  -- claudecode.nvim drops cmd_args when a Claude buffer already exists, so
  -- --resume/--continue would silently re-show the running session.
  if cmd_args and any_claude_terminal() then
    vim.notify(
      'A Claude session is already running -- close it with <leader>ax to start a different one.',
      vim.log.levels.WARN
    )
    return
  end

  local origin = vim.api.nvim_get_current_win()
  require('claudecode.terminal').ensure_visible({}, cmd_args)
  ensure_terminal_autoscroll()
  vim.schedule(function()
    if vim.api.nvim_win_is_valid(origin) and vim.api.nvim_get_current_win() ~= origin then
      vim.api.nvim_set_current_win(origin)
    end
  end)
end

-- claudecode.nvim manages a single terminal and reuses it wherever it runs, so
-- another tree can only be opened once the first is gone.
launch_claude = function(cmd_args, dir)
  if dir then
    if any_claude_terminal() then
      vim.notify(
        'A Claude session is already running -- close it with <leader>ax to start one in another worktree.',
        vim.log.levels.WARN
      )
      return
    end
    worktree_cwd = dir
  end
  show_no_focus(cmd_args)
end

local function toggle_no_focus(cmd_args)
  if claude_win() then
    require('claudecode.terminal').simple_toggle()
  else
    show_no_focus(cmd_args)
  end
end

-- Neovim only auto-follows terminal output in the *focused* window, and terminal
-- buffers fire no on_lines for PTY output -- so poll, and pin every unfocused
-- window to its last line. The focused one is left alone.
local autoscroll_timer = nil

local function stop_terminal_autoscroll()
  if autoscroll_timer then
    autoscroll_timer:stop()
    autoscroll_timer:close()
    autoscroll_timer = nil
  end
end

ensure_terminal_autoscroll = function()
  if autoscroll_timer then
    return
  end
  -- Only nil when out of file descriptors.
  autoscroll_timer = assert(vim.uv.new_timer())
  autoscroll_timer:start(
    250,
    250,
    vim.schedule_wrap(function()
      local cur = vim.api.nvim_get_current_win()
      local found = false
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
          local buf = vim.api.nvim_win_get_buf(win)
          if is_claude_terminal(buf) then
            found = true
            -- Counts as found, but Neovim already follows output there.
            if win ~= cur then
              local last = vim.api.nvim_buf_line_count(buf)
              pcall(vim.api.nvim_win_set_cursor, win, { last, 0 })
            end
          end
        end
      end
      -- Stop rather than wake four times a second for the rest of the session;
      -- anything that shows a terminal calls ensure_terminal_autoscroll().
      if not found and not any_claude_terminal() then
        stop_terminal_autoscroll()
      end
    end)
  )
end

-- True when every remaining non-floating window shows the Claude terminal.
-- Floats (prompt box, popups) are ignored.
local function only_claude_windows_left()
  local claude, other = 0, 0
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative == '' then
      if is_claude_terminal(vim.api.nvim_win_get_buf(win)) then
        claude = claude + 1
      else
        other = other + 1
      end
    end
  end
  return claude > 0 and other == 0
end

local function has_unsaved_changes()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local buftype = vim.bo[buf].buftype
    -- 'acwrite' counts too: oil.nvim stages pending renames in one, and the
    -- `qall!` this guards would discard them without a prompt.
    local writable = buftype == '' or buftype == 'acwrite'
    if vim.api.nvim_buf_is_loaded(buf) and writable and vim.bo[buf].modified then
      return true
    end
  end
  return false
end

-- Claude's half of the shared <leader>a contract, registered at file-body level
-- -- which core/lazy.lua runs while collecting specs, so this lands before load.
require('util.ai').register('claude', {
  send_raw = send_raw,
  term_buf = function()
    return require('claudecode.terminal').get_active_terminal_bufnr()
  end,
  show = function()
    show_no_focus()
  end,
  -- Bracketed paste keeps a multi-line message one message, and the submitting
  -- CR has to land after Claude finishes reading it -- hence the defer.
  submit = function(text)
    local normalized = text:gsub('\r\n', '\n'):gsub('\r', '\n')
    if not send_raw('\27[200~' .. normalized .. '\27[201~') then
      return false
    end
    vim.defer_fn(function()
      send_raw '\r'
    end, 100)
    return true
  end,
  -- Claude's alone: they read Claude's TUI and write its @path#L10-20 syntax.
  -- The box reaches them with `try`, so another backend gets nothing.
  scrape_suggestion = get_claude_suggestion,
  scrape_question = scrape_claude_question,
  mention = build_mention,
  slash_commands = slash_command_names,
  -- OMP implements none of these: its bridge already pushes the cursor's file.
  attach_visual = function()
    vim.cmd 'ClaudeCodeSend'
  end,
  attach_tree = function()
    vim.cmd 'ClaudeCodeTreeAdd'
  end,
  attach_buffer = function()
    vim.cmd 'ClaudeCodeAdd %'
  end,
  -- nvim-side picker over ~/.claude/projects; find_session_cli is the in-TUI one.
  find_session = function()
    pick_claude_session()
  end,
  find_session_cli = function()
    vim.cmd 'ClaudeCode --resume'
  end,
  worktree_continue = continue_in_worktree,
  worktree_session = pick_worktree_session,
  -- claudecode.nvim's MCP diff protocol, which omp.nvim has no equivalent for.
  diff_accept = function()
    vim.cmd 'ClaudeCodeDiffAccept'
  end,
  diff_reject = function()
    vim.cmd 'ClaudeCodeDiffDeny'
  end,
  health = function()
    vim.cmd 'checkhealth claudecode'
  end,
  toggle = function()
    toggle_no_focus()
  end,
  continue = function()
    show_no_focus '--continue'
  end,
  kill = function()
    local bufnr = require('claudecode.terminal').get_active_terminal_bufnr()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end,
  -- <CR> takes the highlighted option, <Esc> cancels the dialog.
  accept = function()
    send_raw '\r'
  end,
  reject = function()
    send_raw '\27'
  end,
  interrupt = function()
    send_raw '`'
  end,
  -- Next question tab; the next <leader><leader> re-scrapes whichever is shown.
  next_tab = function()
    send_raw '\t'
  end,
  -- Shift+Tab is the back-tab sequence ESC [ Z; cycles permission mode.
  cycle_mode = function()
    send_raw '\27[Z'
  end,
  model = function()
    vim.cmd 'ClaudeCodeSelectModel'
  end,
})

return {
  {
    'coder/claudecode.nvim',
    dependencies = { 'folke/snacks.nvim' },
    cmd = {
      'ClaudeCode',
      'ClaudeCodeSend',
      'ClaudeCodeAdd',
      'ClaudeCodeTreeAdd',
      'ClaudeCodeDiffAccept',
      'ClaudeCodeDiffDeny',
      'ClaudeCodeSelectModel',
    },
    -- No `keys`: every mapping is declared in core/keymaps.lua and dispatched
    -- through util.ai, so the `cmd` list above is what lazy loads this on.
    config = function()
      require('claudecode').setup {
        -- Every field is annotated required, but the plugin merges over defaults.
        ---@diagnostic disable-next-line: missing-fields
        terminal = {
          split_width_percentage = 0.45,
          -- worktree_cwd is read once, so later launches are nvim's cwd again.
          -- Must be here: build_config drops per-call overrides defaulting to nil.
          cwd_provider = function()
            local dir = worktree_cwd
            worktree_cwd = nil
            return dir
          end,
        },
      }

      local group = vim.api.nvim_create_augroup('ClaudeTerminal', { clear = true })

      vim.api.nvim_create_autocmd('BufEnter', {
        group = group,
        pattern = 'term://*',
        callback = function(args)
          local term_buf = args.buf
          -- Wait briefly just in case we immediately switch out of the buffer
          vim.defer_fn(function()
            -- args.buf, not 0: the prompt box's float takes focus back inside
            -- these 100ms, so buffer 0 would resolve to it and skip the maps.
            if not vim.api.nvim_buf_is_valid(term_buf) or not is_claude_terminal(term_buf) then
              return
            end
            ensure_terminal_autoscroll()
            -- jk leaves terminal-insert (buffer-local, so other terminals keep jk literal)
            vim.keymap.set(
              't',
              'jk',
              [[<C-\><C-n>]],
              { buffer = term_buf, silent = true, desc = 'escape terminal mode' }
            )
            -- Buffer-scoped, so shells keep <C-h/j/k/l> for line editing.
            for key, dir in pairs { h = 'Left', j = 'Down', k = 'Up', l = 'Right' } do
              vim.keymap.set(
                't',
                '<C-' .. key .. '>',
                [[<C-\><C-n><Cmd>NvimTmuxNavigate]] .. dir .. [[<CR>]],
                { buffer = term_buf, silent = true, desc = 'navigate ' .. dir:lower() }
              )
            end
          end, 100)
        end,
      })

      -- Deferred out of the WinClosed cascade and guarded to fire once; bails if
      -- any file buffer is modified.
      local quitting = false
      vim.api.nvim_create_autocmd('WinClosed', {
        group = group,
        callback = function()
          if quitting then
            return
          end
          vim.defer_fn(function()
            if quitting or not only_claude_windows_left() or has_unsaved_changes() then
              return
            end
            quitting = true
            vim.cmd 'noautocmd qall!'
          end, 50)
        end,
      })
    end,
  },
}
