-- Claude Code integration. Most of this is a prompt box you pop over your file:
-- it composes a message, completes @file and slash commands, previews Claude's
-- suggested reply, and can answer an AskUserQuestion prompt by option key --
-- all without focusing the terminal.

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

-- vim.json.decode maps JSON null to vim.NIL, which is *truthy* -- so plain
-- `t.a and t.a.b` throws on `"a":null`. Both readers below run outside any pcall
-- that would catch it, and one bad transcript line would take the whole picker
-- down rather than skipping that line.
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

-- Claude keys each project's sessions under ~/.claude/projects by its path:
-- non-alphanumerics become '-', and a key over 200 characters is cut there with
-- a hash suffix. Mirrors the CLI exactly; a key one character off finds nothing.
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

-- <leader>af re-reads a title per transcript, and transcripts run to tens of
-- MB, so: cache on file identity (mtime+size), parse only the head of the file
-- -- both the ai-title and the first user message live near the top -- and stop
-- as soon as both are in hand. The old version json-decoded every line of every
-- session on every open.
local TITLE_SCAN_BYTES = 512 * 1024
local title_cache = {}

local function parse_session_title(chunk)
  local ai_title, first_msg = nil, ''
  for line in chunk:gmatch '[^\n]+' do
    -- The final line of a truncated chunk is normally incomplete JSON; the
    -- decode simply fails and it is skipped.
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

-- Forward declaration: assigned lower in the file, but called by show_no_focus
-- above that assignment -- including on the `show` op's path, which is how the
-- shared prompt box starts the terminal with autoscroll too.
local ensure_terminal_autoscroll

-- Worktrees this repo no longer has, but whose sessions are still on disk:
-- <leader>wwm and <leader>wwd remove the directory, the transcripts under
-- ~/.claude/projects outlive it. Matched by key prefix, newest first -- the
-- encoding is lossy, so the real path cannot be recovered from a key.
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

-- Where a session's project sits relative to nvim's cwd. 'here' and 'worktree'
-- share a rank -- both are this repo, and plain recency is the more useful order
-- between them -- but they keep different path colours. Telescope's default
-- strategy draws entry 1 at the bottom of the list, next to the prompt, so rank
-- 1 is what you land on and the greyed-out rest of the world stacks above it.
local ORIGIN_RANK = { here = 1, worktree = 1, other = 2 }

-- Green for this directory, blue for another worktree of the same repo; the
-- title stays default-white for both. An 'other' row is painted flat grey
-- instead and never reaches this table.
local ORIGIN_PATH_HL = { here = 'Comment', worktree = 'Directory' }

-- The ~/.claude/projects keys belonging to a worktree of the repo nvim is in --
-- the live ones git knows about, plus the removed ones whose transcripts
-- outlived the directory. Outside a repo there are none, and the picker just
-- falls back to here-vs-elsewhere.
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

-- ---------------------------------------------------------------------------
-- Session preview pane.
--
-- A transcript is the whole conversation and runs to megabytes, while the
-- previewer re-fires on every cursor move -- so this never reads a file whole.
-- It takes a tail just big enough to fill the preview window, and grows the bite
-- only when a chunk turns out to be mostly tool payloads with little to show.
-- ---------------------------------------------------------------------------

local PREVIEW_TAIL_BYTES = 128 * 1024
local PREVIEW_MAX_BYTES = 4 * 1024 * 1024

-- How much of that tail is kept in the preview buffer. More than one windowful,
-- so <C-u> scrolls back into real history rather than into blank lines, but
-- still bounded -- the buffer is repainted on every cursor move in the list.
local PREVIEW_MAX_ROWS = 500
local preview_cache = {}

-- The last `bytes` of a file, minus the partial line at the cut. Also reports
-- whether the read reached back to the start, which is the signal to stop
-- growing.
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

-- Tool calls are shown as one line, so pick the one argument that says what the
-- call was actually about -- the command, the file, the pattern.
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

