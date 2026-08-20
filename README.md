# nvim

The default Neovim config, at `~/.config/nvim`. The config it replaced is at
`~/.config/nvim-old`, still runnable as `nvo`; see
[Porting more from the old config](#porting-more-from-the-old-config).

## Layout

```
init.lua              leader keys, then require 'core'
lua/core/             editor config, no plugin dependencies
  options.lua         vim.opt / vim.g
  filetypes.lua       vim.filetype.add overrides
  keymaps.lua         non-plugin mappings, desc inline
  autocmds.lua        autocmds, one augroup per concern
  commands.lua        user commands
  lsp.lua             native LSP wiring: enable, attach, keymaps, diagnostics
  lazy.lua            lazy.nvim bootstrap + setup (loaded last)
  health.lua          :checkhealth core
lua/util/             helpers; env.lua holds machine-specific paths
lua/enabled.lua       the plugin list, by lazy spec name -- comment out to disable
lua/plugins/          one file per plugin
lsp/<server>.lua      per-server config, auto-discovered by vim.lsp.enable
after/ftplugin/       per-filetype settings
```

## LSP

No lsp-zero, no nvim-lspconfig, no nvim-cmp. Servers are defined in `lsp/*.lua`
and switched on by `vim.lsp.enable` in `core/lsp.lua`; completion is
`vim.lsp.completion` with `autotrigger`.

Run `:MasonInstallAll` once to install the servers, formatters and linters
through mason. Until then, linters with no binary are skipped rather than
erroring, and conform falls back to the LSP formatter.

To add a server: drop a `lsp/<name>.lua` returning `{ cmd, filetypes,
root_markers, settings }`, add its name to `SERVERS` in `core/lsp.lua`, and its
mason package to `MASON_PACKAGES` (which also carries the formatter and linter
packages).

0.11+ binds `grn` rename, `gra` code action, `grr` references, `gri`
implementation, `grt` type definition, `gO` document symbols, `K` hover, and
`<C-s>` signature help. The `<leader>l*` maps in `core/lsp.lua` duplicate a few
of these on purpose, carried over from the old config.

## Conventions

- **One plugin per file**, in `lua/plugins/<name>.lua`, with its spec and config
  together. No parallel `lua/config/` tree.
- **`lua/enabled.lua` is the single plugin list**, holding each plugin's real
  lazy.nvim spec name. `core/lazy.lua` collects every spec under `lua/plugins/`
  and emits only the listed ones, matching on the spec's own name -- so the list
  can't drift from the files. Comment an entry out to disable that plugin;
  a name matching no spec is reported at startup, so typos fail loudly.
  Adding a plugin is a new file plus a line in the list.
- **Keymap descriptions are inline** on `vim.keymap.set`. which-key reads them
  directly; there is no separate `keys` table.
- **Filetype settings go in `after/ftplugin/`,** not `FileType` autocmds.
- **Your code stays under `core/`, `util/`, `plugins/`.** Other top-level dirs in
  `lua/` belong to plugin extension points (e.g. `lua/overseer/component/`).

## Neovim 0.12 baseline

This config targets 0.12 and uses current APIs only:

- `vim.uv`, `vim.fs.joinpath`, `vim.fs.normalize`, `vim.fs.root`, `vim.fs.rm`
- `vim.system` for subprocesses (async, argv list, no shell)
- `vim.ui.open` to hand a path to the OS -- no per-platform branching
- `vim.filetype.add` instead of filetype autocmds
- `options.lua` lists **non-defaults only**, verified against `nvim --clean`

When adding LSP, use `vim.lsp.config` / `vim.lsp.enable` rather than wiring
servers through nvim-lspconfig's old setup path.

## Notes on ported plugins

- `lua/plugins/edgy.lua` keeps layout slots for plugins that aren't here yet
  (trouble, dap-ui, overseer, neotest, neo-tree, vista, fugitive). An
  `ft` that never appears never matches, so each panel starts docking as soon as
  its plugin lands.
- `lua/plugins/lualine.lua` is the single `lualine.setup` call. The old config
  called it four times, grafting components on from `lsp_zero.lua`, `lint.lua`
  and `noice.lua`; those components are defined inline there instead.
- `lua/plugins/treesitter.lua` pins `branch = 'main'`. `main` is the rewrite and
  the only branch with `install()`; on `master` the whole API is different. It
  installs parsers and starts nothing, as the old config did -- see Gaps that are
  not a missing plugin.
- `lua/plugins/treesitter_context.lua` calls `require('treesitter-context').toggle()`
  rather than the old config's `:TSContextToggle`, which upstream replaced with
  the `:TSContext toggle` subcommand.
- `lua/plugins/biscuits.lua` hands `<leader>zC` to biscuits' own
  `toggle_keybind`, with `show_on_start = false`. The old config bound the key
  through lazy's `keys` and called `BufferAttach()` then `toggle_biscuits()`,
  which rendered and immediately un-rendered -- its first press did nothing.
- `lua/plugins/calendar.lua` defines `notes_cal_sign` and `notes_cal_action` as
  globals. calendar-vim calls them by name through `v:lua`, from Vimscript, so a
  module function is not reachable.
- `lua/plugins/surround.lua` keeps its keymap descriptions in
  `plugins/whichkey.lua`, next to trailblazer's. mini installs its own mappings
  from `opts.mappings` when it loads, replacing lazy's key stubs and their
  `desc`, so the spec's `keys` labels only ever show before the first use.

## Finder

`lua/plugins/telescope.lua` holds telescope plus its extensions;
`lua/plugins/navigation.lua` holds grapple and other.nvim.

Features that lost their backing plugin in this config:

- `merge_from_branch` and `reset_file_to_*` ran fugitive's `:Git`. They now shell
  out with `vim.system`, so they work without fugitive.
- The telescope picker mappings `T`/`t` sent results to trouble.nvim; dropped.
- The diff previewer only adds `delta` to the git command when delta is on PATH.

## Git

`lua/plugins/git.lua` holds fugitive, lazygit, gitsigns, diffview, gitlinker,
git-conflict, git-blame and gitgraph. `lua/plugins/worktree.lua` holds
git-worktree.nvim on its own, since its config is substantial.

- `util/git.lua` supplies the branch refs. Its `main_branch()` is why
  `<leader>gl` / `<leader>gfl` (`origin/<main>...HEAD`) resolve at all.
- In a `fugitive` buffer, `<leader>p` / `<leader>P` are pull/push, shadowing the
  global clipboard maps for that buffer only.
- git-worktree's spec dropped the overseer.nvim dependency; nothing used it.
- `_G.worktree_symlinks` still defaults to `{ '.env', '.vscode' }`.

## Notes and journal

The vault is `util.env`'s `DIR_NOTES` (`~/notes` unless the environment says
otherwise). `plugins/obsidian.lua` loads for markdown files under it, or on the
first `<leader>n` mapping, and `plugins/calendar.lua` and
`plugins/global_note.lua` sit beside it.

