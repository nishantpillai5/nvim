-- Tags a closing bracket with what it closes, as virtual text. Reads the tree,
-- so it needs a parser from plugins/treesitter.lua.
--
-- `toggle_keybind` is biscuits' own switch; paired with `show_on_start = false`
-- it attaches every buffer but renders nothing until the first press. The old
-- config drove the toggle from a lazy `keys` entry instead, which loaded the
-- plugin, attached the buffer (rendering) and immediately toggled that off again
-- -- so its first press did nothing and the second one showed. The desc lives in
-- plugins/whichkey.lua, since the mapping is the plugin's, not ours.
return {
  {
    'code-biscuits/nvim-biscuits',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      default_config = {
        prefix_string = '  ',
        toggle_keybind = '<leader>zC',
        show_on_start = false,
      },
    },
  },
}
