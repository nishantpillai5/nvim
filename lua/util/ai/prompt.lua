-- The prompt box: a centered float for composing a message, with @file and
-- /command completion, a preview of the backend's reply, and a menu for
-- answering a structured question -- all without focusing the agent's terminal.
--
-- Backend-agnostic, through util.ai `call` and `try`. `try` returning nil is
-- load-bearing: both scrapers read a *terminal*, so a backend that cannot scrape
-- must return nothing rather than draw its ghost text from the other agent's
-- input box and answer that agent's pending question.

local ai = require 'util.ai'

local M = {}

-- Cached for the lifetime of one box (attach_completion drops it on open). A
-- backend that publishes none disables the "/" half of the menu.
local slash_cache = nil

local function slash_commands()
  if slash_cache == nil then
    slash_cache = ai.try 'slash_commands' or false
  end
  return slash_cache or nil
end

-- Files *and* directories under cwd, so a fragment fuzzy matches the whole path
-- ("clcode" -> lua/plugins/claudecode.lua) instead of walking one level at a
-- time the way getcompletion() does. Cached like slash_cache.
local file_cache = nil

-- The fuzzy match ranks the whole tree; thousands of rows only slow the redraw.
local MAX_FILE_ITEMS = 200

-- nil when the tool is missing, fails, or says nothing: try the next fallback.
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
  -- fd is gitignore-aware and already marks directories with a trailing slash.
  local paths =
    lister_output { 'fd', '--type', 'f', '--type', 'd', '--hidden', '--exclude', '.git', '--strip-cwd-prefix' }
  if not paths then
    paths = lister_output { 'git', 'ls-files', '--cached', '--others', '--exclude-standard' }
    if paths then
      -- git lists files only, so re-derive parents for "@dir" to complete.
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
    -- Misses dotfiles and honours no ignore file, but never comes up empty.
    paths = {}
    for _, path in ipairs(vim.fn.glob('**/*', false, true)) do
      paths[#paths + 1] = vim.fn.isdirectory(path) == 1 and path .. '/' or path
    end
  end
  file_cache = paths
  return paths
end

-- Completes @file paths and /commands through the built-in popup menu. Two
-- things make a *path* different from a keyword, and both are why this is
-- re-driven from a TextChanged autocmd rather than only from <C-n>: the menu
-- ends on any character outside 'iskeyword', and "/" is one; and complete()
-- takes a *static* list, so "@lua"'s candidates would still be the parent's once
-- you reach "@lua/". Recomputing per typed character fixes both.
local function prompt_complete()
  local before = vim.api.nvim_get_current_line():sub(1, vim.fn.col '.' - 1)

  -- Only when the line is a leading slash token, and only if the backend
  -- publishes commands -- never another agent's.
  if before:match '^%s*/%S*$' then
    local names = slash_commands()
    if not names then
      return false
    end
    -- The match above guarantees a slash token, so find cannot return nil.
    local start = assert(before:find '/%S*$')
    local items = {}
    for _, name in ipairs(names) do
      items[#items + 1] = { word = '/' .. name, kind = 'f' }
    end
    vim.fn.complete(start, items)
    return true
  end

  -- 'fuzzy' is in completeopt, so the menu's narrowing agrees with this ranking.
  -- A token outside the project (absolute, ~, ./, ../) has no candidate list and
  -- keeps prefix completion, which also backstops fd's ignore rules.
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

-- InsertCharPre fires only for a literally typed character, never for text the
-- menu inserts -- without it <C-n> would rebuild the menu out from under the
-- cursor. TextChangedP is needed too: only it fires while the menu is open.
local function attach_completion(buf)
  -- One box, one directory walk each.
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
      -- Swallowed, or a bad keystroke reports on every character typed.
      pcall(prompt_complete)
    end,
  })
end

local ghost_ns = vim.api.nvim_create_namespace 'ai_prompt_ghost'
local context_ns = vim.api.nvim_create_namespace 'ai_prompt_context'

