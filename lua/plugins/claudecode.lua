-- Claude Code integration. Most of this is a prompt box you pop over your file:
-- it composes a message, completes @file and slash commands, previews Claude's
-- suggested reply, and can answer an AskUserQuestion prompt by option key --
-- all without focusing the terminal.

-- Assigned further down; the prompt box calls them before they are defined.
local ensure_terminal_autoscroll
local show_no_focus

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

local function build_path_map()
  local path_map = {}
  local cj = io.open(vim.fn.expand '~/.claude.json', 'r')
  if cj then
    local ok, data = pcall(vim.json.decode, cj:read '*a')
    cj:close()
    if ok and data.projects then
      local home = vim.fn.expand '~'
      for actual_path, _ in pairs(data.projects) do
        local display = actual_path:gsub('^' .. vim.pesc(home), '~')
        path_map[actual_path:gsub('[/.]', '-')] = display
      end
    end
  end
  return path_map
end

local function read_session_title(session_file)
  local sf = io.open(session_file, 'r')
  if not sf then
    return ''
  end
  local ai_title, first_msg = nil, ''
  for line in sf:lines() do
    local ok, entry = pcall(vim.json.decode, line)
    if ok then
      if entry.type == 'ai-title' and entry.aiTitle then
        ai_title = entry.aiTitle
      elseif first_msg == '' and entry.type == 'user' then
        local content = entry.message and entry.message.content
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
    end
  end
  sf:close()
  return (ai_title or first_msg):gsub('\n', ' '):sub(1, 80)
end

-- Forward declaration: defined lower in the file, used by the session picker.
local show_no_focus

-- Forward declaration: assigned lower in the file. Declared above
-- open_prompt_input (not just above show_no_focus) so the prompt box can start
-- the terminal with autoscroll too.
local ensure_terminal_autoscroll

