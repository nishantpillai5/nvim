-- The prompt box: a centered float you compose a message in, with @file and
-- /command completion, a preview of the backend's suggested reply, and a menu
-- for answering a structured question -- all without focusing the agent's
-- terminal.
--
-- Backend-agnostic. Everything specific to one agent is reached through
-- util.ai: `call` for what every backend must do (send_raw, term_buf, show,
-- submit) and `try` for what only some can (scrape_suggestion, scrape_question,
-- slash_commands, mention), which returns nil instead of warning.
--
-- `try` returning nil is load-bearing, not a shrug. Both scrapers read a
-- *terminal*, and before this module existed they read Claude's unconditionally:
-- with two agents running, a box aimed at OMP would have drawn its ghost text
-- from Claude's input box and answered Claude's pending question with OMP's
-- keystrokes. A backend that cannot scrape must therefore return nothing rather
-- than inherit someone else's. See the AI section of README.md.

local ai = require 'util.ai'

local M = {}

-- The backend's slash-command list, cached for the lifetime of one box the way
-- project_files is (attach_completion drops both when a box opens). A backend
-- that doesn't publish one disables the "/" half of the menu outright.
local slash_cache = nil

local function slash_commands()
  if slash_cache == nil then
    slash_cache = ai.try 'slash_commands' or false
  end
  return slash_cache or nil
end

-- @file candidates: every file *and* directory under cwd, so a fragment can be
-- fuzzy matched against the whole path ("clcode" -> lua/plugins/claudecode.lua)
-- the way Claude's own terminal file search works, instead of walking the tree
-- one directory level at a time the way getcompletion() does. Cached like
-- slash_cache -- built on the first @ you type, dropped when a box opens, so a
-- file created mid-session shows up the next time you pop the box.
local file_cache = nil

-- Cap on what reaches the popup menu. The fuzzy match ranks the entire tree, but
-- a menu of thousands of paths is slow to redraw and nothing past the first
-- screenful is ever the entry you meant.
local MAX_FILE_ITEMS = 200

-- Run a lister and return its stdout lines, or nil if it isn't installed, fails,
-- or has nothing to say -- which is the signal to try the next fallback.
local function lister_output(cmd)
  local ok, res = pcall(function()
    return vim.system(cmd, { cwd = vim.fn.getcwd(), text = true }):wait(3000)
  end)
  if not ok or res.code ~= 0 or not res.stdout then
    return nil
  end
  local lines = vim.split(res.stdout, '\n', { trimempty = true })
  return #lines > 0 and lines or nil
end

