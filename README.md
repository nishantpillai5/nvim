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
- `lua/plugins/snacks.lua` provides `vim.ui.input` and `vim.ui.select`, which
  dressing.nvim used to. dressing is archived upstream and snacks was already on
  disk as claudecode's terminal provider, so replacing it enabled two snacks
  modules rather than adding a plugin. Only `input` and `picker` are on --
  telescope is still the finder behind every mapping, and `picker` is here for
  `vim.ui.select` alone. Two things the swap changed: `overseer.lua`'s bundle
  pickers no longer pass `telescope = require('telescope.themes').get_cursor()`,
  a per-call option only dressing read; and `git_worktree.lua` dropped its own
  nui centered float for the create prompt, because snacks.input floats
  centered where dressing rendered at the cursor. There is one input style now.

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
first `<leader>n` mapping, and `plugins/calendar.lua`,
`plugins/global_note.lua` and `plugins/markdown_preview.lua` sit beside it.

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
- **markdown-preview is `<leader>zP`, not the old `<leader>zp`.** `<leader>zp` is
  the Pomodoro prefix here, and a buffer-local `<leader>zp` completes on its own,
  so the old binding swallowed `<leader>zp*` in every markdown buffer -- i.e. in
  the whole vault. The mapping is still buffer-local to markdown; `:MarkdownPreview`
  and friends work anywhere. `MarkdownPreviewToggleTheme` is this config's command
  rather than the plugin's, as it was before -- it flips `g:mkdp_theme` (`dark` at
  startup) and re-opens the page, since the theme is read as the page opens.
- **The preview server is a prebuilt binary.** The spec's `build` calls
  `mkdp#util#install_sync`, which downloads the release binary, in place of the old
  `cd app && yarn install`: no yarn or node, and it blocks, so the Dockerfile's
  headless `Lazy! install` actually completes it. The async `mkdp#util#install`
  opens a terminal window and returns, which headless Neovim would cut off.
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

`plugins/overseer.lua` wraps `vim.ui.select` for the `overseer_template` kind
so `<leader>oo` lists `.vscode/tasks.json` tasks above everything else. Overseer
v2 removed template sort priority and orders templates by provider-discovery
order, which is the alphabetical runtimepath glob -- npm before vscode.
`MODULE_ORDER` in that file is the list of template modules to float to the top.

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

## Containers

Two unrelated things, both from the old config:

- **`Dockerfile` + `docker-compose.yml`** build a throwaway Arch box that *runs*
  this config, for trying a change against a clean machine:
  `docker compose run --rm nvim`. The repo is bind-mounted at
  `~/.config/nvim`, so `nvim` in the container is this config, live from the
  host -- `lazy-lock.json` included, so a plugin update inside is a change you
  can commit outside. `~/.local` is a named volume, so plugin clones, mason
  binaries and treesitter parsers survive between runs, and `$HOME/notes` is
  bind-mounted at DIR_NOTES.
- **`.devcontainer.json`** is for working *on* the config with Claude Code behind
  the firewall feature. Its image carries node and the CLI, not neovim.
  `postCreateCommand` symlinks the workspace to `~/.config/nvim`, which is where
  `DIR_NVIM`, the `<leader>ii` source maps and `enabled.lua`'s loader all expect
  to find it.

`.dockerignore` keeps `.git`, `.env`, `.claude` and the container files
themselves out of the build context; the config itself has to be in it, since the
image warms up against it.

What changed on the way over:

- **The neovim version is asserted at build time.** Arch is rolling, so the
  neovim it ships moves, and this config's 0.12 APIs fail one `require` at a
  time rather than up front. The build runs `has('nvim-0.12')` and `cquit 1`s if
  it is older.
- **The user is created before anything lands in its home.** The old Dockerfile
  built the python venv first and then `useradd`d over the top, leaving the venv
  root-owned inside the user's own home.
- **luarocks is gone**, along with `lua51`, the `.luarocks/config-5.1.lua` and
  the `lazy-rocks` directory. `core/lazy.lua` sets `rocks = { enabled = false }`.
- **`tree-sitter-cli` earns its place now.** nvim-treesitter's `main` branch
  builds every parser in `util/parsers.lua` from source, so it and a compiler are
  load-bearing rather than leftovers.
- **`git-delta` added**, since telescope's diff previewer uses it when it is on
  PATH. **`yarn`, `ruby` and `imagemagick` dropped** -- yarn built
  markdown-preview's server, which now arrives as a prebuilt binary over curl,
  and ruby and imagemagick were image.nvim's, which did not come over.
  `pacman -Scc` would have taken the sync database with the package cache, so the
  cleanup is `rm -rf /var/cache/pacman/pkg/*` instead.
- **`$HOME/notes` is mounted**, which it was not before: obsidian's `event`
  never fires without the directory, and calendar and global-note both read it.

### Warm image

The last four layers install everything a first run used to: `Lazy! install`
then `Lazy! restore` (the second pins every plugin to `lazy-lock.json` rather
than whatever HEAD happens to be), the parsers, and `:MasonInstallAll`. All of
them block without a UI, and mason `1cq`s on an unknown package name -- so a typo
in `core/lsp.lua`'s `MASON_PACKAGES` fails the build rather than the editor.

- **The parser list moved to `lua/util/parsers.lua`.** `plugins/treesitter.lua`
  requires it, and so does the build, which calls
  `install(require 'util.parsers'):wait(...)` -- the config's own call is async
  and would be cut off when headless nvim exits. One list, two callers.
