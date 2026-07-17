# CLAUDE.md — dotfiles project context

This repo is managed with [chezmoi](https://www.chezmoi.io/). It handles both dotfile deployment and automated package installation on Mac and Fedora Silverblue.

> [worktrunk](https://github.com/max-sixty/worktrunk) (`wt`) is installed for git worktree management.

## What's here

| Source file | Deploys to | Purpose |
|---|---|---|
| `dot_zshrc` | `~/.zshrc` | Shell config |
| `dot_zprofile.tmpl` | `~/.zprofile` | gcloud SDK path (templated) |
| `dot_gitconfig.tmpl` | `~/.gitconfig` | Git config (email templated) |
| `dot_tmux.conf` | `~/.tmux.conf` | Tmux config |
| `dot_config/yazi/` | `~/.config/yazi/` | Yazi file manager config |
| `dot_gitignore` | `~/.gitignore` | Global gitignore (wired via `core.excludesfile` in `dot_gitconfig.tmpl`) |
| `dot_claude/` | `~/.claude/` | Claude Code settings, agents, commands |
| `dot_Brewfile.tmpl` | `~/.Brewfile` | Homebrew bundle (Mac only). Templated — shared CLIs are rendered from `.chezmoidata/cli_packages.yaml` |
| `.chezmoidata/cli_packages.yaml` | — | Source of truth for CLIs installed on both Mac (brew) and Fedora toolbox (dnf). Each entry has `brew:` and `dnf:` names |
| `run_onchange_install-mac-packages.sh.tmpl` | — | Mac: installs Homebrew + brew bundle. Hash includes `cli_packages` JSON, so editing the shared list re-triggers `brew bundle` |
| `run_onchange_install-fedora-packages.sh.tmpl` | — | Fedora: installs Flatpak apps + gsettings (host-level only) |
| `scripts/setup-toolbox.sh` | — | Run inside a Fedora toolbox; installs shared CLIs (rendered via `chezmoi execute-template`), a `TOOLBOX_ONLY` dnf array (zsh, gcc, make, python3-pip, rust, cargo, wl-clipboard), and a non-dnf section for tools without Fedora packages (mise/tlrc/yazi via cargo, pnpm via corepack, goose [pressly] and git-spice via `go install`). Ignored by chezmoi via `.chezmoiignore` |
| `scripts/setup-ptyxis.sh` | — | **Experimental, untested.** Run on the host after `toolbox create`; configures the default Ptyxis profile to launch `/usr/bin/zsh -l` inside the toolbox via `gsettings` |

Neovim config is pulled via `.chezmoiexternal.toml` from a separate git repo (`ChrisLTD/nvim`). It probes `vim.fn.executable("tree-sitter")` — that comes from the `tree-sitter-cli` package on both platforms (the plain `tree-sitter` brew formula and dnf package are just the C library, no binary).

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
- [x] Set up Toolbox for CLI dev tools — `toolbox create && toolbox enter && bash ~/.local/share/chezmoi/scripts/setup-toolbox.sh`
- [ ] Terminal (Ptyxis) settings:
  - Profile → Container = `fedora-toolbox-<ver>`, Custom command = `/usr/bin/zsh -l` (manual, or try the experimental `scripts/setup-ptyxis.sh`)
  - Keybindings: New tab `ctrl-t`, Close tab `ctrl-w`, Next `ctrl-tab`, Prev `shift-ctrl-tab` (no automation)
  - Theme: Tokyo Night, Font: Source Code Pro 12, Line spacing: 1.1, Cursor: i-beam (no automation)
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

**Mac-only formula / cask / mas app:**
```sh
chezmoi edit ~/.Brewfile   # opens dot_Brewfile.tmpl in $EDITOR
chezmoi apply
cd ~/.local/share/chezmoi && git add . && git commit -m "Add <package>"
```

**Shared CLI (Mac brew + Fedora toolbox dnf):**
```sh
chezmoi edit ~/.local/share/chezmoi/.chezmoidata/cli_packages.yaml
chezmoi apply              # Mac: re-renders Brewfile, re-runs brew bundle
# Inside the Fedora toolbox:
bash ~/.local/share/chezmoi/scripts/setup-toolbox.sh
cd ~/.local/share/chezmoi && git add . && git commit -m "Add <tool> to shared CLIs"
```

**Toolbox-only CLI (build tool, language toolchain):**
```sh
# Edit the TOOLBOX_ONLY array in scripts/setup-toolbox.sh, then:
bash ~/.local/share/chezmoi/scripts/setup-toolbox.sh
cd ~/.local/share/chezmoi && git add . && git commit -m "Add <tool> to TOOLBOX_ONLY"
```

**Fedora Flatpak (host GUI app):**
```sh
chezmoi edit ~/.local/share/chezmoi/run_onchange_install-fedora-packages.sh.tmpl
# add flatpak install line, then:
chezmoi apply
cd ~/.local/share/chezmoi && git add . && git commit -m "Add <app> flatpak"
```