-- Keeps the origin selection visible while the float is open. `vsel` is a
-- 1-indexed linewise {start, end} or nil; returns a function that clears it.
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
  -- Captured BEFORE the float takes focus. It becomes a prefilled @-mention, so
  -- it is sent only on submit and escaping leaves nothing in the terminal.
  local origin_buf = vim.api.nvim_get_current_buf()
  local origin_mode = vim.fn.mode()
  local vsel
  if origin_mode == 'v' or origin_mode == 'V' or origin_mode == '\22' then
    local a, b = vim.fn.getpos 'v', vim.fn.getpos '.'
    vsel = { math.min(a[2], b[2]), math.max(a[2], b[2]) } -- 1-indexed line range
  end
  local clear_origin_highlight = highlight_origin_selection(origin_buf, vsel)

  -- Starting is deferred to the end: opening here would steal the redraw and the
  -- box would never appear.
  local need_terminal = not ai.call 'term_buf'

  local width = math.min(100, math.max(40, math.floor(vim.o.columns * 0.7)))
  local max_height = math.max(1, math.floor(vim.o.lines * 0.5))
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.b[buf].ai_prompt = true
  local suggestion = ai.try 'scrape_suggestion'
  -- With no selection nothing is prefilled, so a whole file is never force-fed
  -- into context and the suggested-reply ghost keeps its behaviour.
  local prefill
  if vsel then
    local mention = ai.try('mention', origin_buf, vsel)
    if mention then
      prefill = mention .. ' '
      suggestion = nil -- the prefilled selection replaces the suggested-reply ghost
    end
  end
  local suggestion_lines = suggestion and vim.split(suggestion, '\n')

  -- llama has no per-buffer guard, so left alone it renders its own FIM ghost
  -- and rebinds <Tab> over the backend's suggestion: suppress it while the box is
  -- empty. 'pumheight' drops to 8 because Neovim decides whether the menu fits
  -- below the cursor from it rather than the real candidate count, and at 12 the
  -- menu flips above and lands on this centred box. Both restored on close.
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

  -- Before our keymaps: llama#disable() unmaps <buffer> <Tab>.
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
    -- Guarded on the split, the one indexed below; both are set together.
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

  -- TextChangedP too: only it fires while the menu is open, and without it the
  -- box freezes at the height it had when the menu appeared.
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

    -- Before tearing the float down: the buffer is bufhidden=wipe, so closing
    -- first and then failing to send lost whatever had been composed.
    if sending and not ai.call('submit', text) then
      return
    end

    closed = true
    clear_origin_highlight()
    restore_pumheight()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    -- Closing from insert leaves the global insert state on.
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

  -- Buffer-local so they win over a global <CR>=confirm while the menu is open.
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

  -- <C-e> needs no mapping, Neovim already aborts with it; <C-n> is the explicit
  -- trigger for reopening the menu after one.
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
      -- 'noselect' means <C-y> with nothing highlighted just dismisses, leaving
      -- a fuzzy token like "@clcode" behind -- take the top entry instead.
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

  -- Deferred so the float is realized first. The backend may focus its new
  -- terminal, so pull focus back to the box.
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

-- Option NUMBER keys, the TUI's shortcut -- synthetic arrow keys were not
-- reliable. Single-select advances on its own; multi-select only toggles, so
-- press the numbers whose state differs from what is checked, then Tab.
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

-- Spaced out: consecutive digits read as one number, so "1" and "3" sent
-- together look like option 13.
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
            -- Let Telescope's close settle before writing to the PTY.
            vim.defer_fn(function()
              send_keys_seq(keys)
            end, 60)
          end
        end
        map('i', '<CR>', confirm)
        map('n', '<CR>', confirm)
        if q.multiselect then
          -- Plain toggle_selection is what get_multi_selection() reads back; a
          -- composed action showed a mark but did not register it.
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

-- Answers a live structured question when the backend can see one, else the
-- free-text box. A backend with no scraper always gets the box.
function M.open()
  local q = ai.try 'scrape_question'
  if not q then
    return open_prompt_input()
  end
  pick_option(q)
end

return M
