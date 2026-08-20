-- A month view beside the journal. Opening a journal note pops the calendar to
-- that month; picking a day in the calendar opens that day's note, and days that
-- already have one are marked. edgy docks it left by its `calendar` filetype.
local env = require 'util.env'

local journal = vim.fs.joinpath(vim.fs.normalize(env.DIR_NOTES), 'journal')

local function note_path(day, month, year)
  return vim.fs.joinpath(journal, string.format('%04d.%02d.%02d.md', year, month, day))
end

-- calendar-vim calls these through `v:lua.<name>`, so they have to be globals
-- rather than module functions.
function _G.notes_cal_sign(day, month, year)
  return vim.fn.filereadable(note_path(day, month, year)) == 1 and 1 or 0
end

function _G.notes_cal_action(day, month, year)
  -- Back to the window the calendar was opened from, so the note replaces the
  -- note rather than the calendar.
  vim.cmd 'silent! wincmd p'
  vim.cmd('silent! e ' .. vim.fn.fnameescape(note_path(day, month, year)))
end

return {
  {
    'mattn/calendar-vim',
    cmd = { 'Calendar', 'CalendarT' },
    event = {
      'BufReadPre ' .. journal .. '/*.md',
      'BufNewFile ' .. journal .. '/*.md',
    },
    init = function()
      vim.g.calendar_action = 'v:lua.notes_cal_action'
      vim.g.calendar_sign = 'v:lua.notes_cal_sign'
      vim.g.calendar_mark = 'left'
      vim.g.calendar_monday = 1
      vim.g.calendar_datetime = 'title'
      vim.g.calendar_weeknm = 5
      vim.g.calendar_keys = { goto_next_month = '<A-PageDown>', goto_prev_month = '<A-PageUp>' }
      vim.g.calendar_no_mappings = 0
    end,
    config = function()
      vim.api.nvim_create_autocmd('BufEnter', {
        group = vim.api.nvim_create_augroup('calendar_journal', { clear = true }),
        pattern = journal .. '/*.md',
        desc = 'show the journal month alongside a journal note',
        callback = function()
          -- Only with the vault as cwd; a journal note opened from elsewhere
          -- should not steal a window.
          if vim.fs.normalize(vim.uv.cwd() or '') ~= vim.fs.normalize(env.DIR_NOTES) then
            return
          end
          local year, month = vim.fn.expand('%:t'):match '(%d+).(%d+).%d+.md'
          if not year then
            return
          end
          -- :Calendar wants unpadded numbers.
          vim.cmd(('silent! Calendar %d %d'):format(tonumber(year), tonumber(month)))
          vim.cmd 'silent! wincmd p'
        end,
      })
    end,
  },
}
