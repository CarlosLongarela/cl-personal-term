# cl-personal-term

Terminal setup script for Debian/Ubuntu systems. Installs and configures a modern shell environment with a custom Starship prompt and tmux.

## What it installs

| Tool | Purpose |
|------|---------|
| [Starship](https://starship.rs) | Cross-shell prompt |
| [bash-completion](https://github.com/scop/bash-completion) | Tab completion for bash |
| [bat](https://github.com/sharkdp/bat) | `cat` with syntax highlighting |
| [eza](https://github.com/eza-community/eza) | Modern `ls` replacement |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smarter `cd` with frecency |
| [tmux](https://github.com/tmux/tmux) | Terminal multiplexer |

## Aliases configured

```bash
alias ls="eza --icons"
alias ll="eza -lah --icons"
alias tree="eza --tree"
alias bat="batcat"   # auto-detected: batcat on Debian/Ubuntu, bat elsewhere
alias h="show-help"  # quick reference cheatsheet
```

## Quick reference (`h`)

Type `h` in any terminal to display a colour-coded cheatsheet of the most useful shortcuts, organised by tool:

- **tmux** — prefix, windows, panes, scroll mode
- **bash** — history search, cursor shortcuts
- **zoxide** — fuzzy directory navigation
- **fzf** — file and history fuzzy search
- **aliases** — all configured shortcuts

---

## How to run

Execute directly from GitHub — no need to clone the repo:

```bash
bash <(curl -sSfL https://raw.githubusercontent.com/CarlosLongarela/cl-personal-term/main/install.sh)
```

After the script finishes, reload your shell:

```bash
source ~/.bashrc
```

> **Requirements:** `curl` and `sudo` access. Targets Debian/Ubuntu systems (uses `apt`).

### Preview mode (dry-run)

See exactly what the script would do without making any changes:

```bash
bash <(curl -sSfL https://raw.githubusercontent.com/CarlosLongarela/cl-personal-term/main/install.sh) --dry-run
```

---

## tmux

The script deploys `.tmux.conf` to `~/.tmux.conf`, installs `tmux-start` as an executable in `~/.local/bin/`, and adds an auto-start call to `.bashrc`:

```bash
if [ -z "$TMUX" ]; then
    tmux-start
fi
```

`tmux-start` creates a named session `main` with two windows (`local` and `remote`), or attaches to it if it already exists. Every new interactive shell will attach automatically. This is skipped when already inside tmux (e.g. nested sessions via SSH).

### tmux key bindings (from `.tmux.conf`)

| Shortcut | Action |
|----------|--------|
| `Ctrl-a` | Prefix (replaces default `Ctrl-b`) |
| `Prefix \|` | Split pane horizontally |
| `Prefix -` | Split pane vertically |
| `Prefix h/j/k/l` | Navigate panes (vim-style) |
| `Prefix H/J/K/L` | Resize panes |
| `Prefix r` | Reload tmux config |
| `Prefix L` | New window: logs |
| `Prefix W` | New window: wordpress |
| `Prefix S` | New window: server |
| `Prefix E` | Layout: editor + shell + logs |

---

## Fonts

### Local installation (terminal emulator on your machine)

The Starship config uses icons and symbols from **Nerd Fonts**. Without a compatible font, icons will render as boxes or question marks.

**Recommended font: [CaskaydiaCove Nerd Font](https://www.nerdfonts.com/font-downloads)**

Installation steps:

1. Download **CaskaydiaCove Nerd Font** from [nerdfonts.com/font-downloads](https://www.nerdfonts.com/font-downloads)
2. Extract the `.zip` and install the `.ttf` files:
   - **Windows:** right-click each `.ttf` → *Install for all users*
   - **macOS:** double-click each `.ttf` → *Install Font*
   - **Linux:** copy to `~/.local/share/fonts/` then run `fc-cache -fv`
3. Set **CaskaydiaCove Nerd Font** (or **CaskaydiaCove NF**) as the font in your terminal emulator settings

### Remote via SSH

**No font installation needed on the server.** When connecting via SSH, your terminal emulator runs locally — it uses whatever font is configured on your local machine. As long as your local terminal uses a Nerd Font, icons will render correctly in remote sessions automatically.

---

## Config files

| File | Deployed to |
|------|-------------|
| `starship.toml` | `~/.config/starship.toml` |
| `.tmux.conf` | `~/.tmux.conf` |
| `tmux-start` | `~/.local/bin/tmux-start` (chmod +x) |
| `show-help` | `~/.local/bin/show-help` (chmod +x) |

If either file already exists it is backed up with a `.bak` extension before being overwritten.

To update configs manually at any time:

```bash
curl -sSfL https://raw.githubusercontent.com/CarlosLongarela/cl-personal-term/main/starship.toml \
    -o ~/.config/starship.toml

curl -sSfL https://raw.githubusercontent.com/CarlosLongarela/cl-personal-term/main/.tmux.conf \
    -o ~/.tmux.conf

curl -sSfL https://raw.githubusercontent.com/CarlosLongarela/cl-personal-term/main/tmux-start \
    -o ~/.local/bin/tmux-start && chmod +x ~/.local/bin/tmux-start

curl -sSfL https://raw.githubusercontent.com/CarlosLongarela/cl-personal-term/main/show-help \
    -o ~/.local/bin/show-help && chmod +x ~/.local/bin/show-help
```

---

## Security note

`starship` and `zoxide` are installed by piping remote scripts directly to `bash` (their upstream-recommended method). If you prefer to inspect the scripts before running them:

```bash
curl -sSf  https://starship.rs/install.sh -o /tmp/starship-install.sh
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh -o /tmp/zoxide-install.sh

# Review, then execute:
bash /tmp/starship-install.sh --yes
bash /tmp/zoxide-install.sh
```