-- One transcript record -> zero or more preview rows, appended to `rows`.
-- Skipped: sidechains (a subagent's own turns, interleaved with the main
-- thread), tool results (bulk, and the call above already says what ran), and
-- thinking blocks.
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
          -- extract_text also collapses a pasted wall of text to one line and
          -- drops the local-command caveat blocks entirely.
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
    -- One buffer per transcript, reused as you move back and forth over the
    -- list, instead of a new scratch buffer (and a new markdown parse) per move.
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
        -- Newest last, and deeper than the window is tall so there is something
        -- to scroll back into.
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
      -- Markdown for the assistant's own formatting (fences, lists); extmarks on
      -- top for the turn markers, which outrank treesitter on priority. Guarded
      -- because setting it re-fires every FileType autocmd on a reused buffer.
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
        -- Open on the newest line, at the bottom of the window. This has to wait
        -- a tick: on a first visit telescope hands the freshly built buffer to
        -- the preview window from a scheduled callback that has not run yet, so
        -- a cursor set here would scroll the *previous* entry's buffer and the
        -- swap would then drop us back at line 1. Queued after theirs, it sticks.
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

-- Session picker. Bare (<leader>af) it lists every project's sessions;
-- `opts.key` narrows that to one project key and `opts.cwd` is where Claude then
-- runs, which for a deleted worktree is the repo it was folded back into.
-- Sessions under another key are dimmed but still resumable: `claude --resume
-- <id>` falls back to scanning ~/.claude/projects for that id.
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

  -- This repo's sessions -- cwd and worktrees together -- then everyone else's;
  -- newest first within each group.
  table.sort(entries, function(a, b)
    local ra, rb = ORIGIN_RANK[a.origin], ORIGIN_RANK[b.origin]
    if ra ~= rb then
      return ra < rb
    end
    return a.mtime > b.mtime
  end)

  -- After the sort, so it stays pinned above the sessions: a worktree nobody has
  -- opened yet has none, and the picker would otherwise be a dead end.
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
            -- An unrelated project is dimmed whole; anything from this repo keeps
            -- a readable title and says which tree it came from in the path.
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

-- Pick one of this repo's worktrees -- live ones first, then deleted ones that
-- still have sessions -- and hand it to `cb`. Claude runs with its cwd in the
-- worktree (for a deleted one, in the repo) while nvim's cwd stays put.
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

-- <leader>aw: pick a worktree and pick up its last session. Nothing to continue
-- in one nobody has opened, so start fresh there instead; and `--continue` only
-- looks at the current directory, so a deleted worktree's session needs its id.
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

-- Write raw bytes straight to the running Claude terminal's PTY without moving
-- focus, so its prompts can be answered from whatever buffer you're in. Returns
-- false (and notifies) when no live Claude terminal/channel is available.
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

-- ---------------------------------------------------------------------------
-- Claude's half of the shared prompt box (util/ai/prompt.lua).
--
-- The Claude *terminal* autocompletes @file mentions and /slash commands from
-- inside its TUI, which nvim can't observe, so the box reimplements both. The
-- @file half is backend-agnostic and lives with the box; this is the command
-- list it asks for, published below as the `slash_commands` op.
-- ---------------------------------------------------------------------------

-- Claude's built-in slash commands (not backed by files). Project/user command
-- and skill files are discovered dynamically alongside these.
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

