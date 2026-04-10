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

## Requirements

- **OS:** Debian/Ubuntu (uses `apt` package manager)
- **Tools:** `curl` and `sudo` access
- **Shell:** `bash` (default on most Linux systems)

**Note:** macOS and other Linux distributions are not currently supported by this script.

---

## How to run

Execute directly from GitHub — no need to clone the repo:

```bash
bash <(curl -sSfL https://raw.githubusercontent.com/CarlosLongarela/cl-personal-term/main/install.sh)
```

**The installer is fully idempotent and safe to run repeatedly.**

### Installation behavior

- **First install:** Installs all tools and configures your shell
- **Subsequent runs:** 
  - Tools already installed are checked for updates and upgraded if available
  - Config files (`starship.toml`, `.tmux.conf`) prompt you to keep local or replace with GitHub copy
  - `.bashrc` entries are validated line-by-line — no duplicates even across multiple runs
  - `$HOME/.local/bin` is added to PATH only once (idempotent)

### Validation

After installation completes, the script validates all tools:

```
─── Post-install validation ──────────────────
  ✓ starship   starship 1.18.0
  ✓ eza        eza 0.16.1
  ✓ fzf        0.46.0
  ✓ zoxide     0.9.0
  ✓ batcat     0.24.0
  ✓ tmux       tmux 3.3a
  ✓ starship.toml deployed
──────────────────────────────────────────────
```

Any tool marked with `✗` indicates an installation failure requiring manual review.

### Interactive prompts (non dry-run mode)

1. **tmux installation:** Asked once (skipped during `--dry-run`)
2. **Config files:** If `~/.config/starship.toml` or `~/.tmux.conf` already exist:
   ```
   ~/.config/starship.toml already exists. Keep local file or replace with clean GitHub copy? [K/r]:
   ```
   - Press `K` (or just Enter) → keep your local customizations
   - Press `r` → replace with GitHub version (backup created as `.bak`)

### Preview mode (dry-run)

See exactly what the script **would** do without making any changes or prompts:

```bash
bash <(curl -sSfL https://raw.githubusercontent.com/CarlosLongarela/cl-personal-term/main/install.sh) --dry-run
```

In dry-run mode:
- No prompts are shown (removes interactive delays)
- No installations occur
- Tools are not checked for updates (reduces API calls)
- All changes are logged as `[DRY-RUN]` messages

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

| File | Deployed to | Behavior |
|------|-------------|----------|
| `starship.toml` | `~/.config/starship.toml` | Prompt if exists (keep/replace) |
| `.tmux.conf` | `~/.tmux.conf` | Prompt if exists (keep/replace) |
| `tmux-start` | `~/.local/bin/tmux-start` | Overwrite (always latest) |
| `show-help` | `~/.local/bin/show-help` | Overwrite (always latest) |

### Handling existing config files

If `~/.config/starship.toml` or `~/.tmux.conf` already exist:

1. Installer prompts: **Keep local file or replace?**
2. **K** (default) → Preserves your customizations
3. **r** → Replaces with GitHub version + creates `.bak` backup

This approach lets you maintain custom configurations across runs while staying up-to-date with improvements from the repo.

### Manual updates

To update configs directly without running the full installer:

```bash
# Starship config
curl -sSfL https://raw.githubusercontent.com/CarlosLongarela/cl-personal-term/main/starship.toml \
    -o ~/.config/starship.toml

# tmux config
curl -sSfL https://raw.githubusercontent.com/CarlosLongarela/cl-personal-term/main/.tmux.conf \
    -o ~/.tmux.conf

# Helper scripts
curl -sSfL https://raw.githubusercontent.com/CarlosLongarela/cl-personal-term/main/tmux-start \
    -o ~/.local/bin/tmux-start && chmod +x ~/.local/bin/tmux-start

curl -sSfL https://raw.githubusercontent.com/CarlosLongarela/cl-personal-term/main/show-help \
    -o ~/.local/bin/show-help && chmod +x ~/.local/bin/show-help
```

---

## Shell configuration (.bashrc)

The installer manages your `~/.bashrc` intelligently:

### What gets added

```bash
export PATH="$HOME/.local/bin:$PATH"
alias ls="eza --icons"
alias ll="eza -lah --icons"
alias tree="eza --tree"
alias bat="batcat"  # or "bat" depending on system
alias h="show-help"
eval "$(zoxide init bash)"
eval "$(fzf --bash)"
eval "$(starship init bash)"
if [ -z "$TMUX" ]; then
    tmux-start
fi
```

### Idempotent behavior

- **No duplicates:** Lines are checked before adding (exact match lookup)
- **Run as many times as you want:** Repeating the installer won't duplicate `eval` statements
- **PATH handling:** If `$HOME/.local/bin` is already in PATH, it's not added again
- **Marked block:** Entries are wrapped with start/end markers for easier maintenance

This means you can safely run the installer multiple times without worrying about your `~/.bashrc` becoming cluttered with repeated init lines.

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
