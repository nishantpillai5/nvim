-- The spoken words that end dictation and act on the agent prompt box. Three
-- syllables, no near neighbours in speech about code, and far apart from each
-- other -- one misheard as another sends a half-composed prompt.
local M = {}

-- `submit` sends the box; the rest are the ops <leader>j, <leader>k and
-- <leader>al dispatch to, and leave it cancelled.
M.WORDS = {
  submit = 'zeppelin',
  accept = 'flamingo',
  reject = 'kangaroo',
  interrupt = 'platypus',
}

-- A chunk clipped at the VAD boundary comes back short a syllable and reaches
-- for a commoner word. Any spelling that lands in the box instead belongs here.
local HEARD = {
  zeppelin = 'submit',
  zeppelins = 'submit',
  zepplin = 'submit',
  zeplin = 'submit',
  zepelin = 'submit',
  zipline = 'submit',
  ziplines = 'submit',
  flamingo = 'accept',
  flamingos = 'accept',
  flamingoes = 'accept',
  flameingo = 'accept',
  -- The dance is far commoner, so a clipped "flamingo" lands on it.
  flamenco = 'accept',
  kangaroo = 'reject',
  kangaroos = 'reject',
  kangeroo = 'reject',
  kangroo = 'reject',
  cangaroo = 'reject',
  platypus = 'interrupt',
  platypuses = 'interrupt',
  platypi = 'interrupt',
  platipus = 'interrupt',
  plattypus = 'interrupt',
}

-- A trigger arrives as "Zeppelin." about as often as bare.
function M.normalise(word)
  return (word:lower():gsub('%p', ''))
end

-- The words before the first trigger, and the action it names. The tail is
-- dropped: VAD hands back a trailing window, so it is the same breath or noise.
function M.split(text)
  local words = vim.split(text, '%s+', { trimempty = true })
  for i, word in ipairs(words) do
    local norm = M.normalise(word)
    -- A compound spelling can arrive split in two ("zip line", "kanga roo");
    -- the join still has to be in HEARD to count.
    local joined = words[i + 1] and norm .. M.normalise(words[i + 1])
    local action = HEARD[norm] or (joined and HEARD[joined])
    if action then
      local last = i - 1
      -- The model knows the band better than the airship. Scoped to this word:
      -- a "led" before either of the others is a real one.
      if action == 'submit' and last > 0 and M.normalise(words[last]) == 'led' then
        last = last - 1
      end
      return table.concat(vim.list_slice(words, 1, last), ' '), action
    end
  end
  return text, nil
end

return M
