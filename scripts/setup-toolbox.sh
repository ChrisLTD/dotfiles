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

sudo dnf install -y \
  neovim \
  git \
  gh \
  lazygit \
  tmux \
  ripgrep \
  fd-find \
  fzf \
  zsh \
  zoxide \
  eza \
  gcc \
  make \
  python3-pip \
  nodejs

# GitHub Copilot CLI extension
if ! gh extension list 2>/dev/null | grep -q "gh-copilot"; then
  gh extension install github/gh-copilot
fi