-- Every path under cwd, relative and with directories marked by a trailing "/".
local function project_files()
  if file_cache then
    return file_cache
  end
  -- fd is the fast path: gitignore-aware (so build output and node_modules stay
  -- out of the menu, as they do in Claude's terminal) and it already prints the
  -- trailing slash on directories.
  local paths =
    lister_output { 'fd', '--type', 'f', '--type', 'd', '--hidden', '--exclude', '.git', '--strip-cwd-prefix' }
  if not paths then
    paths = lister_output { 'git', 'ls-files', '--cached', '--others', '--exclude-standard' }
    if paths then
      -- git lists files only; re-derive each parent directory so "@dir" still
      -- completes to something.
      local dirs, seen = {}, {}
      for _, path in ipairs(paths) do
        local slash = path:find '/'
        while slash do
          local dir = path:sub(1, slash)
          if not seen[dir] then
            seen[dir] = true
            dirs[#dirs + 1] = dir
          end
          slash = path:find('/', slash + 1)
        end
      end
      vim.list_extend(paths, dirs)
      table.sort(paths)
    end
  end
  if not paths then
    -- Last resort with neither tool: a plain recursive glob. Misses dotfiles and
    -- honours no ignore file, but it never comes up empty.
    paths = {}
    for _, path in ipairs(vim.fn.glob('**/*', false, true)) do
      paths[#paths + 1] = vim.fn.isdirectory(path) == 1 and path .. '/' or path
    end
  end
  file_cache = paths
  return paths
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

  -- /command: only when the line is just a leading slash token. A backend with
  -- no command list disables this half rather than offering another agent's.
  if before:match '^%s*/%S*$' then
    local names = slash_commands()
    if not names then
      return false
    end
    -- The match above guarantees a slash token, so find cannot come back nil.
    local start = assert(before:find '/%S*$')
    local items = {}
    for _, name in ipairs(names) do
      items[#items + 1] = { word = '/' .. name, kind = 'f' }
    end
    vim.fn.complete(start, items)
    return true
  end

  -- @file: fuzzy match the last @token against every path in the project.
  -- 'fuzzy' is already in completeopt, so the menu's own narrowing agrees with
  -- the ranking here rather than fighting it. A token that points outside the
  -- project (absolute, ~, ./ or ../) has no candidate list to match against and
  -- keeps plain prefix completion -- which also backstops whatever fd's ignore
  -- rules left out of project_files().
  local at = before:find '@%S*$'
  if at then
    local partial = before:sub(at + 1)
    local matches
    if partial == '' then
      matches = vim.list_slice(project_files(), 1, MAX_FILE_ITEMS)
    elseif not (partial:match '^[/~]' or partial:match '^%.%.?/') then
      matches = vim.fn.matchfuzzy(project_files(), partial, { limit = MAX_FILE_ITEMS })
    end
    if not matches or #matches == 0 then
      matches = vim.fn.getcompletion(partial, 'file')
    end
    local items = {}
    for _, path in ipairs(matches) do
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
  -- One box, one directory walk each: see slash_commands / project_files.
  slash_cache = nil
  file_cache = nil
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

local ghost_ns = vim.api.nvim_create_namespace 'ai_prompt_ghost'
local context_ns = vim.api.nvim_create_namespace 'ai_prompt_context'

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
  local need_terminal = not ai.call 'term_buf'

  local width = math.min(100, math.max(40, math.floor(vim.o.columns * 0.7)))
  local max_height = math.max(1, math.floor(vim.o.lines * 0.5))
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.b[buf].ai_prompt = true
  local suggestion = ai.try 'scrape_suggestion'
  -- A visual selection prefills its @-mention (with line range) so it rides
  -- along with your prompt and is sent only on submit. With no selection nothing
  -- is prefilled: the suggested-reply ghost keeps its normal behavior, and a
  -- whole file is never force-fed into Claude's context on every prompt.
  local prefill
  if vsel then
    local mention = ai.try('mention', origin_buf, vsel)
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
    title = ' ' .. ai.get().name .. ' ',
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
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
    local sending = send and text:gsub('%s', '') ~= ''

    -- Send *before* tearing the float down. The prompt buffer is bufhidden=wipe,
    -- so closing first and then failing to send (the agent exited, channel
    -- closed) lost whatever had been composed. The backend owns how a prompt
    -- reaches its TUI -- bracketed paste and a trailing CR for Claude, a
    -- flattened single line for one that can't take a paste -- and has already
    -- notified by the time it returns false.
    if sending and not ai.call('submit', text) then
      return
    end

    closed = true
    clear_origin_highlight()
    restore_pumheight()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    -- Closing the float from insert mode leaves the global insert state on, so
    -- focus returns to your buffer still in insert -- force normal mode back.
    vim.schedule(function()
      vim.cmd 'stopinsert'
    end)
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
      -- 'noselect' leaves nothing highlighted until you walk the menu, and <C-y>
      -- with no selection just dismisses it -- which for a fuzzy token like
      -- "@clcode" would leave behind text that is not a path at all. Take the
      -- top-ranked entry in that case.
      feed(vim.fn.complete_info({ 'selected' }).selected == -1 and '<C-n><C-y>' or '<C-y>')
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

  -- Now that the prompt box is up, start the agent if it wasn't running so it
  -- boots while you compose. Deferred so the float is fully realized first; the
  -- backend may focus its new terminal window, so pull focus back to the box and
  -- re-enter insert.
  if need_terminal then
    vim.schedule(function()
      ai.call 'show'
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
        vim.cmd 'startinsert'
      end
    end)
  end
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
  ai.call('send_raw', keys[i])
  vim.defer_fn(function()
    send_keys_seq(keys, i + 1)
  end, 80)
end

-- Telescope menu of the current tab's options. <CR> confirms; for multi-select
-- questions, <Tab>-mark several first.
local function pick_option(q)
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'

  local title = q.question ~= '' and q.question or ai.get().name
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

-- Bound to <leader><leader> in core/keymaps.lua. Answers a live structured
-- question when the active backend can see one, otherwise falls back to the
-- free-text box -- the single keymap just skips the box while a question waits.
-- A backend with no scraper always gets the box, and never someone else's
-- question.
function M.open()
  local q = ai.try 'scrape_question'
  if not q then
    return open_prompt_input()
  end
  pick_option(q)
end

return M
