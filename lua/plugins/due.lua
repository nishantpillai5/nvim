local PATTERNS = { 'todo.md', 'todo.txt', 'TODO.md', 'TODO.txt' }

local events = {}
for _, pattern in ipairs(PATTERNS) do
  table.insert(events, 'BufReadPre ' .. pattern)
  table.insert(events, 'BufNewFile ' .. pattern)
end

return {
  {
    'nfrid/due.nvim',
    event = events,
    config = function()
      require('due_nvim').setup {
        ft = table.concat(PATTERNS, ','),
        pattern_start = 'due: ',
        pattern_end = '',
        prescript = ' ',
      }
    end,
  },
}