- **With the vault as cwd, four general finders become obsidian's**:
  `<leader>ff`, `<leader>?`, `<leader>fs` and `<leader>fS` are re-bound in
  obsidian's `config`, since a vault has no code to find. Outside the vault they
  stay telescope's. The guard is the cwd, exactly as in the old config, so
  opening a single note from a project does not move them.
- **Completion inside a note comes from obsidian's own LSP server.** The old
  config set `completion.nvim_cmp = true`; upstream has since dropped both that
  and the blink flag in favour of an in-process `obsidian-ls`, which `vim.lsp`
  attaches like any other server -- so `core/lsp.lua` gives it the native
  autotrigger menu for free, with no completion plugin involved.
- **`mc` toggles a checkbox** from anywhere on its line, bound per-buffer on
  `ObsidianNoteEnter` so it does not shadow the `m` marks prefix elsewhere.
- **The calendar tracks the journal.** Opening `journal/*.md` in the vault pops
  the month beside it; a day in the calendar opens that day's note, and days that
  already have one are marked. edgy docks it left by its `calendar` filetype.
- **global-note's three scratch notes** all live in the vault: `<leader>na`
  global, `<leader>nN` per project (`project.<dir>.md`), `<leader>nn` per branch
  (`project.<dir>.<branch>.md`, non-word characters replaced). `util.git.branch()`
  supplies the branch and returns nil on a detached HEAD, which global-note reads
  as "no note".