- **How the warm-up reaches runtime**: all three write under `~/.local`, and
  Docker seeds a *new* named volume from whatever the image has at that path. An
  existing volume keeps its own contents, so pick the baked ones up once with
  `docker volume rm nvim_nvim-local`.
- **The COPY is the last cache boundary on purpose.** Editing the config
  invalidates it, so a rebuild redoes the warm-up but not the pacman layers. You
  do not normally rebuild -- the bind mount is live -- only when plugins change.

### Claude, clipboard, uid

- **`claude` is installed** (`npm install -g @anthropic-ai/claude-code`), so
  `plugins/claudecode.lua` has something to talk to. Credentials are not baked:
  `~/.claude` is a named volume so `claude login` survives, and
  `ANTHROPIC_API_KEY` is passed through when it is set in the host environment.
  A volume rather than a bind of the real `~/.claude` -- the same call
  `.devcontainer.json` makes.
- **The `"+` maps work through OSC 52.** A container has no display server, so
  xclip would have nothing to talk to; compose sets `NVIM_CONTAINER`, and
  `core/options.lua` turns that into `vim.g.clipboard = 'osc52'`, which hands the
  yank to the host's terminal. Copy is widely supported, paste needs the terminal
  to answer the query and often does not -- so `<leader>y` lands and `<leader>p`
  may not.
- **uid is a build arg.** `UID`/`GID` default to 1000, which is what macOS wants
  (Docker Desktop ignores ownership, and real macOS ids would fail the build --
  GID 20 is `staff` there and `dialout` on Arch). On Linux, once:

  ```sh
  printf 'UID=%s\nGID=%s\n' "$(id -u)" "$(id -g)" > .env
  ```

  compose reads `.env` on its own, and `.gitignore` keeps it out of the repo.

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
without it the count is 56 rather than 37, since those entries are still text in
the manifest range. One caveat remains: a plugin ported under a fork shows up as
missing (the old manifest says `folke/todo-comments.nvim`, we run
`nishantpillai5/todo-comments.nvim`).

The old config had already disabled 19 of its own: opencode, copilot.vim,
copilot.lua, CopilotChat, coerce, jupytext, dap-python, eyeliner, outline,
easypick, leetcode, competitest, marp, luarocks, hardtime, strudel, beepboop,
presence, rest.nvim. Those are not gaps.

#### The 37, grouped

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

**Notes** -- `MeanderingProgrammer/render-markdown.nvim`, `nfrid/due.nvim`,
`Pocco81/HighStr.nvim` (`<leader>zh*` persistent highlights with export/import),
`Avi-D-coder/whisper.nvim` (`<leader>ns` speech-to-text). obsidian.nvim,
global-note.nvim, calendar-vim and markdown-preview.nvim are ported -- see Notes
and journal, above.

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

Not carried over at the repo level, deliberately: `scripts/`, `sounds/`,
`vscode_config/`, and `lua/vsc/`. `Dockerfile`, `docker-compose.yml`,
`.dockerignore` and `.devcontainer.json` are ported -- see Containers, above.

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

### Fill the which-key gaps

Some mappings exist but which-key cannot advertise them, either because they
only come into being when a plugin loads or attaches, or because whoever
installed them left no `desc` to read. Found by snapshotting every global and
buffer-local mapping at startup, force-loading all plugins, and diffing the
result against the `spec` in `plugins/whichkey.lua`.

Created on attach, so absent until then:

- **gitsigns** installs `]c`, `[c`, `<leader>gh*`, `<leader>gRj`, `<leader>gV`
  and `ih` in its `on_attach`, buffer-locally. In a tracked file they are all
  there with descs; in the dashboard, a `:enew` buffer or any file outside a git
  repo the `]` menu simply has no `c`. Only `<leader>gB` is a lazy `keys` stub.
  Spec entries for `]c` / `[c` would advertise them everywhere, at the cost of
  the label being a small lie in buffers where the key does nothing.
- **LSP** maps `<leader>l*`, `<leader>r*` and `gr*` from `core/lsp.lua` on
  `LspAttach`. Consequence: the `<leader>r` Refactor group declared in
  `whichkey.lua` is an empty menu in every buffer without a server -- the
  caveat the group list's own header comment describes.

Installed by the plugin with no `desc`:

- **calendar-vim** binds `<leader>cal` and `<leader>caL` (`<Plug>CalendarV` /
  `CalendarH`) because `calendar.lua` sets `calendar_no_mappings = 0`. They show
  as the raw `<Plug>` name, inside the `<leader>c` Chat group. Either give them
  descs in the spec or flip the flag to `1` if the mappings are unwanted.
- **mini.surround** adds next/prev variants beyond the six keys the spec names:
  `<leader>Vdl`/`Vdn`, `Vfl`/`Vfn`, `VFl`/`VFn`, `Vhl`/`Vhn`, `Vrl`/`Vrn`. They
  arrive with mini's own sentence-case descs ("Delete previous surrounding"),
  which do not match the lowercase style used everywhere else here.
- **vim-illuminate** maps `<M-i>` in operator-pending and visual with no desc.
  Its `<M-n>` / `<M-p>` do have one.
- **llama.vim** takes global normal-mode `<Tab>` and `<Esc>`
  (`llama#inst_accept` / `inst_cancel`), undescribed. Worth knowing about for
  the `<Esc>` grab as much as for which-key.
- **fugitive**'s `y<C-G>` and **matchit**'s `%`, `[%`, `]%`, `g%`, `a%` are
  undescribed too. Upstream, and cosmetic.

Already handled, listed so they are not rediscovered: trailblazer's `m*` keys,
`<leader>m`, and mini.surround's six base `<leader>V*` keys all get their labels
from entries in the whichkey spec.
