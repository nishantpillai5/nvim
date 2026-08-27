# A throwaway box that runs *this* config and nothing else, so a change can be
# tried against a clean machine:
#
#   docker compose run --rm nvim
#
# docker-compose.yml bind-mounts the repo at ~/.config/nvim, so `nvim` inside the
# container is this config, live from the host. Plugins, parsers and mason's
# binaries are installed while the image is built, not on first run.
FROM archlinux:base

# tree-sitter-cli and a compiler are not optional here: nvim-treesitter's `main`
# branch builds every parser in util/parsers.lua from source. git-delta is what
# telescope's diff previewer uses when it is on PATH, and npm/pip/go/cargo are
# what :MasonInstallAll builds its packages with.
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
      base-devel \
      cargo \
      curl \
      fd \
      fzf \
      gcc \
      git \
      git-delta \
      go \
      gzip \
      lazygit \
      make \
      neovim \
      npm \
      pkg-config \
      python-pip \
      python3 \
      ripgrep \
      tree-sitter-cli \
      unzip \
      wget \
      zsh && \
    rm -rf /var/cache/pacman/pkg/*

# Arch is rolling, so the neovim it ships moves. This config targets 0.12 APIs
# (vim.lsp.config / vim.lsp.enable, vim.lsp.completion, vim.fs.rm, winborder),
# which fail one require at a time rather than up front -- so assert the version
# while the image is being built instead.
RUN nvim --version | head -n 1 && \
    nvim --headless -u NONE -i NONE \
      +'lua if vim.fn.has("nvim-0.12") == 0 then io.stderr:write("this config needs Neovim 0.12+\n") vim.cmd "cquit 1" end' \
      +qa

# plugins/claudecode.lua drives this binary. Credentials are not baked: compose
# keeps ~/.claude in a volume so `claude login` survives, and passes
# ANTHROPIC_API_KEY through from the host.
RUN npm install -g @anthropic-ai/claude-code && npm cache clean --force

# On Linux a bind mount keeps the host's uid, which has to exist in here for the
# repo to be writable. Defaults suit a single-user Linux box; macOS ignores
# ownership under Docker Desktop, so leave them alone there -- passing macOS ids
# would collide GID 20 (staff) with Arch's dialout group and fail the build.
ARG UID=1000
ARG GID=1000

# Create the user before anything lands in its home. The old Dockerfile built the
# python venv first and then useradd'd over the top of it, leaving the venv
# root-owned inside the user's own home.
RUN groupadd -g $GID nvimuser && \
    useradd -m -u $UID -g $GID -s /bin/bash nvimuser

USER nvimuser
# Docker's HOME handling for USER varies by version, and every step below reads
# it -- the venv path, lazy's data dir, the COPY target.
ENV HOME=/home/nvimuser
WORKDIR /home/nvimuser

# core/options.lua points python3_host_prog at util.env's NVIM_PYTHON, which
# defaults to exactly this path.
RUN python -m venv $HOME/.virtualenvs/neovim && \
    $HOME/.virtualenvs/neovim/bin/python -m pip install -U pynvim

# Everything below is the warm-up, and it is last on purpose: editing the config
# invalidates the COPY, and only these layers get rebuilt.
#
# lazy's clones, mason's binaries and treesitter's parsers all land under
# ~/.local. compose mounts a named volume there, and Docker seeds a *new* named
# volume from whatever the image already has at that path -- which is how this
# warm-up reaches runtime. An existing volume keeps its own contents, so pick the
# baked ones up with `docker volume rm nvim_nvim-local` once.
COPY --chown=nvimuser:nvimuser . $HOME/.config/nvim

# Two passes: install fetches what is missing, restore pins every plugin to the
# commit in lazy-lock.json rather than whatever HEAD happens to be. Both block in
# headless mode.
RUN nvim --headless '+Lazy! install' +qa && \
    nvim --headless '+Lazy! restore' +qa

# install() is async, so the config's own call at startup would be cut off when
# nvim exits. Ask for the same list and wait on it.
RUN nvim --headless \
      '+lua require("nvim-treesitter").install(require("util.parsers")):wait(900000)' +qa && \
    nvim --headless '+lua print("parsers:", #require("nvim-treesitter.config").get_installed())' +qa

# mason's :MasonInstall blocks when there is no UI, and `1cq`s on an unknown
# package name -- so a typo in core/lsp.lua's MASON_PACKAGES fails the build.
RUN nvim --headless '+MasonInstallAll' +qa

CMD ["nvim"]