## Scopes and sessions

A neoscopes "scope" is a named subset of the repo. When one is active the
telescope pickers narrow to it: `util/scope.lua` is consulted at call time by
`<leader>ff`, `<leader>fA`, `<leader>f/`, `<leader>f?`, `<leader>fw`,
`<leader>fW` and `<leader>?`, and it is a no-op when no scope is selected.

The old config instead swapped those seven keymaps in and out on scope
select/clear, restoring them by re-invoking `config.telescope.keymaps()`. The
lazy `keys` spec has no equivalent to re-invoke, and reading the scope per call
removes the restore path entirely.

resession names sessions after the active scope, so each scope keeps its own
layout. `<leader>ws` / `<leader>wl` are the scoped save/load; `<leader>wS` /
`<leader>wL` prompt for a name.

## Tasks

`util/tasks.lua` holds the build/run task filters, the formatter and the
spinner, shared by `plugins/overseer.lua` and the lualine task indicator. The
`_G.filter_build_tasks`, `_G.filter_run_tasks`, `_G.task_formatter`,
`_G.run_template` and `_G.build_template` hooks are all project-local exrc knobs.

`lua/overseer/component/custom/vscode_env.lua` is found by overseer on the
runtimepath as `custom.vscode_env`; it injects `.vscode/.env` (falling back to
`.env`) into every task's environment via the same `_G.env_reader` the terminal
manager uses.

## AI

`plugins/claudecode.lua` is the largest file here. Most of it is the prompt box
you pop over the current file with `<leader><leader>`: it composes a message,
completes `@file` paths and slash commands, previews Claude's suggested reply,
and can answer an AskUserQuestion prompt by option key -- all without focusing
the terminal.

Its `@file` / `/command` completion drove nvim-cmp in the old config. nvim-cmp
isn't part of this config, so it drives Neovim's built-in popup menu through
`vim.fn.complete()` instead. The menu opens as you type inside an `@path` or a
leading `/command`; `<C-n>` also opens it (and advances it), `<C-p>` and
`<S-Tab>` go back, `<Tab>` accepts, and `<C-e>` aborts natively.

Completing a *path* on the built-in menu needs the candidate list rebuilt on
every keystroke, which is what the `InsertCharPre` + `TextChanged{I,P}` pair in
`attach_completion` does. Without it the menu dies on the first `/` you type (the
built-in menu ends on any character outside `'iskeyword'`) and, because
`complete()` takes a static list, it would keep offering a directory's parent
entries instead of its contents. `TextChangedP` is in the box's resize autocmd
for the same reason -- it is the only one of the pair that fires while the menu
is open, and without it the box freezes at its old height mid-prompt.

Two settings elsewhere exist only to keep that menu off the box:

- **`popupmenu = { enabled = false }` in `plugins/noice.lua`.** noice otherwise
  takes `ext_popupmenu` over `vim.ui_attach` and draws the menu itself, anchored
  at a hardcoded `row = 1 + offset` from the cursor with `offset` already at its
  maximum -- which lands its top row on the box and hides the line being typed.
  There is no config lever for that row, so the menu goes back to Neovim, which
  places it clear of the box at every terminal height. The cost is that cmdline
  completion is drawn natively too, not in noice's styled menu.
- **`pumheight` dropped to 8 while the box is open** (`open_prompt_input`,
  restored in `finish`). Neovim decides whether the menu fits *below* the cursor
  from `'pumheight'` rather than the real candidate count, and the box sits at the
  vertical centre -- so at the config-wide 12 the menu flips above the cursor on a
  24-row terminal and lands on the box anyway. Scoped rather than global so
  completion everywhere else keeps the taller menu. Below about 20 rows Neovim
  flips it regardless; that one is not ours to fix.

`core/autocmds.lua`'s terminal autoscroll skips Claude's terminal, which
`plugins/claudecode.lua` manages itself (jk to leave insert, `<C-h/j/k/l>` split
navigation, autoscroll for unfocused windows, and quitting Neovim when only the
Claude terminal is left and nothing is unsaved).