-- Walked fresh on each call: util/ai/prompt.lua caches the result for the
-- lifetime of one box, which is where the cache belonged all along. A command
-- file added mid-session still shows up the next time you open one.
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
  -- Project- and user-level command files. A nested file becomes a namespaced
  -- command (commands/git/commit.md -> git:commit), matching Claude's convention.
  local dirs = { vim.fn.getcwd() .. '/.claude/commands', vim.fn.expand '~/.claude/commands' }
  for _, dir in ipairs(dirs) do
    for _, f in ipairs(vim.fn.glob(dir .. '/**/*.md', false, true)) do
      local rel = f:sub(#dir + 2, -4) -- strip "<dir>/" prefix and ".md" suffix
      add((rel:gsub('/', ':')))
    end
  end
  return names
end

-- Scrape Claude's suggested next reply (the greyed text it renders in its input
-- box) out of the terminal buffer. The box is delimited by two horizontal-rule
-- lines; the line between them holds the "❯ " prompt marker + suggestion.
-- Returns nil when there's no terminal, no box, or the input is empty. NOTE:
-- there is no per-cell colour API for terminals, so this can't tell a grey
-- *suggestion* from text you actually typed into the terminal -- it assumes the
-- terminal input is untouched, which holds when you pop the box open to answer.
-- Both scrapers below anchor within a few lines of the terminal's bottom and
-- never look back further than ~70 (the question scraper's `hint - 60` bound),
-- but a terminal carries 10k lines of scrollback by default. Fetch a tail with
-- room to spare rather than copying the whole buffer into Lua on every
-- <leader><leader> -- which happened twice per press when no question was found.
-- Every index below is relative to this tail, which is why the bound matters.
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
  -- The live input box is always at the very bottom of the terminal, with only
  -- a few hint lines below it. Find the last non-blank line so stale horizontal
  -- rules from earlier scrollback can be rejected: without this, two old
  -- separators get mistaken for the box and their contents returned as a bogus
  -- "suggestion" -- which then (per the prompt-box gate) wrongly suppresses the
  -- @-mention prefill.
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
  -- Drop the prompt marker from the first line, right-trim every line's box
  -- padding, then trim the joined block.
  content[1] = content[1]:gsub('^%s*', ''):gsub('^\u{276f}%s?', ''):gsub('^>%s?', '')
  for i, l in ipairs(content) do
    content[i] = (l:gsub('%s+$', ''))
  end
  -- Claude pads its (empty) input box with a non-breaking space (U+00A0),
  -- which Lua's %s does not match -- normalize it to a plain space first, else
  -- a blank box scrapes to "\u{00A0}" and is mistaken for a real suggestion
  -- (which then wrongly suppresses the @-mention prefill).
  local text = table.concat(content, '\n'):gsub('\u{00a0}', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  if text == '' then
    return nil
  end
  return text
end

-- Build the Claude @-mention text for a visual line range in the given buffer,
-- e.g. "@lua/config/claude.lua#L10-20" (or "#L10" for a single line). The path
-- is relative to cwd and the line numbers are 1-indexed, matching Claude's own
-- mention format. Returns nil for non-file or unnamed buffers.
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

-- ---------------------------------------------------------------------------
-- Answering Claude's AskUserQuestion prompts from a selection menu.
--
-- When Claude asks structured questions (its tabbed multiple-choice UI) the
-- centered text box isn't useful. We can't read the pending question from the
-- session transcript -- Claude only flushes an AskUserQuestion to disk *after*
-- it's answered -- so instead we scrape it live from the terminal buffer, the
-- same trick get_claude_suggestion() uses for the input box. The prompt renders
-- as:
--
--   ←  ☐ Fruit  ☐ Colors  ✔ Submit  →      <- tab bar (one tab per question + Submit)
--   Which fruit do you prefer?           <- the current question
--   ❯ 1. Apple                           <- ❯ marks the highlighted option
--        A crisp red or green fruit.     <- option description (indented)
--     2. Banana
--   ...
--   Enter to select · Tab/Arrow keys to navigate · Esc to cancel
--
-- Multi-select questions render a "[ ]" / "[x]" checkbox per option. The options
-- are numbered, and pressing an option's number selects it (single-select) or
-- toggles its checkbox (multi-select) -- the only input that proved reliable
-- over the PTY (synthetic arrow keys did nothing). So <leader><leader> scrapes
-- whatever tab is currently shown into a Telescope menu and, on pick, presses
-- the chosen option's number key(s). <leader>a; sends Tab to move to the next
-- tab (the menu then re-scrapes it), and <leader>j (Enter) submits from Submit.
-- ---------------------------------------------------------------------------

-- A horizontal-rule line (───...), used to bound the box on screen.
local function is_hr(s)
  local stripped, n = s:gsub('\u{2500}', '')
  return n >= 10 and stripped:gsub('%s', '') == ''
end

-- Parse one option line. Returns { num, label, checked } or nil. `checked` is
-- nil for single-select, true/false for a "[x]"/"[ ]" checkbox.
local function parse_option_line(line)
  -- Column the number starts at, with the ❯ highlight marker measured as the
  -- whitespace it replaces so the highlighted row lines up with the others.
  -- The scrape loop uses this to reject numbered lines that sit deeper than the
  -- options -- i.e. a numbered list inside an option's description.
  local prefix = line:match '^%s*\u{276f}%s*' or line:match '^%s*' or ''
  local indent = vim.fn.strdisplaywidth(prefix)

  local body = line:gsub('^%s*\u{276f}%s*', ''):gsub('^%s*', '')
  local num, rest = body:match '^(%d+)%.%s+(.*)$'
  if not num then
    return nil
  end
  -- Only a genuine checkbox counts. `1. [P0] Fix it` is a label that happens to
  -- start with a bracket: treating it as checked flipped the whole question to
  -- multi-select, and choice_keys (util/ai/prompt.lua) then pressed the *other*
  -- options' numbers
  -- (their state differed) while skipping the one actually picked.
  local inside, label = rest:match '^%[([^%]]*)%]%s*(.*)$'
  if inside ~= nil then
    local mark = inside:gsub('%s', '')
    if mark == '' or mark == 'x' or mark == 'X' or mark == '\u{2713}' or mark == '\u{2714}' then
      return { num = tonumber(num), label = label, checked = mark ~= '', indent = indent }
    end
  end
  return { num = tonumber(num), label = rest, indent = indent }
end

-- Scrape the AskUserQuestion prompt out of the live terminal. Returns
-- { multiselect, question, options = { {num, pos, label, desc, checked} } }
-- for the currently-shown tab, or nil when no such prompt is on screen.
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
  -- The signature footer, unique to the selection prompt. Anchor on the
  -- bottom-most one -- earlier renders leave stale copies higher in scrollback.
  -- Require it right at the bottom so a stale prompt (no live question) is
  -- rejected rather than answered blind.
  -- Claude renders this footer as one line carrying every part:
  -- `Enter to select · ↑/↓ to navigate · Esc to cancel`. Requiring two of those
  -- phrases together, rather than either alone, is what keeps ordinary output
  -- from matching -- a turn ending in a todo list (rendered with the same ☐/☑
  -- glyphs the box header uses) plus any prose mentioning navigation used to be
  -- enough to pop a bogus answer menu.
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
  -- The header/tab line is the box's top boundary. It carries a checkbox glyph
  -- per question (☐/☑/✔) -- present both for single-question prompts ("☐ Foo")
  -- and multi-question tab bars ("← ☐ A  ☐ B  ✔ Submit →"). Take the nearest one
  -- above the hint; refuse (fall back to the prompt box) when there's none rather
  -- than scanning up into scrollback and swallowing stray numbered lines.
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

-- Detect the Claude Code terminal by the command in its term:// buffer name
-- ("term://{cwd}//{pid}:{command}") -- test the command part only so a plain
-- shell opened inside a .claude/ dir isn't matched.
local function is_claude_terminal(buf)
  if vim.bo[buf].buftype ~= 'terminal' then
    return false
  end
  local name = vim.api.nvim_buf_get_name(buf)
  local cmd = name:match ':([^:]*)$' or name
  return cmd:find('claude', 1, true) ~= nil
end

-- Any Claude terminal at all, shown or hidden. Only consulted when no window is
-- displaying one, so the buffer sweep is not part of the common tick.
local function any_claude_terminal()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if is_claude_terminal(buf) then
      return true
    end
  end
  return false
end

show_no_focus = function(cmd_args)
  -- claudecode.nvim drops cmd_args whenever a Claude terminal buffer already
  -- exists: terminal.lua's ensure_terminal_visible_no_focus returns early when
  -- one is visible, and the Snacks provider's open() reuses a hidden one without
  -- looking at the command at all. So --resume/--continue would silently just
  -- re-show the running session. Say so instead of appearing to work.
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

-- Start Claude, optionally with its process cwd in `dir`. claudecode.nvim
-- manages a single terminal and reuses it wherever it already runs, so another
-- tree can only be opened once the first is gone.
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
-- buffers don't fire nvim_buf_attach on_lines for PTY output -- so while you edit
-- elsewhere the Claude terminal streams past the bottom of its viewport. Poll on
-- a timer and keep any UNFOCUSED window showing a Claude terminal pinned to its
-- last line. The focused window is left alone (Neovim follows it natively, and
-- you may be scrolling its history there).
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
  -- Only ever nil if the process is out of file descriptors.
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
            -- The focused window still counts as "found", but Neovim already
            -- follows output there and you may be reading its history.
            if win ~= cur then
              local last = vim.api.nvim_buf_line_count(buf)
              pcall(vim.api.nvim_win_set_cursor, win, { last, 0 })
            end
          end
        end
      end
      -- Claude is gone (<leader>ax, or the CLI exited): stop instead of waking
      -- four times a second for the rest of the session. Anything that shows a
      -- terminal again calls ensure_terminal_autoscroll().
      if not found and not any_claude_terminal() then
        stop_terminal_autoscroll()
      end
    end)
  )