local function pick_claude_session()
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'

  local path_map = build_path_map()
  local sessions_base = vim.fn.expand '~/.claude/projects'
  local cwd_encoded = vim.fn.getcwd():gsub('[/.]', '-')
  local entries = {}

  for _, project_dir in ipairs(vim.fn.glob(sessions_base .. '/*', false, true)) do
    local encoded_name = vim.fn.fnamemodify(project_dir, ':t')
    local display_project = path_map[encoded_name] or encoded_name

    for _, session_file in ipairs(vim.fn.glob(project_dir .. '/*.jsonl', false, true)) do
      table.insert(entries, {
        session_id = vim.fn.fnamemodify(session_file, ':t:r'),
        project = display_project,
        summary = read_session_title(session_file),
        mtime = vim.fn.getftime(session_file),
        loadable = encoded_name == cwd_encoded,
      })
    end
  end

  table.sort(entries, function(a, b)
    if a.loadable ~= b.loadable then
      return a.loadable
    end
    return a.mtime > b.mtime
  end)

  pickers
    .new({}, {
      prompt_title = 'Claude Sessions',
      finder = finders.new_table {
        results = entries,
        entry_maker = function(entry)
          local make_display = function(e)
            local title = e.summary ~= '' and e.summary or '(no message)'
            local path_str = '  ' .. e.project
            local time_str = '  ' .. relative_time(e.mtime)
            local display = title .. path_str .. time_str
            if not e.loadable then
              return display, { { { 0, #display }, 'LspInlayHint' } }
            end
            return display,
              {
                { { #title, #title + #path_str }, 'Comment' },
                { { #title + #path_str, #display }, 'Special' },
              }
          end
          return {
            value = entry.session_id,
            display = make_display,
            ordinal = entry.summary .. ' ' .. entry.project,
            summary = entry.summary,
            project = entry.project,
            mtime = entry.mtime,
            loadable = entry.loadable,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr, map)
        local function resume_session()
          local selection = action_state.get_selected_entry()
          if selection and not selection.loadable then
            vim.notify(
              'Session belongs to ' .. selection.project .. ' — not resumable from this directory.',
              vim.log.levels.WARN
            )
            return
          end
          actions.close(prompt_bufnr)
          if selection then
            show_no_focus('--resume ' .. selection.value)
          end
        end
        map('i', '<CR>', resume_session)
        map('n', '<CR>', resume_session)
        return true
      end,
    })
    :find()
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
-- Completion inside the centered prompt box (`<leader><leader>`).
--
-- The Claude *terminal* autocompletes @file mentions and /slash commands from
-- inside its TUI, which nvim can't observe. This reimplements those same two
-- completions as a buffer-local nvim-cmp source so <Tab> works in the float too.
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

-- Native replacement for the old nvim-cmp source: completes @file paths and
-- /commands inside the prompt buffer. nvim-cmp is not part of this config, so
-- this drives the built-in popup menu with vim.fn.complete() instead.
--
-- Two things about the built-in menu make a *path* different from a keyword, and
-- both are why this is re-driven from a TextChanged autocmd (see
-- attach_completion) rather than only from <C-n>:
--
--  * the menu ends as soon as you type a character outside 'iskeyword', and "/"
--    is exactly that -- so a path could never be typed past its first slash;
--  * complete() takes a *static* candidate list, so the list computed for "@lua"
--    still holds the parent's entries once you reach "@lua/" and would never
--    offer what is inside the directory.
--
-- Recomputing from scratch on every typed character fixes both, and restores the
-- as-you-type menu the nvim-cmp source used to give.
local function prompt_complete()
  local before = vim.api.nvim_get_current_line():sub(1, vim.fn.col '.' - 1)

  -- /command: only when the line is just a leading slash token.
  if before:match '^%s*/%S*$' then
    -- The match above guarantees a slash token, so find cannot come back nil.
    local start = assert(before:find '/%S*$')
    local items = {}
    for _, name in ipairs(slash_command_names()) do
      items[#items + 1] = { word = '/' .. name, kind = 'f' }
    end
    vim.fn.complete(start, items)
    return true
  end

  -- @file: complete the last @token as a path relative to cwd.
  local at = before:find '@%S*$'
  if at then
    local partial = before:sub(at + 1)
    local items = {}
    for _, path in ipairs(vim.fn.getcompletion(partial, 'file')) do
      items[#items + 1] = { word = '@' .. path, kind = path:sub(-1) == '/' and 'd' or 'f' }
    end
    vim.fn.complete(at, items)
    return true
  end
  return false
end

-- Keep the menu in step with what you type inside an @path or /command token.
-- InsertCharPre fires only for a literally typed character and never for the
-- text the menu itself inserts as you move through it, so it is what separates a
-- keystroke from a selection -- without it, <C-n> would insert a match, retrigger
-- this, and rebuild the menu out from under the cursor. TextChangedP is needed
-- alongside TextChangedI because only it fires while the menu is open.
local function attach_completion(buf)
  local typed = false
  vim.api.nvim_create_autocmd('InsertCharPre', {
    buffer = buf,
    callback = function()
      typed = true
    end,
  })
  vim.api.nvim_create_autocmd({ 'TextChangedI', 'TextChangedP' }, {
    buffer = buf,
    callback = function()
      if not typed then
        return
      end
      typed = false
      -- Swallow errors rather than let a bad keystroke report on every
      -- character typed into the box.
      pcall(prompt_complete)
    end,
  })
end

local ghost_ns = vim.api.nvim_create_namespace 'claude_prompt_ghost'

-- Scrape Claude's suggested next reply (the greyed text it renders in its input
-- box) out of the terminal buffer. The box is delimited by two horizontal-rule
-- lines; the line between them holds the "❯ " prompt marker + suggestion.
-- Returns nil when there's no terminal, no box, or the input is empty. NOTE:
-- there is no per-cell colour API for terminals, so this can't tell a grey
-- *suggestion* from text you actually typed into the terminal -- it assumes the
-- terminal input is untouched, which holds when you pop the box open to answer.
local function get_claude_suggestion()
  local ok, term = pcall(require, 'claudecode.terminal')
  if not ok then
    return nil
  end
  local bufnr = term.get_active_terminal_bufnr()
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
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

local context_ns = vim.api.nvim_create_namespace 'claude_prompt_context'

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

-- Re-paint the visual selection in the origin buffer while the prompt float is
-- open, so you can still see what you're asking Claude about. `vsel` is a
-- 1-indexed {start_line, end_line} range (linewise) or nil. Returns a function
-- that clears the highlight.
local function highlight_origin_selection(buf, vsel)
  if not vsel or not vim.api.nvim_buf_is_valid(buf) then
    return function() end
  end
  local last = vim.api.nvim_buf_get_lines(buf, vsel[2] - 1, vsel[2], false)[1] or ''
  pcall(vim.api.nvim_buf_set_extmark, buf, context_ns, vsel[1] - 1, 0, {
    end_row = vsel[2] - 1,
    end_col = #last,
    hl_group = 'Visual',
    hl_eol = true,
  })
  return function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, context_ns, 0, -1)
    end
  end
end

local function open_prompt_input()
  -- Capture the visual selection you're launching from BEFORE the float takes
  -- focus. It becomes an @-mention *prefilled* into the box (see build_mention),
  -- so it reaches Claude only if you actually submit -- escaping the box leaves
  -- nothing stray behind in Claude's terminal. The selection is also re-painted
  -- so it stays visible while you type. A plain <leader><leader> with no
  -- selection prefills nothing -- Claude reads files on demand.
  local origin_buf = vim.api.nvim_get_current_buf()
  local origin_mode = vim.fn.mode()
  local vsel
  if origin_mode == 'v' or origin_mode == 'V' or origin_mode == '\22' then
    local a, b = vim.fn.getpos 'v', vim.fn.getpos '.'
    vsel = { math.min(a[2], b[2]), math.max(a[2], b[2]) } -- 1-indexed line range
  end
  local clear_origin_highlight = highlight_origin_selection(origin_buf, vsel)

  -- Whether a Claude terminal needs starting (none running yet). The actual
  -- start is deferred to the end of this function: opening it here would steal
  -- focus/redraw from the float and the prompt box would never appear.
  local need_terminal = not require('claudecode.terminal').get_active_terminal_bufnr()

  local width = math.min(100, math.max(40, math.floor(vim.o.columns * 0.7)))
  local max_height = math.max(1, math.floor(vim.o.lines * 0.5))
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.b[buf].claude_prompt = true
  local suggestion = get_claude_suggestion()
  -- A visual selection prefills its @-mention (with line range) so it rides
  -- along with your prompt and is sent only on submit. With no selection nothing
  -- is prefilled: the suggested-reply ghost keeps its normal behavior, and a
  -- whole file is never force-fed into Claude's context on every prompt.
  local prefill
  if vsel then
    local mention = build_mention(origin_buf, vsel)
    if mention then
      prefill = mention .. ' '
      suggestion = nil -- the prefilled selection replaces the suggested-reply ghost
    end
  end
  local suggestion_lines = suggestion and vim.split(suggestion, '\n')

  -- The *initial* ghost should be Claude's suggestion; everything after the
  -- first keystroke should come from llama.vim as usual. But llama has no
  -- per-buffer guard -- left alone it renders its own FIM ghost (green) and
  -- rebinds <Tab> on the empty buffer, clobbering Claude's suggestion. So
  -- suppress llama while the box is empty, then re-enable it once you type.
  -- Neovim decides whether the completion menu fits below the cursor from
  -- 'pumheight' rather than the real candidate count, and this box sits at the
  -- vertical centre -- so at the config-wide 12 the menu flips *above* the cursor
  -- on a 24-row terminal and lands on the box, hiding the line being typed. 8
  -- keeps it below from 24 rows up. Restored on close, so completion everywhere
  -- else keeps the taller menu.
  local saved_pumheight = vim.o.pumheight
  vim.o.pumheight = math.min(saved_pumheight, 8)
  local function restore_pumheight()
    vim.o.pumheight = saved_pumheight
  end

  local llama_on = vim.fn.exists '#llama' == 1
  local llama_suppressed = false
  local function suppress_llama()
    if llama_on and not llama_suppressed then
      llama_suppressed = true
      pcall(vim.fn['llama#disable'])
    end
  end
  local function restore_llama()
    if llama_on and llama_suppressed then
      llama_suppressed = false
      pcall(vim.fn['llama#enable'])
    end
  end
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = 1,
    row = math.floor((vim.o.lines - 1) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' Claude ',
    title_pos = 'center',
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true

  -- Suppress llama *before* installing our keymaps: llama#disable() unmaps
  -- <buffer> <Tab>, which would otherwise wipe the mapping we set below.
  if suggestion then
    suppress_llama()
  end

  local function fit_height()
    if not vim.api.nvim_win_is_valid(win) then
      return
    end
    local rows = 0
    for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
      rows = rows + math.max(1, math.ceil(vim.fn.strdisplaywidth(line) / width))
    end
    rows = math.max(1, math.min(rows, max_height))
    vim.api.nvim_win_set_config(win, {
      relative = 'editor',
      width = width,
      height = rows,
      row = math.floor((vim.o.lines - rows) / 2),
      col = math.floor((vim.o.columns - width) / 2),
    })
  end
  local function buffer_is_empty()
    local l = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    return #l == 1 and l[1] == ''
  end

  -- Preview Claude's suggested reply as greyed ghost text while the box is empty.
  local function render_ghost()
    vim.api.nvim_buf_clear_namespace(buf, ghost_ns, 0, -1)
    -- Guarding on the split rather than on `suggestion` -- the two are set
    -- together, and this is the one that gets indexed below.
    local slines = suggestion_lines
    if not (slines and buffer_is_empty()) then
      return
    end
    local ext = { virt_text = { { slines[1], 'Comment' } }, virt_text_pos = 'inline', hl_mode = 'combine' }
    if #slines > 1 then
      ext.virt_lines = {}
      for i = 2, #slines do
        ext.virt_lines[#ext.virt_lines + 1] = { { slines[i], 'Comment' } }
      end
    end
    vim.api.nvim_buf_set_extmark(buf, ghost_ns, 0, 0, ext)
  end

  -- TextChangedP belongs here alongside TextChangedI: only it fires while the
  -- completion menu is open, and the menu now stays open for as long as you are
  -- typing a path. Without it the box freezes at whatever height it had when the
  -- menu appeared, so a prompt that wraps past that height scrolls out of sight
  -- while you type. Resizing the float does not disturb the open menu.
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'TextChangedP' }, {
    buffer = buf,
    callback = function()
      fit_height()
      render_ghost()
      if not buffer_is_empty() then
        restore_llama()
      end
    end,
  })
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = buf,
    once = true,
    callback = function()
      restore_llama()
      restore_pumheight()
    end,
  })

  local closed = false
  local function finish(send)
    if closed then
      return
    end
    closed = true
    clear_origin_highlight()
    restore_pumheight()
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    -- Closing the float from insert mode leaves the global insert state on, so
    -- focus returns to your buffer still in insert -- force normal mode back.
    vim.schedule(function()
      vim.cmd 'stopinsert'
    end)
    if send and text:gsub('%s', '') ~= '' then
      local normalized = text:gsub('\r\n', '\n'):gsub('\r', '\n')
      send_raw('\27[200~' .. normalized .. '\27[201~')
      vim.defer_fn(function()
        send_raw '\r'
      end, 100)
    end
  end
  -- Normal-mode controls are always available.
  vim.keymap.set('n', '<CR>', function()
    finish(true)
  end, { buffer = buf })
  vim.keymap.set('n', '<Esc>', function()
    finish(false)
  end, { buffer = buf })
  vim.keymap.set('n', 'q', function()
    finish(false)
  end, { buffer = buf })

  -- Insert-mode: <CR> submits, <Esc> cancels. Buffer-local so they win over
  -- cmp's global <CR>=confirm mapping while the completion menu is open.
  vim.keymap.set('i', '<CR>', function()
    finish(true)
  end, { buffer = buf })
  vim.keymap.set('i', '<Esc>', function()
    finish(false)
  end, { buffer = buf })

  -- Replace the empty prompt with Claude's suggested reply, cursor at its end.
  local function accept_suggestion()
    local slines = suggestion_lines
    if not (slines and buffer_is_empty()) then
      return false
    end
    vim.api.nvim_buf_clear_namespace(buf, ghost_ns, 0, -1)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, slines)
    vim.api.nvim_win_set_cursor(win, { #slines, #slines[#slines] })
    fit_height()
    return true
  end

  -- Completion keys are buffer-local, driving the built-in popup menu. <C-e>
  -- needs no mapping -- Neovim already aborts completion with it. The menu also
  -- opens and refreshes as you type; <C-n> stays as the explicit trigger for
  -- reopening it after <C-e>.
  attach_completion(buf)

  local function feed(keys)
    vim.api.nvim_feedkeys(vim.keycode(keys), 'n', false)
  end

  vim.keymap.set('i', '<C-n>', function()
    if vim.fn.pumvisible() == 1 then
      feed '<C-n>'
    else
      prompt_complete()
    end
  end, { buffer = buf })

  for _, lhs in ipairs { '<C-p>', '<S-Tab>' } do
    vim.keymap.set('i', lhs, function()
      if vim.fn.pumvisible() == 1 then
        feed '<C-p>'
      end
    end, { buffer = buf })
  end

  -- <Tab>: accept the completion if the menu is open, else accept Claude's
  -- previewed suggestion if there is one, else insert a literal tab.
  vim.keymap.set('i', '<Tab>', function()
    if vim.fn.pumvisible() == 1 then
      feed '<C-y>'
    elseif accept_suggestion() then
      return
    else
      feed '<Tab>'
    end
  end, { buffer = buf })

  if prefill then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { prefill })
    fit_height()
  end
  vim.cmd 'startinsert'
  if prefill then
    vim.api.nvim_win_set_cursor(win, { 1, #prefill })
  end
  render_ghost()

  -- Now that the prompt box is up, start Claude if it wasn't running so it boots
  -- while you compose. Deferred so the float is fully realized first; Snacks
  -- focuses the new terminal window, so pull focus back to the box and re-enter
  -- insert.
  if need_terminal then
    vim.schedule(function()
      require('claudecode.terminal').ensure_visible {}
      ensure_terminal_autoscroll()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
        vim.cmd 'startinsert'
      end
    end)
  end
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
  local body = line:gsub('^%s*\u{276f}%s*', ''):gsub('^%s*', '')
  local num, rest = body:match '^(%d+)%.%s+(.*)$'
  if not num then
    return nil
  end
  local inside, label = rest:match '^%[([^%]]*)%]%s*(.*)$'
  if inside ~= nil then
    return { num = tonumber(num), label = label, checked = inside:gsub('%s', '') ~= '' }
  end
  return { num = tonumber(num), label = rest }
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
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
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
  local hint
  for i = #lines, 1, -1 do
    if lines[i]:find('to navigate', 1, true) or lines[i]:find('Enter to select', 1, true) then
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
  for i = top + 1, hint - 1 do
    local o = parse_option_line(lines[i])
    if o then
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

-- Find the scraped option at display position `pos`.
local function opt_by_pos(q, pos)
  for _, o in ipairs(q.options) do
    if o.pos == pos then
      return o
    end
  end
end

-- The keystrokes to enact the chosen options on the current tab, by pressing
-- option NUMBER keys -- the TUI's shortcut, verified to work reliably (synthetic
-- arrow keys did not). For single-select a number selects the option and
-- advances to the next question on its own. For multi-select a number only
-- toggles that option's checkbox, so we press the numbers whose desired state
-- differs from what's already checked (re-opening the menu then won't flip
-- existing marks) and finish with a Tab to advance -- matching single-select's
-- feel. <leader>j (Enter) still submits from the Submit tab.
local function choice_keys(q, chosen)
  local keys = {}
  if #chosen == 0 then
    return keys
  end
  if not q.multiselect then
    local o = opt_by_pos(q, chosen[1])
    if o then
      keys[1] = tostring(o.num)
    end
    return keys
  end
  local want = {}
  for _, p in ipairs(chosen) do
    want[p] = true
  end
  for _, o in ipairs(q.options) do
    if (want[o.pos] or false) ~= (o.checked or false) then
      keys[#keys + 1] = tostring(o.num)
    end
  end
  keys[#keys + 1] = '\t' -- multi-select numbers only toggle; Tab advances the tab
  return keys
end

-- Press each option-number key in turn, spaced out in time. The prompt reads
-- consecutive digits as a single multi-digit number (so "1" and "3" sent
-- together look like option 13), so each keypress must land as its own event.
local function send_keys_seq(keys, i)
  i = i or 1
  if i > #keys then
    return
  end
  send_raw(keys[i])
  vim.defer_fn(function()
    send_keys_seq(keys, i + 1)
  end, 80)
end

-- Telescope menu of the current tab's options. <CR> confirms; for multi-select
-- questions, <Tab>-mark several first.
local function pick_claude_option(q)
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'

  local title = q.question ~= '' and q.question or 'Claude'
  if q.multiselect then
    title = title .. '  (Tab to mark multiple)'
  end

  pickers
    .new({}, {
      prompt_title = title:sub(1, 120),
      finder = finders.new_table {
        results = q.options,
        entry_maker = function(o)
          return {
            value = o,
            display = function(e)
              local box = e.value.checked == nil and '' or (e.value.checked and '[x] ' or '[ ] ')
              local head = e.value.pos .. '. ' .. box .. e.value.label
              if e.value.desc ~= '' then
                local full = head .. '  \u{2014}  ' .. e.value.desc
                return full, { { { #head, #full }, 'Comment' } }
              end
              return head
            end,
            ordinal = o.label,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr, map)
        local function confirm()
          local picker = action_state.get_current_picker(prompt_bufnr)
          local multi = picker:get_multi_selection()
          local chosen = {}
          if q.multiselect and #multi > 0 then
            for _, s in ipairs(multi) do
              chosen[#chosen + 1] = s.value.pos
            end
          else
            local sel = action_state.get_selected_entry()
            if sel then
              chosen[#chosen + 1] = sel.value.pos
            end
          end
          actions.close(prompt_bufnr)
          table.sort(chosen)
          local keys = choice_keys(q, chosen)
          if #keys > 0 then
            -- Defer so Telescope's close settles before writing to the PTY.
            vim.defer_fn(function()
              send_keys_seq(keys)
            end, 60)
          end
        end
        map('i', '<CR>', confirm)
        map('n', '<CR>', confirm)
        if q.multiselect then
          -- Space (and Tab) mark/unmark options; <CR> then submits everything
          -- marked. Plain toggle_selection is what get_multi_selection() reads
          -- back -- a composed action showed a mark but didn't register it.
          map('i', '<Space>', actions.toggle_selection)
          map('n', '<Space>', actions.toggle_selection)
          map('i', '<Tab>', actions.toggle_selection)
          map('n', '<Tab>', actions.toggle_selection)
        end
        return true
      end,
    })
    :find()
end

-- Bound to <leader><leader> (see M.keymaps). Answers a live AskUserQuestion
-- prompt when one is on screen, otherwise falls back to the free-text prompt
-- box -- the single keymap just skips the box while a structured question waits.
local function open_prompt_or_answer()
  local q = scrape_claude_question()
  if not q then
    return open_prompt_input()
  end
  pick_claude_option(q)
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

show_no_focus = function(cmd_args)
  local origin = vim.api.nvim_get_current_win()
  require('claudecode.terminal').ensure_visible({}, cmd_args)
  ensure_terminal_autoscroll()
  vim.schedule(function()
    if vim.api.nvim_win_is_valid(origin) and vim.api.nvim_get_current_win() ~= origin then
      vim.api.nvim_set_current_win(origin)
    end
  end)
end

local function toggle_no_focus(cmd_args)
  if claude_win() then
    require('claudecode.terminal').simple_toggle()
  else
    show_no_focus(cmd_args)
  end
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

-- Neovim only auto-follows terminal output in the *focused* window, and terminal
-- buffers don't fire nvim_buf_attach on_lines for PTY output -- so while you edit
-- elsewhere the Claude terminal streams past the bottom of its viewport. Poll on
-- a timer and keep any UNFOCUSED window showing a Claude terminal pinned to its
-- last line. The focused window is left alone (Neovim follows it natively, and
-- you may be scrolling its history there).
local autoscroll_timer = nil
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
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if win ~= cur and vim.api.nvim_win_is_valid(win) then
          local buf = vim.api.nvim_win_get_buf(win)
          if is_claude_terminal(buf) then
            local last = vim.api.nvim_buf_line_count(buf)
            pcall(vim.api.nvim_win_set_cursor, win, { last, 0 })
          end
        end
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
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == '' and vim.bo[buf].modified then
      return true
    end
  end
  return false
end

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
    keys = {
      {
        '<leader>aa',
        function()
          toggle_no_focus()
        end,
        mode = { 'n', 'v' },
        desc = 'toggle',
      },
      { '<leader><leader>', open_prompt_or_answer, mode = { 'n', 'v' }, desc = 'prompt' },

      -- Answer Claude's prompt without leaving your file: <CR> accepts the
      -- highlighted option, <Esc> rejects/cancels it.
      {
        '<leader>j',
        function()
          send_raw '\r'
        end,
        mode = { 'n', 'v' },
        desc = 'accept_prompt',
      },
      {
        '<leader>k',
        function()
          send_raw '\27'
        end,
        mode = { 'n', 'v' },
        desc = 'reject_prompt',
      },
      -- Interrupt Claude's current turn.
      {
        '<leader>al',
        function()
          send_raw '`'
        end,
        mode = { 'n', 'v' },
        desc = 'interrupt',
      },
      -- Next question tab in an AskUserQuestion prompt; the next
      -- <leader><leader> re-scrapes whichever tab is then shown.
      {
        '<leader>a;',
        function()
          send_raw '\t'
        end,
        mode = { 'n', 'v' },
        desc = 'next_question',
      },
      -- Shift+Tab is the terminal back-tab sequence: ESC [ Z.
      {
        '<leader>am',
        function()
          send_raw '\27[Z'
        end,
        mode = { 'n', 'v' },
        desc = 'cycle_mode',
      },

      {
        '<leader>ax',
        function()
          local bufnr = require('claudecode.terminal').get_active_terminal_bufnr()
          if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = true })
          end
        end,
        mode = { 'n', 'v' },
        desc = 'kill',
      },

      { '<leader>av', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = 'attach_visual' },
      {
        '<leader>av',
        '<cmd>ClaudeCodeTreeAdd<cr>',
        desc = 'attach_file',
        ft = { 'NvimTree', 'neo-tree', 'oil', 'minifiles', 'netrw' },
      },
      { '<leader>aV', '<cmd>ClaudeCodeAdd %<cr>', desc = 'attach_buffer' },

      {
        '<leader>as',
        function()
          show_no_focus '--continue'
        end,
        desc = 'session_continue',
      },
      { '<leader>af', pick_claude_session, desc = 'find_session' },
      { '<leader>aF', '<cmd>ClaudeCode --resume<cr>', desc = 'find_session_cmd' },

      { '<leader>ay', '<cmd>ClaudeCodeDiffAccept<cr>', desc = 'diff_accept' },
      { '<leader>an', '<cmd>ClaudeCodeDiffDeny<cr>', desc = 'diff_reject' },
      { '<leader>aM', '<cmd>ClaudeCodeSelectModel<cr>', desc = 'model' },
    },
    config = function()
      require('claudecode').setup {
        -- Every field of ClaudeCodeTerminalConfig is annotated as required; the
        -- plugin merges what you pass over its own defaults.
        ---@diagnostic disable-next-line: missing-fields
        terminal = {
          split_width_percentage = 0.45,
        },
      }

      local group = vim.api.nvim_create_augroup('ClaudeTerminal', { clear = true })

      vim.api.nvim_create_autocmd('BufEnter', {
        group = group,
        pattern = 'term://*',
        callback = function()
          -- Wait briefly just in case we immediately switch out of the buffer
          vim.defer_fn(function()
            if not is_claude_terminal(0) then
              return
            end
            ensure_terminal_autoscroll()
            -- jk leaves terminal-insert (buffer-local, so other terminals keep jk literal)
            vim.keymap.set('t', 'jk', [[<C-\><C-n>]], { buffer = 0, silent = true, desc = 'escape terminal mode' })
            -- tmux-style split navigation from terminal-insert, scoped to this
            -- buffer so shells keep <C-h/j/k/l> for their own line editing.
            for key, dir in pairs { h = 'Left', j = 'Down', k = 'Up', l = 'Right' } do
              vim.keymap.set(
                't',
                '<C-' .. key .. '>',
                [[<C-\><C-n><Cmd>NvimTmuxNavigate]] .. dir .. [[<CR>]],
                { buffer = 0, silent = true, desc = 'navigate ' .. dir:lower() }
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