The `llama_hl_fim_hint` highlight lives in `plugins/llama.lua` rather than
core, since it only matters when llama.vim is enabled.

## Porting more from the old config

This config lives at `~/.config/nvim`, so plain `nvim` runs it. The config it
grew out of moved to `~/.config/nvim-old` (a git repo, branch `main`) and runs
under the `nvo` alias -- the two are fully isolated, so it stays a working
reference rather than an archive.

Its shape, for orientation:

```
lua/plugins/<topic>.lua   specs, grouped by topic, each file opening with a
                          `local plugins = { ... }` manifest and every spec
                          gated on `cond = conds['owner/repo']`
lua/config/<name>.lua     one module per plugin: M.keys, M.keymaps, M.setup,
                          M.config, sometimes M.lualine
lua/common/               shared across the nvim and vscode branches
lua/nvim/                 the non-vscode branch
lua/vsc/                  the vscode branch -- deliberately not ported
```

### What is still over there

```sh
comm -13 \
  <(grep -ohE "'[^']+/[^']+'" ~/.config/nvim/lua/enabled.lua | tr -d "'" | sort -uf) \
  <(sed -n '/^local plugins = {/,/^}/p' ~/.config/nvim-old/lua/plugins/*.lua \
    | grep -v -E "^\s*--" | grep -oE "'[^']+/[^']+'" | tr -d "'" | sort -uf)
```

Lists every plugin the old config actually loaded that this config does not
enable. The `grep -v` drops the entries commented out in the old manifests --
without it the count is 57 rather than 38, since those entries are still text in
the manifest range. One caveat remains: a plugin ported under a fork shows up as
missing (the old manifest says `folke/todo-comments.nvim`, we run
`nishantpillai5/todo-comments.nvim`).

The old config had already disabled 19 of its own: opencode, copilot.vim,
copilot.lua, CopilotChat, coerce, jupytext, dap-python, eyeliner, outline,
easypick, leetcode, competitest, marp, luarocks, hardtime, strudel, beepboop,
presence, rest.nvim. Those are not gaps.

#### The 38, grouped

The keymaps listed are what came off with the plugin.

**Debugging** -- the largest single hole. `mfussenegger/nvim-dap`,
`rcarriga/nvim-dap-ui`, `Weissle/persistent-breakpoints.nvim`. `<F4>` `<F5>`
`<C-F5>` `<F6>` `<F8>` `<F9>` step/continue/stop, `mb` / `mB` breakpoint and
conditional breakpoint, `[b` / `]b`, `<leader>fbb` `fbc` `fbv` `fbf` telescope
pickers over breakpoints/configurations/variables/frames, `<leader>bb` dap-ui
toggle, `<leader>bK` eval, `<leader>zb` / `<leader>bz` virtual text.

**Testing** -- `nvim-neotest/neotest`. `<leader>ii` run, `iI` run all, `ix` stop,
`id` debug, `ia` attach, `ip` preview, `io` open, `<leader>ei` picker, `]i` `[i`.

**Diagnostic lists** -- `folke/trouble.nvim`. The whole `<leader>t*` family
(`tt` `td` `tD` `tq` `tL` `tg` `tl` `tf`), `<leader>J` / `<leader>K` and `<M-j>`
/ `<M-k>` next/prev, `gr` references. Two more trouble absences are listed
under Gaps that are not a missing plugin, below.

**Explorer and symbols** -- `nvim-neo-tree/neo-tree.nvim` (`<leader>ee` `eE`
`eb` `eg`, `<leader>fe` `fE`), `liuchengxu/vista.vim` (`<leader>es` / `eS`, plus
buffer-local `s`, `<leader>s`, `<leader>p`).

**Refactoring and search-replace** -- `ThePrimeagen/refactoring.nvim`
(`<leader>rr` `re` `rf` `rv` `ri` `rI` `rb` `rB`), `nvim-pack/nvim-spectre`
(`<leader>r/` `r?` `rw`), `smjonas/inc-rename.nvim` (`<leader>rn`).

