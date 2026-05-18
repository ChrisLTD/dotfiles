# dotfiles

Managed with [chezmoi](https://www.chezmoi.io/).

## New machine setup

These steps assume a brand new machine with no chezmoi installed.

### 1. Prerequisites

**Mac:** install the Xcode Command Line Tools (provides `git`):

```sh
xcode-select --install
```

**Fedora Silverblue:** `git` ships with the base image, no action needed.

### 2. Install chezmoi and apply in one step

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply ChrisLTD/dotfiles
```

This downloads chezmoi to `~/.local/bin/chezmoi` (which is on PATH on Fedora by default and added to PATH in `dot_zshrc` for Mac), clones the repo over HTTPS, prompts for your git email (written to `~/.config/chezmoi/chezmoi.yaml`, local only), and runs `chezmoi apply` — which then runs the platform-specific install script (Homebrew + `brew bundle` on Mac, Flatpak apps + gsettings on Fedora).

### 3. (Optional) SSH key for pushing changes back

The repo is public, so HTTPS clone works without auth. If you plan to commit and push edits from this machine, add an SSH key to GitHub and switch the chezmoi source remote to SSH:

```sh
ssh-keygen -t ed25519 -C "your_email@example.com"
# Add ~/.ssh/id_ed25519.pub at https://github.com/settings/keys
git -C "$(chezmoi source-path)" remote set-url origin git@github.com:ChrisLTD/dotfiles.git
```

### Subsequent runs

```sh
chezmoi apply                  # re-apply local source
chezmoi update                 # pull latest from git and apply
```

## What's managed

| File | Notes |
|---|---|
| `~/.zshrc` | Shell config |
| `~/.zprofile` | gcloud SDK path (skipped silently if SDK not installed) |
| `~/.gitconfig` | Git config — email is templated per machine |
| `~/.config/git/ignore` | Global gitignore |
| `~/.tmux.conf` | Tmux config |
| `~/.wezterm.lua` | WezTerm config |
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

### Adding a Homebrew package (Mac-only)

For tools you only want on Mac (casks, `mas` apps, Mac-only formulas):

```sh
chezmoi edit ~/.Brewfile   # add the formula or cask
chezmoi apply              # installs new packages via brew bundle
cd ~/.local/share/chezmoi && git add . && git commit -m "Add <package> to Brewfile"
```

### Adding a shared CLI (Mac + Fedora toolbox)

For CLI tools you want on both platforms, edit the shared list:

```sh
chezmoi edit ~/.local/share/chezmoi/.chezmoidata/cli_packages.yaml
chezmoi apply              # Mac: rerenders Brewfile and runs brew bundle
# Inside the Fedora toolbox:
bash ~/.local/share/chezmoi/scripts/setup-toolbox.sh
cd ~/.local/share/chezmoi && git add . && git commit -m "Add <tool> to shared CLIs"
```

`dot_Brewfile.tmpl` and `scripts/setup-toolbox.sh` both read from `.chezmoidata/cli_packages.yaml`, so a single edit propagates to both. Each entry has a `brew` and `dnf` name (most are identical; some differ, e.g. `tree-sitter` / `tree-sitter-cli`).

### Adding a Flatpak app (Fedora Silverblue)

```sh
chezmoi edit ~/.local/share/chezmoi/run_onchange_install-fedora-packages.sh.tmpl
# add a new flatpak install line, then:
chezmoi apply
cd ~/.local/share/chezmoi && git add . && git commit -m "Add <app> flatpak"
```

### Dev CLIs in a Toolbox (Fedora Silverblue)

CLI dev tools (nvim, gh, lazygit, ripgrep, language toolchains) live in a [Toolbox](https://containertoolbx.org/) container, not on the immutable host. `$HOME` is bind-mounted into the toolbox, so dotfiles applied by chezmoi on the host work as-is inside the container.

```sh
# One-time setup
toolbox create
toolbox enter
bash ~/.local/share/chezmoi/scripts/setup-toolbox.sh
```

To make Ptyxis open new tabs directly into the toolbox running zsh:

1. Open Ptyxis → hamburger menu → **Preferences**
2. Select your profile (or "Default") → **Edit**
3. Under the **Command** tab:
   - Set **Container** to your toolbox name (e.g. `fedora-toolbox-41`)
   - Toggle **Custom command** on
   - Enter: `/usr/bin/zsh -l`

The `-l` flag makes it a login shell so `~/.zprofile` is sourced; `~/.zshrc` then runs because `$HOME` is bind-mounted into the toolbox.

There's also an **experimental, untested** helper that automates these `gsettings` calls — `scripts/setup-ptyxis.sh`. Ptyxis schema keys can change between releases, so verify with `gsettings list-keys org.gnome.Ptyxis.Profile` first if it doesn't take effect. Usage:

```sh
bash ~/.local/share/chezmoi/scripts/setup-ptyxis.sh [container-name]
```

To add a tool: if it should also be on Mac, add it to `.chezmoidata/cli_packages.yaml` (see "Adding a shared CLI" above). For toolbox-only packages (build tools, language toolchains), edit the `TOOLBOX_ONLY` array in `scripts/setup-toolbox.sh`. Either way, re-run the script inside the toolbox.

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
