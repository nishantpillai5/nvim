-- The spoken words that end dictation and act on the agent prompt box, wired up
-- in plugins/whisper.lua. Each has to survive whisper's own transcription and
-- never turn up by accident, so they are multi-syllable dictionary nouns with no
-- near neighbours in speech about code: three syllables give large-v3 enough
-- signal that it never guesses, and nobody says them while describing a diff.
-- They also have to stay far apart from each other -- one misheard as another
-- would send a half-composed prompt where you meant to answer a dialog.
local M = {}

-- What each word does. `submit` sends the box; the rest are the ops <leader>j,
-- <leader>k and <leader>al dispatch to (see util/ai/init.lua), and leave the box
-- cancelled -- answering a dialog or stopping a turn is not a prompt.
M.WORDS = {
  submit = 'zeppelin',
  accept = 'flamingo',
  reject = 'kangaroo',
  interrupt = 'platypus',
}

-- large-v3 spells each word itself consistently, but a chunk whose leading audio
-- is clipped by the VAD boundary comes back short a syllable, and it will reach
-- for a commoner word that sounds the same. A spelling that turns up in the box
-- instead of acting on it belongs here, against the action it was meant for.
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
  -- The dance is the commoner word by far, so a clipped "flamingo" lands on it.
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

-- Whisper punctuates and capitalises a word it thinks ends a sentence, so a
-- trigger arrives as "Zeppelin." about as often as bare.
function M.normalise(word)
  return (word:lower():gsub('%p', ''))
end

-- Splits a transcript chunk at the first trigger: the words spoken before it,
-- and the action it names (nil when none was heard). Anything after it is
-- dropped -- VAD hands back a trailing window, so the tail is either the same
-- breath or the room.
function M.split(text)
  local words = vim.split(text, '%s+', { trimempty = true })
  for i, word in ipairs(words) do
    local norm = M.normalise(word)
    -- A compound spelling can arrive split in two ("zip line", "kanga roo").
    -- Joining is safe because the join still has to be in HEARD to count, and
    -- the tail of the chunk is dropped either way, so there is nothing to
    -- consume.
    local joined = words[i + 1] and norm .. M.normalise(words[i + 1])
    local action = HEARD[norm] or (joined and HEARD[joined])
    if action then
      local last = i - 1
      -- The model knows the band far better than the airship, so a bare
      -- "zeppelin" is sometimes handed back with a "Led" in front of it. Scoped
      -- to that word: a "led" before either of the others is a real word.
      if action == 'submit' and last > 0 and M.normalise(words[last]) == 'led' then
        last = last - 1
      end
      return table.concat(vim.list_slice(words, 1, last), ' '), action
    end
  end
  return text, nil
end

return M