**Notes** -- `iamcco/markdown-preview.nvim` (`<leader>zp`),
`MeanderingProgrammer/render-markdown.nvim`, `nfrid/due.nvim`,
`Pocco81/HighStr.nvim` (`<leader>zh*` persistent highlights with export/import),
`Avi-D-coder/whisper.nvim` (`<leader>ns` speech-to-text). obsidian.nvim,
global-note.nvim and calendar-vim are ported -- see Notes and journal,
above.

**Notebooks and data science** -- `quarto-dev/quarto-nvim`,
`benlubas/molten-nvim`, `jmbuhr/otter.nvim`, `3rd/image.nvim`,
`jbyuki/nabla.nvim`. Cell execution (`<leader>ii` `ij` `ik` `iI` `il`), kernel
select (`<leader>wi`), math preview (`<leader>iP`), inline images.

**Editing** -- `echasnovski/mini.align`, `chrisgrieser/nvim-recorder` (`q` `Q`
`cq` `dq` `yq` plus `<leader>q` slot switch), `AllenDang/nvim-expand-expr`
(`<leader>Q`), `mawkler/demicolon.nvim`. mini.surround is ported, in
`plugins/surround.lua`.

**LSP-adjacent** -- `VonHeikemen/lsp-zero.nvim` and `L3MON4D3/LuaSnip` are
deliberate (native LSP), but note there is no snippet engine here at all.
`chrisgrieser/nvim-rulebook` (`<leader>li` ignore rule, `lI` ignore formatter,
`lF` lookup code, `lY` yank code). `Bilal2453/luvit-meta` was a lazydev
dependency. `mtdl9/vim-log-highlighting`: `after/ftplugin/log.lua` only sets
`commentstring`, so log files have no syntax highlighting.

**Terminal and tasks** -- `pianocomposer321/officer.nvim` (`:Make` / `:Run`
through overseer), `sbulav/nredir.nvim` (`<leader>oRR`, command output to a
buffer).

**Workspaces** -- `xvzc/chezmoi.nvim` (`<leader>wC` dotfile picker).

**Misc** -- `dstein64/vim-startuptime`, `subnut/nvim-ghost.nvim` (edit browser
textareas), `tris203/hawtkeys.nvim` (keymap conflict analysis), `jrop/tuis.nvim`
(`<leader>fZ`), `theprimeagen/vim-be-good`.

#### The non-plugin layers are done

Diffed directly, so this does not need re-checking:

- **Keymaps.** 42 old core mappings against 40 here; the only two the diff
  reports are a `yc` that was commented out over there and the `<leader>ey*`
  loop, which is a literal table here (`core/keymaps.lua`).
- **Options.** Everything the old `set.lua` had and this one does not is either a
  0.11 default (`incsearch`, `autoread`, `showcmd`, `autochdir`,
  `termguicolors`, `netrw_banner`) or was already commented out there
  (`backup`, `swapfile`, `hlsearch`, `clipboard`, `updatetime`).
- **Autocmds and commands.** TermClose, terminal autoscroll with its claude
  exemption, last-place, the checktime pair, formatoptions, json to jsonc, `.str`
  to javascript, log and markdown `commentstring`, notes `conceallevel`,
  `ClearShada` -- all here. The TimeDiff virtual text is the one real gap.
- **env.** `DIR_LEET`, `VSC_CONFIG`, `GLOBAL_STATUS`, `PANEL_POSITION`,
  `PRESENTING`, `SCREEN` and `SIDEBAR_POSITION` are not in `util/env.lua`.

Not carried over at the repo level, deliberately: `Dockerfile`,
`docker-compose.yml`, `scripts/`, `sounds/`, `vscode_config/`, and `lua/vsc/`.

### Translating a spec

