#!/bin/bash
# Install dev CLIs inside a Fedora toolbox.
#
# Usage:
#   toolbox create
#   toolbox enter
#   bash ~/.local/share/chezmoi/scripts/setup-toolbox.sh
#
# $HOME is bind-mounted from the host, so chezmoi-applied dotfiles
# (~/.zshrc, ~/.config/nvim, ~/.tmux.conf, ~/.gitconfig) work as-is.

set -euo pipefail

if [ ! -f /run/.containerenv ] && [ ! -f /.dockerenv ]; then
  echo "Refusing to run: this script is meant for inside a toolbox container." >&2
  exit 1
fi

CHEZMOI="${CHEZMOI:-$(command -v chezmoi || echo "$HOME/.local/bin/chezmoi")}"
if [ ! -x "$CHEZMOI" ]; then
  echo "chezmoi not found at \$PATH or $HOME/.local/bin. Run new-machine setup on the host first." >&2
  exit 1
fi

# Render the shared CLI list from .chezmoidata/cli_packages.yaml into an array
# (one package per line so names can't be word-split unexpectedly).
mapfile -t SHARED_DNF < <("$CHEZMOI" execute-template '{{ range .cli_packages }}{{ .dnf }}{{ "\n" }}{{ end }}')

# Toolbox-only packages. fedora-toolbox already ships with git, so it's
# omitted here. gcc/make come from Xcode CLT on Mac, not the Brewfile.
# rust+cargo are needed for the cargo-installed tools below.
TOOLBOX_ONLY=(
  fd-find
  zsh
  gcc
  make
  python3-pip
  rust
  cargo
)

sudo dnf install -y "${SHARED_DNF[@]}" "${TOOLBOX_ONLY[@]}"

# GitHub Copilot CLI extension
if ! gh extension list 2>/dev/null | grep -q "gh-copilot"; then
  gh extension install github/gh-copilot
fi

# --- Tools not in dnf (each guarded so re-runs are quick) ---

# mise — runtime version manager
if ! command -v mise >/dev/null; then
  cargo install --locked mise
fi

# tlrc — Rust tldr-pages client (binary is `tldr`)
if ! command -v tldr >/dev/null; then
  cargo install --locked tlrc
fi

# yazi — terminal file manager (already configured via dot_config/yazi/).
# yazi-fm provides the `yazi` TUI; yazi-cli adds `ya` for plugin/theme
# management (`ya pack`) and pub/sub shell integrations.
if ! command -v yazi >/dev/null; then
  cargo install --locked yazi-fm yazi-cli
fi

# pnpm — via corepack, which ships with the dnf nodejs package
if ! command -v pnpm >/dev/null && command -v corepack >/dev/null; then
  sudo corepack enable pnpm
fi

# goose — pressly DB migrations (https://github.com/pressly/goose)
if ! command -v goose >/dev/null; then
  go install github.com/pressly/goose/v3/cmd/goose@latest
fi

# git-spice — stacked PR manager (https://github.com/abhinav/git-spice)
if ! command -v gs >/dev/null; then
  go install go.abhg.dev/gs/cmd/gs@latest
fi