end

-- Claude terminal behavior: enable jk-to-escape
-- and tmux-style split navigation from terminal-insert (buffer-local), and keep
-- unfocused windows scrolled to the newest output.
-- True when the only non-floating windows left (across all tabpages) show the
-- Claude terminal -- i.e. every editing window is gone and Claude is all that
-- remains. Floating windows (prompt box, popups) are ignored.
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
    -- 'acwrite' counts as much as a real file buffer: oil.nvim stages pending
    -- renames and deletes in one and marks it modified, and the `qall!` this
    -- guards would discard them without a prompt.
    local writable = buftype == '' or buftype == 'acwrite'
    if vim.api.nvim_buf_is_loaded(buf) and writable and vim.bo[buf].modified then
      return true
    end
  end
  return false
end

-- The operations the shared <leader>a keys dispatch to. Those keys are declared
-- once, in core/keymaps.lua, and resolve the active backend at press time; this
-- is Claude's half of that contract. Everything here is Claude-specific and
-- stays so -- util/ai/init.lua deliberately knows none of it. See the AI
-- section of README.md.
--
-- This runs at file-body level, which core/lazy.lua executes for every module
-- under lua/plugins/ while collecting specs, so the table is registered well
-- before claudecode.nvim itself loads.
require('util.ai').register('claude', {
  send_raw = send_raw,
  term_buf = function()
    return require('claudecode.terminal').get_active_terminal_bufnr()
  end,
  show = function()
    show_no_focus()
  end,
  -- How a composed prompt reaches the TUI. Bracketed paste keeps a multi-line
  -- message one message; the CR that submits it has to land after Claude has
  -- finished reading the paste, hence the defer. Returns false when the channel
  -- is gone, which is what stops the box tearing itself down over a failed send.
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
  -- The two scrapers and the mention format are Claude's alone: they read
  -- Claude's TUI and write Claude's @path#L10-20 syntax. util/ai/prompt.lua
  -- reaches them with `try`, so a backend without them gets nothing rather than
  -- these. See the AI section of README.md.
  scrape_suggestion = get_claude_suggestion,
  scrape_question = scrape_claude_question,
  mention = build_mention,
  slash_commands = slash_command_names,
  -- Attaching context by hand. OMP implements none of these: its bridge is
  -- already pushing the cursor's file and line, so there is nothing to attach.
  attach_visual = function()
    vim.cmd 'ClaudeCodeSend'
  end,
  attach_tree = function()
    vim.cmd 'ClaudeCodeTreeAdd'
  end,
  attach_buffer = function()
    vim.cmd 'ClaudeCodeAdd %'
  end,
  -- The nvim-side picker over ~/.claude/projects; find_session_cli is Claude's
  -- own in-TUI one. OMP has only the latter, and points both at it.
  find_session = function()
    pick_claude_session()
  end,
  find_session_cli = function()
    vim.cmd 'ClaudeCode --resume'
  end,
  worktree_continue = continue_in_worktree,
  worktree_session = pick_worktree_session,
  -- claudecode.nvim's MCP diff protocol. omp.nvim is a context bridge with no
  -- equivalent, so these stay Claude-only.
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
  -- Next question tab in an AskUserQuestion prompt; the next <leader><leader>
  -- re-scrapes whichever tab is then shown.
  next_tab = function()
    send_raw '\t'
  end,
  -- Shift+Tab is the terminal back-tab sequence: ESC [ Z. Cycles permission
  -- mode in Claude, reasoning effort in OMP.
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
    -- No `keys` at all: every <leader>a mapping is declared once in
    -- core/keymaps.lua and dispatched through util.ai, so a key can never fire
    -- at Claude while the tabline says another backend is active. The `cmd`
    -- list above is what lazy loads this on, alongside util.ai's own
    -- `lazy.load` when an op is first called.
    config = function()
      require('claudecode').setup {
        -- Every field of ClaudeCodeTerminalConfig is annotated as required; the
        -- plugin merges what you pass over its own defaults.
        ---@diagnostic disable-next-line: missing-fields
        terminal = {
          split_width_percentage = 0.45,
          -- Where the Claude process starts: the worktree maps park a path in
          -- worktree_cwd, read once so later launches are nvim's cwd again. Must
          -- be here -- build_config drops per-call overrides that default to nil.
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
            -- args.buf rather than 0: the prompt box (util/ai/prompt.lua) starts
            -- the terminal and its float takes focus back well inside these 100ms,
            -- so resolving buffer 0 here would inspect the float and skip the maps.
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
            -- tmux-style split navigation from terminal-insert, scoped to this
            -- buffer so shells keep <C-h/j/k/l> for their own line editing.
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

      -- When the last editing window is closed and only the Claude terminal remains,
      -- quit Neovim. Deferred to a clean tick (out of the WinClosed cascade) and
      -- guarded so it fires once; bail if any file buffer is modified so unsaved work
      -- is never lost.
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
