#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
#  Terminal Setup Script
#  Installs: starship, bash-completion, bat, eza, fzf, zoxide, tmux
#  Configures aliases, starship prompt, tmux, and shell init
#
#  Usage:
#    bash install.sh            # normal install
#    bash install.sh --dry-run  # preview changes without applying them
#
#  During installation you will be asked whether to install tmux (default: N).
#  Skip tmux on remote servers where you rely on a local terminal multiplexer.
#
#  NOTE: starship and zoxide are installed by piping remote scripts to bash.
#  This is the upstream-recommended method. If you prefer to verify the scripts
#  manually before executing, download them first:
#    curl -sSf https://starship.rs/install.sh -o /tmp/starship-install.sh
#    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh -o /tmp/zoxide-install.sh
# ─────────────────────────────────────────────

# ── Colors ───────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}     $*"; }
success() { echo -e "${GREEN}[OK]${RESET}       $*"; }
warning() { echo -e "${YELLOW}[WARN]${RESET}     $*"; }
error()   { echo -e "${RED}[ERROR]${RESET}    $*" >&2; exit 1; }
dryrun()  { echo -e "${YELLOW}[DRY-RUN]${RESET}  $*"; }

# ── Dry-run flag ─────────────────────────────
DRY_RUN=false
for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

run() {
    if $DRY_RUN; then
        dryrun "Would run: $*"
    else
        "$@"
    fi
}

$DRY_RUN && warning "Running in dry-run mode — no changes will be made.\n"

# ── tmux prompt ──────────────────────────────
# Default N — skip on remote servers where the local terminal handles multiplexing.
INSTALL_TMUX=false
echo -e "${BOLD}Install tmux + tmux-start? [y/N]:${RESET} \c"
read -r tmux_answer </dev/tty
[[ "${tmux_answer,,}" == "y" ]] && INSTALL_TMUX=true
if $INSTALL_TMUX; then
    info "tmux will be installed."
else
    info "Skipping tmux installation."
fi

# ── Config ───────────────────────────────────
REPO_RAW="https://raw.githubusercontent.com/CarlosLongarela/cl-personal-term/main"
BASHRC="$HOME/.bashrc"
MARKER_START="# >>> cl-personal-term >>>"
MARKER_END="# <<< cl-personal-term <<<"

# ── Detect package manager ───────────────────
if command -v apt-get &>/dev/null; then
    PKG_UPDATE="sudo apt-get update -y"
    PKG_INSTALL="sudo apt-get install -y"
elif command -v apt &>/dev/null; then
    PKG_UPDATE="sudo apt update -y"
    PKG_INSTALL="sudo apt install -y"
else
    error "No supported package manager found (apt/apt-get). This script targets Debian/Ubuntu systems."
fi

# ── Check required commands ──────────────────
require_cmd() {
    command -v "$1" &>/dev/null || error "'$1' is required but not found. Install it and retry."
}
require_cmd curl

# ── Update package index ─────────────────────
info "Updating package index..."
if $DRY_RUN; then
    dryrun "Would run: $PKG_UPDATE"
else
    $PKG_UPDATE
fi

# ── Install apt packages ─────────────────────
install_pkg() {
    local name="$1"
    info "Installing ${name}..."
    if $DRY_RUN; then
        dryrun "Would run: $PKG_INSTALL $name"
    else
        $PKG_INSTALL "$name"
    fi
}

install_pkg bash-completion
install_pkg bat
install_pkg fzf
$INSTALL_TMUX && install_pkg tmux

# ── Install zoxide ────────────────────────────
info "Installing zoxide..."
if command -v zoxide &>/dev/null || [ -x "$HOME/.local/bin/zoxide" ]; then
    success "zoxide already installed, skipping."
else
    if $DRY_RUN; then
        dryrun "Would run: curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash"
    else
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    fi
fi

# ── Install eza ───────────────────────────────
info "Installing eza..."
if command -v eza &>/dev/null; then
    success "eza already installed, skipping."
