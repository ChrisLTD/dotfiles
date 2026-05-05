#!/bin/bash
# EXPERIMENTAL / UNTESTED — automate Ptyxis profile setup for toolbox + zsh.
#
# Run this on the HOST (not inside the toolbox), after `toolbox create`.
# It points your default Ptyxis profile at the toolbox container and
# launches /usr/bin/zsh -l inside it.
#
# Caveats:
#   - The Ptyxis gsettings schema is young; key names (container-runtime,
#     container-name, custom-command, use-custom-command) may rename
#     between releases. Verify first with:
#       gsettings list-keys org.gnome.Ptyxis.Profile
#   - This modifies the *default* profile. If you have multiple profiles,
#     you may want to create a new one instead.
#   - If Ptyxis hasn't been launched yet, the schema may not be present.
#
# Usage:
#   bash ~/.local/share/chezmoi/scripts/setup-ptyxis.sh [container-name]
#
# If container-name is omitted, the first toolbox listed by `toolbox list -c`
# is used.

set -euo pipefail

if [ -f /run/.containerenv ] || [ -f /.dockerenv ]; then
  echo "Refusing to run: this script must run on the host, not inside a container." >&2
  exit 1
fi

if ! command -v gsettings >/dev/null; then
  echo "gsettings not found. This script requires GNOME / dconf." >&2
  exit 1
fi

if ! gsettings list-schemas 2>/dev/null | grep -q '^org.gnome.Ptyxis$'; then
  echo "Ptyxis gsettings schema not found. Launch Ptyxis at least once, then re-run." >&2
  exit 1
fi

container="${1:-}"
if [ -z "$container" ]; then
  container=$(toolbox list -c 2>/dev/null | awk 'NR>1 {print $2; exit}')
fi
if [ -z "$container" ]; then
  echo "No toolbox container found. Pass one as the first argument or run 'toolbox create' first." >&2
  exit 1
fi

uuid=$(gsettings get org.gnome.Ptyxis default-profile-uuid | tr -d "'")
if [ -z "$uuid" ]; then
  echo "Could not read Ptyxis default-profile-uuid." >&2
  exit 1
fi

path="/org/gnome/Ptyxis/Profiles/$uuid/"

gsettings set "org.gnome.Ptyxis.Profile:$path" container-runtime 'toolbox'
gsettings set "org.gnome.Ptyxis.Profile:$path" container-name "$container"
gsettings set "org.gnome.Ptyxis.Profile:$path" use-custom-command true
gsettings set "org.gnome.Ptyxis.Profile:$path" custom-command '/usr/bin/zsh -l'

echo "Configured Ptyxis default profile:"
echo "  container = $container"
echo "  shell     = /usr/bin/zsh -l"
echo "Open a new Ptyxis window/tab to take effect."
