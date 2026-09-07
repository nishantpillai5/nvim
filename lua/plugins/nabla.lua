return {
  {
    'jbyuki/nabla.nvim',
    ft = 'markdown',
    -- No keys: <leader>zp drives nabla along with the other two in-buffer
    -- renderers, through util/markdown.lua. `ft` is what loads the plugin, so
    -- require('nabla') resolves by the time that toggle runs.
  },
}