else
    if $DRY_RUN; then
        dryrun "Would add eza apt repository and install eza"
    else
        sudo mkdir -p /etc/apt/keyrings
        curl -sSfL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
            | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
            | sudo tee /etc/apt/sources.list.d/gierens.list
        sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        $PKG_UPDATE
        $PKG_INSTALL eza
    fi
fi

# ── Install Starship ──────────────────────────
info "Installing starship..."
if command -v starship &>/dev/null; then
    success "starship already installed, skipping."
else
    if $DRY_RUN; then
        dryrun "Would run: curl -sSf https://starship.rs/install.sh | sh -s -- --yes"
    else
        curl -sSf https://starship.rs/install.sh | sh -s -- --yes
    fi
fi

# ── Deploy starship.toml ──────────────────────
info "Configuring starship prompt..."
TOML_DST="$HOME/.config/starship.toml"
if ! $DRY_RUN; then
    mkdir -p "$HOME/.config"
    if [ -f "$TOML_DST" ]; then
        warning "~/.config/starship.toml already exists — backing up to starship.toml.bak"
        cp "$TOML_DST" "${TOML_DST}.bak"
    fi
    curl -sSfL "$REPO_RAW/starship.toml" -o "$TOML_DST"
    success "starship.toml deployed."
else
    dryrun "Would deploy starship.toml to $TOML_DST"
fi

# ── Deploy .tmux.conf and tmux-start ─────────
if $INSTALL_TMUX; then
    info "Configuring tmux..."
    TMUX_DST="$HOME/.tmux.conf"
    if ! $DRY_RUN; then
        if [ -f "$TMUX_DST" ]; then
            warning "~/.tmux.conf already exists — backing up to .tmux.conf.bak"
            cp "$TMUX_DST" "${TMUX_DST}.bak"
        fi
        curl -sSfL "$REPO_RAW/.tmux.conf" -o "$TMUX_DST"
        success ".tmux.conf deployed."
    else
        dryrun "Would deploy .tmux.conf to $TMUX_DST"
    fi

    info "Deploying tmux-start to ~/.local/bin..."
    TMUX_START_DST="$HOME/.local/bin/tmux-start"
    if ! $DRY_RUN; then
        mkdir -p "$HOME/.local/bin"
        curl -sSfL "$REPO_RAW/tmux-start" -o "$TMUX_START_DST"
        chmod +x "$TMUX_START_DST"
        success "tmux-start deployed and made executable."
    else
        dryrun "Would deploy tmux-start to $TMUX_START_DST and chmod +x"
    fi
fi

# ── Detect bat command name ───────────────────
# On Debian/Ubuntu apt installs bat as 'batcat' to avoid a name collision.
# If bat is already on PATH use it directly; otherwise fall back to batcat.
BAT_CMD="batcat"
if command -v bat &>/dev/null && ! command -v batcat &>/dev/null; then
    BAT_CMD="bat"
fi
info "bat alias will point to: ${BAT_CMD}"

# ── Detect fzf shell integration paths ───────
FZF_KEYBINDINGS=""
for p in \
    /usr/share/doc/fzf/examples/key-bindings.bash \
    /usr/share/fzf/key-bindings.bash \
    /usr/share/fzf/shell/key-bindings.bash; do
    if [ -f "$p" ]; then
        FZF_KEYBINDINGS="$p"
        break
    fi
done

FZF_COMPLETION=""
for p in \
    /usr/share/bash-completion/completions/fzf \
    /usr/share/fzf/completion.bash \
    /usr/share/fzf/shell/completion.bash; do
    if [ -f "$p" ]; then
        FZF_COMPLETION="$p"
        break
    fi
done

[ -n "$FZF_KEYBINDINGS" ] && info "fzf key-bindings found: $FZF_KEYBINDINGS" \
    || warning "fzf key-bindings file not found — keybindings will not be enabled."
[ -n "$FZF_COMPLETION" ]  && info "fzf completion  found: $FZF_COMPLETION" \
    || warning "fzf completion file not found — completion will not be enabled."

# ── Write .bashrc block ───────────────────────
if grep -q "$MARKER_START" "$BASHRC" 2>/dev/null; then
    warning "Existing cl-personal-term block found in $BASHRC — removing before re-applying."
    if ! $DRY_RUN; then
        sed -i "/$MARKER_START/,/$MARKER_END/d" "$BASHRC"
    fi
