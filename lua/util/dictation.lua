-- The spoken word that ends dictation and sends the Claude prompt box, wired up
-- in plugins/whisper.lua. It has to survive whisper's own transcription and
-- never turn up by accident, so it is a multi-syllable dictionary noun with no
-- near neighbours in speech about code: three syllables give large-v3 enough
-- signal that it never guesses, and nobody says it while describing a diff.
local M = {}

M.WORD = 'zeppelin'

-- large-v3 spells the word itself consistently, but a chunk whose leading audio
-- is clipped by the VAD boundary comes back short a syllable, and it will reach
-- for a commoner word that sounds the same. A spelling that turns up in the box
-- instead of sending it belongs here.
local HEARD = {
  zeppelin = true,
  zeppelins = true,
  zepplin = true,
  zeplin = true,
  zepelin = true,
  zipline = true,
  ziplines = true,
}

-- Whisper punctuates and capitalises a word it thinks ends a sentence, so the
-- trigger arrives as "Zeppelin." about as often as bare.
function M.normalise(word)
  return (word:lower():gsub('%p', ''))
end

-- Splits a transcript chunk at the trigger: the words spoken before it, and
-- whether it was heard at all. Anything after it is dropped -- VAD hands back a
-- trailing window, so the tail is either the same breath or the room.
function M.split(text)
  local words = vim.split(text, '%s+', { trimempty = true })
  for i, word in ipairs(words) do
    local norm = M.normalise(word)
    -- A compound spelling can arrive split in two ("zip line"). Joining is safe
    -- because the join still has to be in HEARD to count, and the tail of the
    -- chunk is dropped either way, so there is nothing to consume.
    local joined = words[i + 1] and norm .. M.normalise(words[i + 1])
    if HEARD[norm] or (joined and HEARD[joined]) then
      local last = i - 1
      -- The model knows the band far better than the airship, so a bare
      -- "zeppelin" is sometimes handed back with a "Led" in front of it.
      if last > 0 and M.normalise(words[last]) == 'led' then
        last = last - 1
      end
      return table.concat(vim.list_slice(words, 1, last), ' '), true
    end
  end
  return text, false
end

return M
