---@meta

-- Hooks a project-local exrc file (see `lua/plugins/config_local.lua` for the
-- filenames it loads) may set to override a default. Nothing in this repo
-- assigns them, so without these declarations every read is an
-- `undefined-field` warning. `---@meta` makes this a definition file only: it
-- is never loaded at runtime.

---Overrides `util.ascii.logo()` in a work/present context.
---@type string[]|nil
_G.LOGO = nil

---Replaces `util.scope.select()`'s default neoscopes picker.
---@type fun()|nil
_G.select_workspace = nil

---Keeps a task out of the overseer build list when it returns false.
---@type fun(task: table): boolean|nil
_G.filter_build_tasks = nil

---Keeps a task out of the overseer run list when it returns false.
---@type fun(task: table): boolean|nil
_G.filter_run_tasks = nil

---Renders a task's label in the lualine indicator.
---@type fun(task: table): string|nil
_G.task_formatter = nil

---Extra `conform.nvim` formatters, merged over the defaults.
---@type table<string, string[]>|nil
_G.custom_formatters_by_ft = nil

---Extra `debugprint.nvim` filetype templates.
---@type table<string, table>|nil
_G.custom_debug_log = nil

---Passed straight to `gitlinker.setup()`.
---@type table|nil
_G.gitlinker_config = nil

---Extra `other.nvim` mappings, appended to the defaults.
---@type table[]|nil
_G.other_mappings = nil

---Filename neoscopes reads its scopes from.
---@type string|nil
_G.scope_config_file = nil

---Loads the workspace on startup when true.
---@type boolean|nil
_G.workspace_load_on_init = nil

---Branch new worktrees fork from; defaults to `origin/main`.
---@type string|nil
_G.worktree_from_branch = nil

---Paths symlinked into a new worktree; defaults to `.env` and `.vscode`.
---@type string[]|nil
_G.worktree_symlinks = nil

---Runs after a worktree is created.
---@type fun(path: string, branch: string)|nil
_G.worktree_create_callback = nil

---Merged over the defaults in `lsp/pyright.lua`.
---@type table|nil
_G.pyright_settings = nil

---Reads a project's env vars; consumed by toggleterm-manager and the
---`custom.vscode_env` overseer component.
---@type fun(): table<string, string>|nil
_G.env_reader = nil
