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

# Render the shared CLI list from .chezmoidata/cli_packages.yaml
SHARED_DNF=$("$CHEZMOI" execute-template '{{ range .cli_packages }}{{ .dnf }} {{ end }}')

# Toolbox-only packages (build tools, language toolchains, host-installed-via-XCode-on-Mac)
TOOLBOX_ONLY=(
  git
  fd-find
  zsh
  gcc
  make
  python3-pip
  nodejs
)

# shellcheck disable=SC2086
sudo dnf install -y $SHARED_DNF "${TOOLBOX_ONLY[@]}"

# GitHub Copilot CLI extension
if ! gh extension list 2>/dev/null | grep -q "gh-copilot"; then
  gh extension install github/gh-copilot
fi