fi

info "Writing aliases and shell init to $BASHRC..."

if $DRY_RUN; then
    dryrun "Would append cl-personal-term block to $BASHRC"
    dryrun "  bat alias      → $BAT_CMD"
    dryrun "  fzf keybindings→ ${FZF_KEYBINDINGS:-not found, skipped}"
    dryrun "  fzf completion → ${FZF_COMPLETION:-not found, skipped}"
    dryrun "  tmux auto-start→ $($INSTALL_TMUX && echo "yes" || echo "no (skipped)")"
else
    # ── Static opening block ──────────────────
    cat >> "$BASHRC" << EOF
$MARKER_START

# ── PATH: local bin (zoxide, etc.) ───────────
export PATH="\$HOME/.local/bin:\$PATH"

# ── bash-completion ───────────────────────────
if [ -f /usr/share/bash-completion/bash_completion ]; then
    source /usr/share/bash-completion/bash_completion
fi

# ── Aliases ───────────────────────────────────
alias ls="eza --icons"
alias ll="eza -lah --icons"
alias tree="eza --tree"
alias bat="$BAT_CMD"

# ── zoxide (replaces cd) ──────────────────────
eval "\$(zoxide init bash)"
EOF

    # ── fzf key-bindings (optional) ──────────
    if [ -n "$FZF_KEYBINDINGS" ]; then
        cat >> "$BASHRC" << EOF

# ── fzf key bindings ─────────────────────────
source "$FZF_KEYBINDINGS"
EOF
    fi

    # ── fzf completion (optional) ─────────────
    if [ -n "$FZF_COMPLETION" ]; then
        cat >> "$BASHRC" << EOF

# ── fzf completion ────────────────────────────
source "$FZF_COMPLETION"
EOF
    fi

    # ── tmux auto-start (only if tmux was installed) ──
    if $INSTALL_TMUX; then
        cat >> "$BASHRC" << 'EOF'

# ── tmux auto-start ───────────────────────────
if [ -z "$TMUX" ]; then
    tmux-start
fi
EOF
    fi

    # ── Starship prompt ───────────────────────────
    cat >> "$BASHRC" << 'EOF'

# ── Starship prompt ───────────────────────────
eval "$(starship init bash)"
EOF

    echo "$MARKER_END" >> "$BASHRC"
    success ".bashrc updated."
fi

# ── Version summary ───────────────────────────
if ! $DRY_RUN; then
    export PATH="$HOME/.local/bin:$PATH"
    echo ""
    echo -e "${BOLD}─── Installed versions ──────────────────────────${RESET}"
    command -v starship &>/dev/null && echo -e "  starship  $(starship --version)"                    || echo -e "  starship  ${RED}not found${RESET}"
    command -v batcat   &>/dev/null && echo -e "  batcat    $(batcat --version 2>/dev/null | head -1)" || true
    command -v bat      &>/dev/null && echo -e "  bat       $(bat --version 2>/dev/null | head -1)"    || true
    command -v eza      &>/dev/null && echo -e "  eza       $(eza --version | head -1)"                || echo -e "  eza       ${RED}not found${RESET}"
    command -v fzf      &>/dev/null && echo -e "  fzf       $(fzf --version)"                          || echo -e "  fzf       ${RED}not found${RESET}"
    command -v zoxide   &>/dev/null && echo -e "  zoxide    $(zoxide --version)"                       || \
        { [ -x "$HOME/.local/bin/zoxide" ] && echo -e "  zoxide    $("$HOME/.local/bin/zoxide" --version)"; } || \
        echo -e "  zoxide    ${RED}not found${RESET}"
    $INSTALL_TMUX && { command -v tmux &>/dev/null && echo -e "  tmux      $(tmux -V)" || echo -e "  tmux      ${RED}not found${RESET}"; }
    echo -e "${BOLD}────────────────────────────────────────────────${RESET}"
    echo ""
fi

success "All done! Run 'source ~/.bashrc' or open a new terminal to apply changes."
