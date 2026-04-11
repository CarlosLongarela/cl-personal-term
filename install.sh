#!/usr/bin/env bash
set -eEuo pipefail

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

trap 'echo -e "${RED}[ERROR]${RESET}    Failed at line ${LINENO}: ${BASH_COMMAND}" >&2' ERR

APT_INSTALLED=()
APT_UPDATED=()
APT_UPTODATE=()

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

version_lt() {
    local v1="$1"
    local v2="$2"
    [ "$v1" != "$v2" ] && [ "$(printf '%s\n' "$v1" "$v2" | sort -V | head -n1)" = "$v1" ]
}

normalize_version() {
    # Strip leading non-numeric prefix (like v1.2.3) and trailing metadata.
    echo "$1" | sed -E 's/^[^0-9]*//; s/[^0-9.].*$//'
}

github_latest_tag() {
    local repo="$1"
    local response
    response=$(curl -fsSL --max-time 5 "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null || echo "")
    
    if [ -z "$response" ]; then
        return 1
    fi
    
    echo "$response" \
        | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        | head -n1
}

ask_keep_or_replace() {
    local item="$1"
    local answer
    echo -e "${BOLD}${item} already exists. Keep local file or replace with clean GitHub copy? [K/r]:${RESET} \c"
    read -r answer </dev/tty || answer=""

    case "${answer,,}" in
        r|replace)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

append_line_if_missing() {
    local line="$1"
    local label="$2"

    if grep -Fqx "$line" "$BASHRC" 2>/dev/null; then
        info "$label already present in $BASHRC, skipping."
        return
    fi

    echo "$line" >> "$BASHRC"
    success "Added $label to $BASHRC."
}

$DRY_RUN && warning "Running in dry-run mode — no changes will be made.\n"

# ── tmux prompt ──────────────────────────────
# Default N — skip on remote servers where the local terminal handles multiplexing.
INSTALL_TMUX=false
if ! $DRY_RUN; then
    echo -e "${BOLD}Install tmux + tmux-start? [y/N]:${RESET} \c"
    read -r tmux_answer </dev/tty
    [[ "${tmux_answer,,}" == "y" ]] && INSTALL_TMUX=true
fi
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

update_package_index() {
    local update_cmd="$1"
    local out=""
    local status=0

    info "Updating package index..."
    if $DRY_RUN; then
        dryrun "Would run: $update_cmd"
        return 0
    fi

    set +e
    out="$($update_cmd 2>&1)"
    status=$?
    set -e

    echo "$out"

    if [ $status -eq 0 ]; then
        return 0
    fi

    if echo "$out" | grep -Eiq 'NO_PUBKEY|GPG error|signatures couldn.t be verified|Some index files failed to download'; then
        warning "apt update reported signature issues in external repositories."
        warning "Continuing using existing package indexes for available repositories."
        return 0
    fi

    error "Package index update failed. Resolve apt errors and retry."
}

# ── Update package index ─────────────────────
update_package_index "$PKG_UPDATE"
info "Package index ready. Checking requested packages..."

# ── Install apt packages ─────────────────────
install_pkg() {
    local name="$1"
    local installed_ver=""
    local candidate_ver=""

    info "Checking package '${name}'..."

    installed_ver="$(dpkg-query -W -f='${Version}' "$name" 2>/dev/null || true)"
    candidate_ver="$(apt-cache policy "$name" 2>/dev/null | awk '/Candidate:/ {print $2; exit}' || true)"

    if [ -z "$installed_ver" ]; then
        info "Installing ${name}..."
        if $DRY_RUN; then
            dryrun "Would run: $PKG_INSTALL $name"
        else
            $PKG_INSTALL "$name"
        fi
        APT_INSTALLED+=("$name")
        return
    fi

    if [ -n "$candidate_ver" ] && [ "$candidate_ver" != "(none)" ] && [ "$candidate_ver" != "$installed_ver" ]; then
        info "${name} installed (${installed_ver}) and update available (${candidate_ver})."
        if $DRY_RUN; then
            dryrun "Would run: $PKG_INSTALL --only-upgrade $name"
        else
            $PKG_INSTALL --only-upgrade "$name"
        fi
        APT_UPDATED+=("$name")
    else
        success "${name} already up to date (${installed_ver})."
        APT_UPTODATE+=("$name")
    fi
}

install_pkg bash-completion
install_pkg bat
install_pkg fzf
$INSTALL_TMUX && install_pkg tmux

# ── Install zoxide ────────────────────────────
info "Installing zoxide..."
ZOXIDE_BIN=""
if command -v zoxide &>/dev/null; then
    ZOXIDE_BIN="$(command -v zoxide)"
elif [ -x "$HOME/.local/bin/zoxide" ]; then
    ZOXIDE_BIN="$HOME/.local/bin/zoxide"
fi

if [ -n "$ZOXIDE_BIN" ]; then
    current_zoxide="$(normalize_version "$($ZOXIDE_BIN --version 2>/dev/null | awk '{print $2}' | head -n1)")"
    latest_zoxide="$(normalize_version "$(github_latest_tag ajeetdsouza/zoxide 2>/dev/null || true)")"

    if [ -n "$latest_zoxide" ] && [ -n "$current_zoxide" ] && version_lt "$current_zoxide" "$latest_zoxide"; then
        info "zoxide installed (${current_zoxide}) and update available (${latest_zoxide}). Updating..."
        if $DRY_RUN; then
            dryrun "Would run: curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash"
        else
            if curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash; then
                success "zoxide updated."
            else
                warning "Failed to update zoxide. Keeping current version."
            fi
        fi
    elif [ -n "$latest_zoxide" ] && [ -n "$current_zoxide" ]; then
        success "zoxide already up to date (${current_zoxide})."
    else
        warning "Could not determine zoxide latest version. Keeping current installation."
    fi
else
    if $DRY_RUN; then
        dryrun "Would run: curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash"
    else
        if curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash; then
            success "zoxide installed."
        else
            error "Failed to install zoxide."
        fi
    fi
fi

# ── Install eza ───────────────────────────────
info "Installing eza..."
EZA_CANDIDATE="$(apt-cache policy eza 2>/dev/null | awk '/Candidate:/ {print $2; exit}' || true)"
if [ -z "$EZA_CANDIDATE" ] || [ "$EZA_CANDIDATE" = "(none)" ]; then
    if $DRY_RUN; then
        dryrun "Would add eza apt repository (if not already present)"
    else
        if [ ! -f /etc/apt/sources.list.d/gierens.list ]; then
            sudo mkdir -p /etc/apt/keyrings
            curl -sSfL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
                | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
            echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
                | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
            sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
            update_package_index "$PKG_UPDATE"
            success "eza repository added."
        else
            info "eza repository already configured."
        fi
    fi
fi
install_pkg eza

# ── Install Starship ──────────────────────────
info "Installing starship..."
if command -v starship &>/dev/null; then
    current_starship="$(normalize_version "$(starship --version 2>/dev/null | awk '{print $2}' | head -n1)")"
    latest_starship="$(normalize_version "$(github_latest_tag starship/starship 2>/dev/null || true)")"

    if [ -n "$latest_starship" ] && [ -n "$current_starship" ] && version_lt "$current_starship" "$latest_starship"; then
        info "starship installed (${current_starship}) and update available (${latest_starship}). Updating..."
        if $DRY_RUN; then
            dryrun "Would run: curl -sSf https://starship.rs/install.sh | sh -s -- --yes"
        else
            if curl -sSf https://starship.rs/install.sh | sh -s -- --yes; then
                success "starship updated."
            else
                warning "Failed to update starship. Keeping current version."
            fi
        fi
    elif [ -n "$latest_starship" ] && [ -n "$current_starship" ]; then
        success "starship already up to date (${current_starship})."
    else
        warning "Could not determine starship latest version. Keeping current installation."
    fi
else
    if $DRY_RUN; then
        dryrun "Would run: curl -sSf https://starship.rs/install.sh | sh -s -- --yes"
    else
        if curl -sSf https://starship.rs/install.sh | sh -s -- --yes; then
            success "starship installed."
        else
            error "Failed to install starship."
        fi
    fi
fi

# ── Deploy starship.toml ──────────────────────
info "Configuring starship prompt..."
TOML_DST="$HOME/.config/starship.toml"
if ! $DRY_RUN; then
    mkdir -p "$HOME/.config"
    if [ -f "$TOML_DST" ]; then
        if ask_keep_or_replace "~/.config/starship.toml"; then
            info "Keeping local ~/.config/starship.toml"
        else
            warning "Replacing ~/.config/starship.toml (backup: starship.toml.bak)"
            cp "$TOML_DST" "${TOML_DST}.bak"
            curl -sSfL "$REPO_RAW/starship.toml" -o "$TOML_DST"
            success "starship.toml deployed."
        fi
    else
        curl -sSfL "$REPO_RAW/starship.toml" -o "$TOML_DST"
        success "starship.toml deployed."
    fi
else
    dryrun "Would deploy starship.toml to $TOML_DST (if it exists, installer would ask keep/replace)"
fi

# ── Deploy .tmux.conf and tmux-start ─────────
if $INSTALL_TMUX; then
    info "Configuring tmux..."
    TMUX_DST="$HOME/.tmux.conf"
    if ! $DRY_RUN; then
        if [ -f "$TMUX_DST" ]; then
            if ask_keep_or_replace "~/.tmux.conf"; then
                info "Keeping local ~/.tmux.conf"
            else
                warning "Replacing ~/.tmux.conf (backup: .tmux.conf.bak)"
                cp "$TMUX_DST" "${TMUX_DST}.bak"
                curl -sSfL "$REPO_RAW/.tmux.conf" -o "$TMUX_DST"
                success ".tmux.conf deployed."
            fi
        else
            curl -sSfL "$REPO_RAW/.tmux.conf" -o "$TMUX_DST"
            success ".tmux.conf deployed."
        fi
    else
        dryrun "Would deploy .tmux.conf to $TMUX_DST (if it exists, installer would ask keep/replace)"
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

# ── Deploy show-help ──────────────────────────
info "Deploying show-help to ~/.local/bin..."
SHOW_HELP_DST="$HOME/.local/bin/show-help"
if ! $DRY_RUN; then
    mkdir -p "$HOME/.local/bin"
    curl -sSfL "$REPO_RAW/show-help" -o "$SHOW_HELP_DST"
    chmod +x "$SHOW_HELP_DST"
    success "show-help deployed and made executable."
else
    dryrun "Would deploy show-help to $SHOW_HELP_DST and chmod +x"
fi

# ── Detect bat command name ───────────────────
# On Debian/Ubuntu apt installs bat as 'batcat' to avoid a name collision.
# If bat is already on PATH use it directly; otherwise fall back to batcat.
BAT_CMD="batcat"
if command -v bat &>/dev/null && ! command -v batcat &>/dev/null; then
    BAT_CMD="bat"
fi
info "bat alias will point to: ${BAT_CMD}"

# ── Check if fzf is available ──────────────────
if command -v fzf &>/dev/null; then
    info "fzf found — will set up integration via eval \"\$(fzf --bash)\""
else
    warning "fzf not found — bash integration will be skipped."
fi

# ── Write .bashrc block ───────────────────────
if grep -q "$MARKER_START" "$BASHRC" 2>/dev/null; then
    warning "Existing cl-personal-term block found in $BASHRC — updating incrementally."
    if ! $DRY_RUN; then
        sed -i "/$MARKER_START/,/$MARKER_END/d" "$BASHRC"
    fi
else
    # Ensure markers exist for future runs
    if ! $DRY_RUN; then
        true  # Will add markers during bashrc update
    fi
fi

info "Writing aliases and shell init to $BASHRC..."

if $DRY_RUN; then
    dryrun "Would append cl-personal-term block to $BASHRC"
    dryrun "  bat alias      → $BAT_CMD"
    dryrun "  fzf integration→ $(command -v fzf &>/dev/null && echo "yes" || echo "no (skipped)")"
    dryrun "  tmux auto-start→ $($INSTALL_TMUX && echo "yes" || echo "no (skipped)")"
else
    touch "$BASHRC"
    {
        echo "$MARKER_START"
        echo ""
    } >> "$BASHRC"

    if ! grep -Fq '/usr/share/bash-completion/bash_completion' "$BASHRC" 2>/dev/null; then
        cat >> "$BASHRC" << 'EOF'
# ── bash-completion ───────────────────────────
if [ -f /usr/share/bash-completion/bash_completion ]; then
    source /usr/share/bash-completion/bash_completion
fi

EOF
        success "Added bash-completion block to $BASHRC."
    else
        info "bash-completion block already present in $BASHRC, skipping."
    fi

    {
        echo "# ── PATH: local bin (zoxide, etc.) ───────────"
    } >> "$BASHRC"
    if ! grep -Fqx 'export PATH="$HOME/.local/bin:$PATH"' "$BASHRC" 2>/dev/null; then
        if ! grep -Fq '$HOME/.local/bin' "$BASHRC" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASHRC"
            success "Added PATH export to $BASHRC."
        else
            info "PATH already contains $HOME/.local/bin, skipping."
        fi
    else
        info "PATH export already present in $BASHRC, skipping."
    fi
    echo "" >> "$BASHRC"

    {
        echo "# ── Aliases ───────────────────────────────────"
    } >> "$BASHRC"
    append_line_if_missing 'alias ls="eza --icons"' "ls alias"
    append_line_if_missing 'alias ll="eza -lah --icons"' "ll alias"
    append_line_if_missing 'alias tree="eza --tree"' "tree alias"
    append_line_if_missing "alias bat=\"$BAT_CMD\"" "bat alias"
    append_line_if_missing 'alias h="show-help"' "h alias"
    echo "" >> "$BASHRC"

    {
        echo "# ── zoxide (replaces cd) ──────────────────────"
    } >> "$BASHRC"
    append_line_if_missing 'eval "$(zoxide init bash)"' "zoxide init"
    echo "" >> "$BASHRC"

    if command -v fzf &>/dev/null; then
        {
            echo "# ── fzf key bindings and completion ──────────"
        } >> "$BASHRC"
        append_line_if_missing 'eval "$(fzf --bash)"' "fzf integration"
        echo "" >> "$BASHRC"
    fi

    if $INSTALL_TMUX; then
        if grep -Fq 'tmux-start' "$BASHRC" 2>/dev/null; then
            info "tmux auto-start already present in $BASHRC, skipping."
        else
            cat >> "$BASHRC" << 'EOF'
# ── tmux auto-start ───────────────────────────
if [ -z "$TMUX" ]; then
    tmux-start
fi

EOF
            success "Added tmux auto-start block to $BASHRC."
        fi
    fi

    {
        echo "# ── Starship prompt ───────────────────────────"
    } >> "$BASHRC"
    append_line_if_missing 'eval "$(starship init bash)"' "starship init"

    {
        echo ""
        echo "$MARKER_END"
    } >> "$BASHRC"
    success ".bashrc updated."
fi

# ── Version summary and post-install validation ──
if ! $DRY_RUN; then
    export PATH="$HOME/.local/bin:$PATH"
    echo ""
    echo -e "${BOLD}─── Post-install validation ──────────────────${RESET}"
    
    # Track any failures
    INSTALL_FAILED=0
    
    # Core tools
    if command -v starship &>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} starship  $(starship --version)"
    else
        echo -e "  ${RED}✗${RESET} starship  not found (installation failed)"
        INSTALL_FAILED=1
    fi
    
    if command -v eza &>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} eza       $(eza --version | head -1)"
    else
        echo -e "  ${RED}✗${RESET} eza       not found (installation failed)"
        INSTALL_FAILED=1
    fi
    
    if command -v fzf &>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} fzf       $(fzf --version)"
    else
        echo -e "  ${RED}✗${RESET} fzf       not found (installation failed)"
        INSTALL_FAILED=1
    fi
    
    if command -v zoxide &>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} zoxide    $(zoxide --version)"
    elif [ -x "$HOME/.local/bin/zoxide" ]; then
        echo -e "  ${GREEN}✓${RESET} zoxide    $($HOME/.local/bin/zoxide --version)"
    else
        echo -e "  ${RED}✗${RESET} zoxide    not found (installation failed)"
        INSTALL_FAILED=1
    fi
    
    # bat (may be bat or batcat)
    if command -v bat &>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} bat       $(bat --version 2>/dev/null | head -1)"
    elif command -v batcat &>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} batcat    $(batcat --version 2>/dev/null | head -1)"
    else
        echo -e "  ${YELLOW}!${RESET} bat/batcat not found"
    fi
    
    # Optional: tmux
    if [ "$INSTALL_TMUX" = true ]; then
        if command -v tmux &>/dev/null; then
            echo -e "  ${GREEN}✓${RESET} tmux      $(tmux -V)"
        else
            echo -e "  ${RED}✗${RESET} tmux      not found (installation failed)"
            INSTALL_FAILED=1
        fi
    fi
    
    # Optional: starship config
    if [ -f "$HOME/.config/starship.toml" ]; then
        echo -e "  ${GREEN}✓${RESET} starship.toml deployed"
    else
        echo -e "  ${YELLOW}!${RESET} starship.toml not found (may be using defaults)"
    fi
    
    echo -e "${BOLD}──────────────────────────────────────────────${RESET}"
    
    if [ $INSTALL_FAILED -eq 1 ]; then
        echo ""
        warning "Some tools failed to install. Please review the output above."
    else
        echo ""
        success "All core tools installed and validated successfully!"
    fi
    echo ""
fi

success "All done! Run 'source ~/.bashrc' or open a new terminal to apply changes."

if ! $DRY_RUN; then
    echo ""
    echo -e "${BOLD}─── apt package summary ──────────────────────${RESET}"
    [ ${#APT_INSTALLED[@]} -gt 0 ] && echo "  installed:  ${APT_INSTALLED[*]}" || echo "  installed:  none"
    [ ${#APT_UPDATED[@]} -gt 0 ]   && echo "  updated:    ${APT_UPDATED[*]}"   || echo "  updated:    none"
    [ ${#APT_UPTODATE[@]} -gt 0 ]  && echo "  up-to-date: ${APT_UPTODATE[*]}"  || echo "  up-to-date: none"
    echo -e "${BOLD}──────────────────────────────────────────────${RESET}"
fi
