# nvim -- remaining work

Everything outstanding in this config, and nothing else. The reference material
that used to live here -- layout, conventions, and the rationale behind each
ported plugin -- is in git history: `git show HEAD:README.md`.

## OMP parity

All of it is OMP catching up to Claude Code behind the `<leader>a` dispatch;
none of it blocks anything else. Two unknowns gate the first four, and both are
answered by looking at what `omp` writes to disk: where it stores sessions, and
where its slash-commands live.

- **Ghost suggestion** and **question menu** (`scrape_suggestion`,
  `scrape_question`) need OMP's TUI layout. Only the scrapers are new -- the
  Telescope menu, the option shape and the spaced-out number-key presses are
  already generic in `util/ai/prompt.lua`.
- **Session picker** (`find_session`) is `omp --resume` today, OMP's own in-TUI
  picker. One like Claude's needs OMP's session store, and parity now also means
  rendering its transcript records, not just listing sessions.
- **Worktree launch** (`worktree_continue`, `worktree_session`) is easier than
  Claude's: `omp.lua` builds its own toggleterm terminal, which takes a `dir`, so
  no `cwd_provider` dance. The session half depends on the picker above.
- **`/command` completion** (`slash_commands`) needs OMP's command and skill
  directories. The `@file` half already works for both backends.

Not coming: **diff accept/reject** is claudecode.nvim's MCP diff protocol, and
omp.nvim is a context bridge with no equivalent; **the attach keys** want no OMP
counterpart, since its bridge already pushes the cursor's file and line over a
socket.

## Gaps

- **Treesitter highlighting is off.** `plugins/treesitter.lua` installs parsers
  and stops there -- the `main` branch starts nothing by itself, so the theme's
  regex syntax is still what you see. One `vim.treesitter.start()` in a
  `FileType` autocmd would switch it on.
- **The notes time-diff virtual text is not ported**
  (`nvim-old/lua/nvim/autocmd.lua`, the `TimeDiff` augroup). It belongs in
  `after/ftplugin/markdown.lua`.
- **Two plugins never came over from the old config**: `tuis.nvim` and
  `vim-be-good`. Their keymaps are whatever `nvo` still binds.
- **There is no snippet engine at all.** LuaSnip went with lsp-zero and nothing
  replaced it.
- **There is no recording indicator.** noice's default routes `skip`
  `msg_showmode`, which is where Neovim's own `recording @q` lives. Getting it
  back is a lualine component beside the noice command one in
  `plugins/lualine.lua` -- `require('noice').api.status.mode` -- not a plugin.
- **`mmdc` is missing**, so mermaid diagrams do not render under `<leader>zp`.
  Everything else snacks.image draws is fine.
- **`tectonic` is not in the container image,** so LaTeX equations do not render
  there. It works on the host once tectonic has downloaded its package bundle.
- **`_G.fav_dirs` was never ported,** so the old `<leader>fe` / `<leader>fE` --
  open the tree at a favourite directory -- do not exist here.
- **Nothing aligns text.** mini.align is not installed; the formatters undo
  alignment in every filetype conform handles, which leaves its `['_']` set --
  yaml, shell, vim, sql, plain text, project config -- where `:'<,'>!column -t`
  is the answer. If it ever comes in, it goes in the mini.surround shape:
  `version = '*'`, `ga` / `gA` in `{ n, x }`, descriptions in `whichkey.lua`.
- **No outline in a filetype with neither a treesitter parser nor a language
  server.** That was vista's ctags backend; aerial has no equivalent.

## Open decisions

- **Should a `<leader>ab` switch survive a restart?** The backend a session
  starts on now comes from Omarchy's `omarchy default agent`, falling back to
  declaration order off Omarchy. A mid-session pick is still in-memory only.
- **Treesitter-driven extract for pyright and lua_ls.** `<leader>la` code actions
  already cover extract-to-function and extract-variable wherever the server
  implements them (rust-analyzer, vtsls, gopls, clangd, jdtls). Reconsider
  refactoring.nvim if Python or Lua refactoring starts hurting.
- **`:Make`.** No `makeprg` is ever set, here or in the old config, and nothing
  in overseer v2 reads one. If it is ever wanted it is a `new_task` with
  `expandcmd(vim.o.makeprg)` and `on_output_quickfix`, in `plugins/overseer.lua`.
