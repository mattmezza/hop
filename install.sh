#!/usr/bin/env bash
#
# hop installer
# Usage: curl -fsSL https://raw.githubusercontent.com/mattmezza/hop/main/install.sh | bash
#

set -euo pipefail

GITHUB_REPO="mattmezza/hop"
BIN_DIR="$HOME/.local/bin"
MAN_DIR="$HOME/.local/share/man/man1"
CONFIG_DIR="$HOME/.config/hop"
TEMPLATES_DIR="$CONFIG_DIR/templates"

# Colors
if [[ -t 1 ]]; then
    RED=$'\e[31m'
    GREEN=$'\e[32m'
    YELLOW=$'\e[33m'
    BOLD=$'\e[1m'
    RESET=$'\e[0m'
else
    RED="" GREEN="" YELLOW="" BOLD="" RESET=""
fi

die() {
    echo "${RED}Error:${RESET} $*" >&2
    exit 1
}

info() {
    echo "${GREEN}$*${RESET}"
}

warn() {
    echo "${YELLOW}$*${RESET}"
}

# Check dependencies
check_dependencies() {
    local missing=()
    command -v curl &>/dev/null || missing+=("curl")
    command -v tar &>/dev/null || missing+=("tar")
    command -v tmux &>/dev/null || missing+=("tmux")
    command -v fzf &>/dev/null || missing+=("fzf")
    command -v sha256sum &>/dev/null || missing+=("sha256sum")

    if ((${#missing[@]} > 0)); then
        die "Missing dependencies: ${missing[*]}"
    fi
}

# Get latest release version from GitHub
get_latest_version() {
    local version
    version=$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')
    if [[ -z "$version" ]]; then
        die "Failed to get latest version from GitHub"
    fi
    echo "$version"
}

main() {
    echo "${BOLD}Installing hop...${RESET}"
    echo ""

    check_dependencies

    # Get latest version
    echo "Fetching latest release..."
    local version
    version=$(get_latest_version)
    echo "Latest version: v${version}"

    # Create directories
    mkdir -p "$BIN_DIR" "$MAN_DIR" "$TEMPLATES_DIR"

    # Download and extract release
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local tarball_url="https://github.com/${GITHUB_REPO}/releases/download/v${version}/hop-v${version}.tar.gz"

    echo "Downloading..."
    if ! curl -fsSL "$tarball_url" -o "$tmp_dir/hop.tar.gz"; then
        rm -rf "$tmp_dir"
        die "Failed to download release"
    fi

    echo "Extracting..."
    tar -xzf "$tmp_dir/hop.tar.gz" -C "$tmp_dir"

    # Find extracted directory
    local extract_dir
    extract_dir=$(find "$tmp_dir" -maxdepth 1 -type d -name "hop-*" | head -1)
    if [[ -z "$extract_dir" ]]; then
        # Files might be extracted directly
        extract_dir="$tmp_dir"
    fi

    # Install files
    echo "Installing..."

    # Main script
    if [[ -f "$extract_dir/hop" ]]; then
        cp "$extract_dir/hop" "$BIN_DIR/hop"
        chmod +x "$BIN_DIR/hop"
    else
        rm -rf "$tmp_dir"
        die "hop script not found in release"
    fi

    # Man page
    if [[ -f "$extract_dir/hop.1" ]]; then
        cp "$extract_dir/hop.1" "$MAN_DIR/"
    fi

    # Default template (if not already exists)
    if [[ ! -f "$TEMPLATES_DIR/default" ]]; then
        if [[ -f "$extract_dir/templates/default" ]]; then
            cp "$extract_dir/templates/default" "$TEMPLATES_DIR/"
        else
            # Create default template inline
            cat > "$TEMPLATES_DIR/default" <<'EOF'
#!/usr/bin/env bash
# Default template - single window
# Available variables: $SESSION_NAME, $PROJECT_PATH

tmux rename-window -t "$SESSION_NAME:1" "default"
EOF
        fi
    fi

    # Store version
    echo "$version" > "$CONFIG_DIR/.version"

    # Cleanup
    rm -rf "$tmp_dir"

    echo ""
    info "hop v${version} installed successfully!"
    echo ""

    # Check if BIN_DIR is in PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        warn "Note: $BIN_DIR is not in your PATH."
        echo "Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        echo ""
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
    fi

    # Shell completion hint
    echo "${BOLD}Shell Completions${RESET}"
    echo "To enable shell completions, run:"
    echo ""
    echo "  hop completion --how-to"
    echo ""

    # Extras hint
    echo "${BOLD}Extra Templates${RESET}"
    echo "Install additional templates with:"
    echo ""
    echo "  hop extras install"
    echo ""

    echo "Run 'hop help' for usage information."
}

main "$@"