| Old | Here |
| --- | --- |
| a spec inside `lua/plugins/<topic>.lua` | its own `lua/plugins/<name>.lua`, plus a line in `lua/enabled.lua` |
| `cond = conds['owner/repo']` | delete it; presence in `enabled.lua` is the switch |
| `keys = require('config.x').keys` + `M.keymaps()` | inline `keys` in the spec, `desc` on each entry |
| `config = require('config.x').config` | `opts` when the plugin takes a table, else `config` |
| `get_keymap_setter(M.keys)` | plain `vim.keymap.set` with an inline `desc` |
| `require('common.env').X` | `require('util.env').X` |
| `require('common.utils').get_root_dir()` | `require('util').root_dir()` |
| `get_main_branch` / `get_fork_point` / `get_merge_base` | `require('util.git')` -- and note the old `get_main_branch` returns an untrimmed `"main\n"` |
| `M.lualine()` calling `lualine.setup` again | add the component to `lua/plugins/lualine.lua`; there is one `setup` call |
| `vim.fn.system` + `vim.v.shell_error` | `vim.system(...):wait()` |
| `starts_with`, `merge_list` | `vim.startswith`, `vim.list_extend` |

**Copy nerd-font icons by codepoint, not by retyping them.** Glyphs are easy to
drop silently when moving code between files, and an empty icon string usually
fails quietly -- a blank statusline segment rather than an error. To check a
ported file against its original:

```sh
python3 - <<'EOF'
import pathlib
a = pathlib.Path('OLD.lua').read_text(); b = pathlib.Path('NEW.lua').read_text()
cps = lambda t: {c for c in t if ord(c) > 0x2000}
print(sorted(f"U+{ord(c):04X}({c})" for c in cps(a) - cps(b)) or 'none lost')
EOF
```

### Gaps that are not a missing plugin

- **Treesitter highlighting is off.** `plugins/treesitter.lua` installs parsers
  and stops there, which is what the old config did too -- the `main` branch
  starts nothing by itself, so the theme's regex syntax is still what you see.
  The parsers exist for the plugins that query the tree. One
  `vim.treesitter.start()` in a `FileType` autocmd would switch it on.
- **`lua/overseer/component/custom/task_formatter.lua`** is not ported. It is
  absent from overseer's `component_aliases`, and depends on `beepboop` and the
  old `config.overseer` module.
- **The notes time-diff virtual text** (`lua/nvim/autocmd.lua`, the `TimeDiff`
  augroup) is not ported. It belongs in `after/ftplugin/markdown.lua`.
- **trouble.nvim absences**: telescope's `T` / `t` send-to-trouble mappings and
  `<leader>tT` (TodoTrouble) were dropped with it.
- **`NVIM_CONTEXT` only selects the dashboard logo here.** In the old config it
  also set `SCREEN`, `PANEL_POSITION` and `PRESENTING`; those became local
  constants in the files that used them, so the LSP indicator does not switch to
  icon-plus-name on a widescreen context.

## Future tasks

### Replace dressing.nvim, and settle on one input style

`dressing.nvim` is archived upstream. It is not broken -- it is a small, stable
shim over `vim.ui.select` and `vim.ui.input` -- so this is not urgent. Do it if
dressing breaks on a future Neovim, or when consolidating the input UI.

What depends on it today:

- `vim.ui.input` in `fugitive.lua` (branch name, two stash messages) and as the
  fallback in `git_worktree.lua`.
- `vim.ui.select` in `grapple.lua` (scope), `overseer.lua` (bundles) and
  `git_worktree.lua` (delete).
- overseer calls `vim.ui.select` internally in four of its own modules
  (`action_util`, `task_editor`, `task_bundle`, `commands`), so every
  `<leader>of` task action goes through it. This is why `overseer.lua` declares
  dressing as a dependency.

**Not** snacks.picker, despite snacks already being on disk. snacks is here only
as claudecode's terminal provider, and enabling its picker would put a second
picker UI next to telescope, which this config uses for everything. Prefer:

- `nvim-telescope/telescope-ui-select.nvim` for `vim.ui.select`, so those prompts
  match the picker used everywhere else.
- `snacks.input`, or plain native input, for `vim.ui.input`.

Two things to watch when swapping:

- `overseer.lua`'s bundle pickers pass `telescope = require('telescope.themes').get_cursor()`.
  Only dressing reads a per-call `opts.telescope` (`dressing/select/telescope.lua:141`);
  with telescope-ui-select the theme is configured once in the extension's opts
  instead.
- `git_worktree.lua` already bypasses `vim.ui.input` with its own nui centered
  float, because dressing renders input at the cursor. So there are two input
  styles today. Picking one is arguably the more valuable half of this task.
