# dotfiles

Managed with [chezmoi](https://www.chezmoi.io/).

## New machine setup

```sh
chezmoi init git@github.com:ChrisLTD/dotfiles.git
chezmoi apply
```

`chezmoi init` will prompt for your git email address and write it to `~/.config/chezmoi/chezmoi.yaml` (local only, not committed).

## What's managed

| File | Notes |
|---|---|
| `~/.zshrc` | Shell config |
| `~/.zprofile` | gcloud SDK path (skipped silently if SDK not installed) |
| `~/.gitconfig` | Git config — email is templated per machine |
| `~/.config/git/ignore` | Global gitignore |
| `~/.tmux.conf` | Tmux config |
| `~/.config/yazi/yazi.toml` | Yazi file manager config |
| `~/.config/nvim/` | Neovim — cloned from [ChrisLTD/nvim](https://github.com/ChrisLTD/nvim) via external |
| `~/.claude/settings.json` | Claude Code settings |
| `~/.claude/agents/` | Claude Code custom agents |
| `~/.claude/commands/` | Claude Code slash commands |
| `~/.claude-business/agents/` | Symlink → `~/.claude/agents/` |
| `~/.claude-business/commands/` | Symlink → `~/.claude/commands/` |
| `~/.Brewfile` | Homebrew bundle — formulas and casks for macOS |

## Package installation

`chezmoi apply` automatically runs platform-specific install scripts:

- **Mac** (`run_onchange_install-mac-packages.sh.tmpl`): installs Homebrew if missing, then runs `brew bundle --global` using `~/.Brewfile`. Re-runs automatically whenever `~/.Brewfile` changes.
- **Fedora Silverblue** (`run_onchange_install-fedora-packages.sh.tmpl`): adds Flathub remote, installs Flatpak apps, and applies GNOME settings via `gsettings`.

Each script guards itself with an OS check and exits immediately on the wrong platform.

### Adding a Homebrew package (Mac)

```sh
chezmoi edit ~/.Brewfile   # add the formula or cask
chezmoi apply              # installs new packages via brew bundle
cd ~/.local/share/chezmoi && git add . && git commit -m "Add <package> to Brewfile"
```

### Adding a Flatpak app (Fedora Silverblue)

```sh
chezmoi edit ~/.local/share/chezmoi/run_onchange_install-fedora-packages.sh.tmpl
# add a new flatpak install line, then:
chezmoi apply
cd ~/.local/share/chezmoi && git add . && git commit -m "Add <app> flatpak"
```

### GNOME extensions (Fedora Silverblue — manual)

Install via Extension Manager app. Recommended extensions:
- **Clipboard Indicator** — exclude `com.onepassword.OnePassword`, toggle shortcut: `shift-super-v`
- **PaperWM** — tiling window management
- **Night Theme Switcher**

## Adding a new agent or command

```sh
chezmoi add ~/.claude/agents/new-agent.md
cd ~/.local/share/chezmoi && git add . && git commit -m "Add new-agent"
```

It will automatically be available in both `~/.claude/` and `~/.claude-business/` via the symlinks.

## Adding a new dotfile

```sh
chezmoi add ~/.some-config-file
cd ~/.local/share/chezmoi && git add . && git commit -m "Add some-config-file"
```

## Editing a managed dotfile

Edit the file directly in your home directory, then re-add it to sync the change into chezmoi:

```sh
# Edit as normal, e.g.:
vim ~/.zshrc

# Sync the change into the chezmoi source
chezmoi add ~/.zshrc

# Commit
cd ~/.local/share/chezmoi && git add . && git commit -m "Update zshrc"
```

Or edit the source file directly and apply:

```sh
chezmoi edit ~/.zshrc   # opens the source file in $EDITOR
chezmoi apply
cd ~/.local/share/chezmoi && git add . && git commit -m "Update zshrc"
```

## Pulling updates on another machine

```sh
chezmoi update   # pull latest and apply
```
