# CLAUDE.md — dotfiles project context

This repo is managed with [chezmoi](https://www.chezmoi.io/). It handles both dotfile deployment and automated package installation on Mac and Fedora Silverblue.

## What's here

| Source file | Deploys to | Purpose |
|---|---|---|
| `dot_zshrc` | `~/.zshrc` | Shell config |
| `dot_zprofile.tmpl` | `~/.zprofile` | gcloud SDK path (templated) |
| `dot_gitconfig.tmpl` | `~/.gitconfig` | Git config (email templated) |
| `dot_tmux.conf` | `~/.tmux.conf` | Tmux config |
| `dot_config/yazi/` | `~/.config/yazi/` | Yazi file manager config |
| `dot_config/git/` | `~/.config/git/` | Global gitignore |
| `dot_claude/` | `~/.claude/` | Claude Code settings, agents, commands |
| `dot_Brewfile` | `~/.Brewfile` | Homebrew bundle (Mac only) |
| `run_onchange_install-mac-packages.sh.tmpl` | — | Mac: installs Homebrew + brew bundle |
| `run_onchange_install-fedora-packages.sh.tmpl` | — | Fedora: installs Flatpak apps + gsettings |

Neovim config is pulled via `.chezmoiexternal.toml` from a separate git repo.

## How `chezmoi apply` works

Both install scripts are `.tmpl` files with an OS guard at the top. On Mac, the Fedora script exits immediately (`exit 0`); on Fedora, the Mac script exits immediately. So `chezmoi apply` is safe to run on either platform.

The `run_onchange_` prefix means each script re-runs automatically whenever its content changes — adding a package to `dot_Brewfile` or to the Flatpak list triggers a re-run on the next `chezmoi apply`.

## Common commands

```sh
chezmoi apply                  # deploy all files and run install scripts
chezmoi apply --dry-run -v     # preview what would change
chezmoi edit ~/.Brewfile       # edit Brewfile, then chezmoi apply
chezmoi update                 # pull latest from git and apply
```

## Fedora Silverblue setup — current state and TODOs

### What the install script does automatically (`chezmoi apply`)

- Adds Flathub remote
- Installs these Flatpak apps:
  - `com.google.Chrome`
  - `com.mattjakeman.ExtensionManager`
  - `com.onepassword.OnePassword`
  - `app.drey.Gradia`
  - `de.haeckerfelix.Shortwave`
  - `io.github.focustimerhq.FocusTimer`
  - `md.obsidian.Obsidian`
  - `org.gnome.Epiphany`
  - `org.gnome.Solanum`
  - `org.localsend.localsend_app`
  - `org.mozilla.firefox`
- Sets Caps Lock → Escape via gsettings

### TODOs / verify on Fedora

- [ ] Confirm all Flatpak IDs above are correct (some may differ on Flathub)
- [x] Constrict — `io.github.wartybix.Constrict` (added to script)
- [ ] Decide whether to add any "maybe" apps (commented out in script):
  - `app.drey.Keypunch`, `com.github.dynobo.normcap`, `com.github.tchx84.Flatseal`, `org.gnome.World.PikaBackup`, `org.gnome.DejaDup`
- [ ] Install GNOME extensions manually via Extension Manager:
  - **Clipboard Indicator** — after installing: exclude `com.onepassword.OnePassword`, set toggle shortcut to `shift-super-v`
  - **PaperWM**
  - **Night Theme Switcher** (https://nightthemeswitcher.romainvigier.fr/)
- [ ] Set up Toolbox or Distrobox for CLI dev tools (neovim, gh, lazygit, etc.)
- [ ] Terminal (Ptyxis) settings — manual, no automation available:
  - New tab: `ctrl-t`, Close tab: `ctrl-w`, Next: `ctrl-tab`, Prev: `shift-ctrl-tab`
  - Theme: Tokyo Night, Font: Source Code Pro 12, Line spacing: 1.1, Cursor: i-beam
- [ ] Web (Epiphany) — create web apps for YouTube Music, Numbr.dev
- [ ] Firefox — disable swipe navigation: open `about:config`, set `browser.gesture.swipe.left` and `browser.gesture.swipe.right` to empty strings
- [ ] Hardware settings (manual in GNOME Settings):
  - Trackpad: natural scrolling
  - Pointing Stick: sensitivity 45%
  - Mouse: natural scrolling, sensitivity 15%
  - Graphics Tablet: map to monitor (Dell), left button = switch monitors, keep aspect ratio, tip pressure = softest
- [ ] Enable fingerprint login: System → User → Fingerprint (right + left index)
- [ ] Consider setting up compose key for text expansion

## Adding a package

**Mac:**
```sh
chezmoi edit ~/.Brewfile   # add brew/cask line
chezmoi apply
cd ~/.local/share/chezmoi && git add . && git commit -m "Add <package>"
```

**Fedora:**
```sh
chezmoi edit ~/.local/share/chezmoi/run_onchange_install-fedora-packages.sh.tmpl
# add flatpak install line, then:
chezmoi apply
cd ~/.local/share/chezmoi && git add . && git commit -m "Add <app> flatpak"
```
