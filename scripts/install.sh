#!/usr/bin/env bash
# CodeFixer v6.0 Installation Script
# Senior Developer Edition - Production Ready

set -euo pipefail

# Configuration
readonly VERSION="6.0.0"
readonly INSTALL_DIR="$HOME/.codefixer"
readonly BIN_DIR="$HOME/.local/bin"
readonly CONFIG_DIR="$INSTALL_DIR/config"
readonly LOG_DIR="$INSTALL_DIR/logs"
readonly BACKUP_DIR="$INSTALL_DIR/backups"
readonly CACHE_DIR="$INSTALL_DIR/cache"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Logging
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    local color=""
    case "$level" in
        ERROR) color="$RED" ;;
        WARN)  color="$YELLOW" ;;
        INFO)  color="$BLUE" ;;
        SUCCESS) color="$GREEN" ;;
        *)     color="$NC" ;;
    esac
    
    printf "%b[%s]%b %s\n" "$color" "$level" "$NC" "$message"
}

# Check system requirements
check_requirements() {
    log "INFO" "Checking system requirements..."
    
    local errors=0
    
    # Check Bash version
    if [[ ${BASH_VERSION%%.*} -lt 4 ]]; then
        log "ERROR" "Bash 4.0 or higher is required (found: $BASH_VERSION)"
        ((errors++))
    fi
    
    # Check OS
    if [[ "$OSTYPE" != "linux-gnu"* && "$OSTYPE" != "darwin"* ]]; then
        log "WARN" "Unsupported OS: $OSTYPE (Linux and macOS supported)"
    fi
    
    # Check available space
    local available_space
    available_space=$(df "$HOME" | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 1048576 ]]; then  # 1GB
        log "WARN" "Low disk space: $((available_space / 1024 / 1024))MB available"
    fi
    
    # Check memory
    local total_memory
    total_memory=$(free -m | awk 'NR==2{print $2}' 2>/dev/null || echo "0")
    if [[ $total_memory -lt 512 ]]; then
        log "WARN" "Low memory: ${total_memory}MB available (512MB recommended)"
    fi
    
    if [[ $errors -gt 0 ]]; then
        log "ERROR" "System requirements not met"
        exit 1
    fi
    
    log "SUCCESS" "System requirements check passed"
}

# Detect package manager
detect_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v brew >/dev/null 2>&1; then
        echo "brew"
    elif command -v port >/dev/null 2>&1; then
        echo "port"
    else
        echo "unknown"
    fi
}

# Install system dependencies
install_system_deps() {
    local pm="$1"
    log "INFO" "Installing system dependencies using $pm..."
    
    case "$pm" in
        apt)
            sudo apt-get update
            sudo apt-get install -y shellcheck jq yamllint git curl wget bc file
            ;;
        yum|dnf)
            sudo $pm install -y ShellCheck jq yamllint git curl wget bc file
            ;;
        pacman)
            sudo pacman -S --noconfirm shellcheck jq yamllint git curl wget bc file
            ;;
        brew)
            brew install shellcheck jq yamllint git curl wget bc file
            ;;
        port)
            sudo port install shellcheck jq yamllint git curl wget bc file
            ;;
        *)
            log "WARN" "Unknown package manager: $pm"
            log "INFO" "Please install: shellcheck, jq, yamllint, git, curl, wget, bc, file"
            ;;
    esac
}

# Install Python dependencies
install_python_deps() {
    log "INFO" "Installing Python dependencies..."
    
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install --user pylint black isort mypy yamllint
    elif command -v pip >/dev/null 2>&1; then
        pip install --user pylint black isort mypy yamllint
    else
        log "WARN" "Python pip not found, skipping Python dependencies"
    fi
}

# Install Node.js dependencies
install_node_deps() {
    log "INFO" "Installing Node.js dependencies..."
    
    if command -v npm >/dev/null 2>&1; then
        npm install -g eslint prettier @typescript-eslint/parser markdownlint stylelint
    else
        log "WARN" "Node.js npm not found, skipping Node.js dependencies"
    fi
}

# Install Ruby dependencies
install_ruby_deps() {
    log "INFO" "Installing Ruby dependencies..."
    
    if command -v gem >/dev/null 2>&1; then
        gem install rubocop
    else
        log "WARN" "Ruby gem not found, skipping Ruby dependencies"
    fi
}

# Install Go dependencies
install_go_deps() {
    log "INFO" "Installing Go dependencies..."
    
    if command -v go >/dev/null 2>&1; then
        go install golang.org/x/lint/golint@latest
    else
        log "WARN" "Go not found, skipping Go dependencies"
    fi
}

# Install Rust dependencies
install_rust_deps() {
    log "INFO" "Installing Rust dependencies..."
    
    if command -v cargo >/dev/null 2>&1; then
        cargo install clippy rustfmt
    else
        log "WARN" "Rust cargo not found, skipping Rust dependencies"
    fi
}

# Create directories
create_directories() {
    log "INFO" "Creating directories..."
    
    mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR" "$BACKUP_DIR" "$CACHE_DIR" "$BIN_DIR"
    
    log "SUCCESS" "Directories created"
}

# Install CodeFixer
install_codefixer() {
    log "INFO" "Installing CodeFixer v$VERSION..."
    
    # Copy main script
    cp codefixer.sh "$BIN_DIR/codefixer"
    chmod +x "$BIN_DIR/codefixer"
    
    # Copy library modules
    cp -r lib "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/lib"/*.sh
    
    # Copy test suite
    cp -r tests "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/tests"/*.sh
    
    # Copy documentation
    cp README*.md "$INSTALL_DIR/"
    cp LICENSE* "$INSTALL_DIR/"
    cp CHANGELOG.md "$INSTALL_DIR/"
    cp SECURITY.md "$INSTALL_DIR/"
    
    # Copy configuration
    cp config*.yaml "$CONFIG_DIR/"
    cp *.txt "$CONFIG_DIR/"
    
    # Create symlink for easy access
    ln -sf "$BIN_DIR/codefixer" "$BIN_DIR/codefixer-latest"
    
    log "SUCCESS" "CodeFixer installed to $INSTALL_DIR"
}

# Create configuration
create_config() {
    log "INFO" "Creating configuration..."
    
    local config_file="$CONFIG_DIR/config.yaml"
    
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << 'EOF'
# CodeFixer v6.0 Configuration
# Senior Developer Edition

# Core settings
depth: 5
parallel_jobs: 4
fix: false
backup_enabled: true
verbose: false
ci_mode: false
generate_report: false
prompt_mode: false
experimental_fixes: false
git_only: false

# Ignore patterns
ignore:
  - "node_modules/"
  - "*.min.js"
  - "vendor/"
  - "*.lock"
  - "*.log"
  - "*.tmp"
  - "*.bak"
  - ".git/"
  - "__pycache__/"
  - ".cache/"

# Tool overrides (optional)
tool_python: "python3 -m black"
tool_javascript: "npx eslint"
tool_shell: "shellcheck"
tool_json: "jq"
tool_yaml: "yamllint"
EOF
        log "SUCCESS" "Configuration created: $config_file"
    else
        log "INFO" "Configuration already exists: $config_file"
    fi
}

# Set up environment
setup_environment() {
    log "INFO" "Setting up environment..."
    
    local shell_rc=""
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        shell_rc="$HOME/.bashrc"
    fi
    
    if [[ -n "$shell_rc" ]]; then
        # Add to PATH if not already present
        if ! grep -q "$BIN_DIR" "$shell_rc" 2>/dev/null; then
            echo "" >> "$shell_rc"
            echo "# CodeFixer v$VERSION" >> "$shell_rc"
            echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$shell_rc"
            log "SUCCESS" "Added $BIN_DIR to PATH in $shell_rc"
        else
            log "INFO" "PATH already configured in $shell_rc"
        fi
    fi
    
    # Set environment variables
    export PATH="$BIN_DIR:$PATH"
    
    log "SUCCESS" "Environment configured"
}

# Run tests
run_tests() {
    log "INFO" "Running installation tests..."
    
    if "$BIN_DIR/codefixer" --version >/dev/null 2>&1; then
        log "SUCCESS" "CodeFixer version check passed"
    else
        log "ERROR" "CodeFixer version check failed"
        return 1
    fi
    
    if "$BIN_DIR/codefixer" --help >/dev/null 2>&1; then
        log "SUCCESS" "CodeFixer help check passed"
    else
        log "ERROR" "CodeFixer help check failed"
        return 1
    fi
    
    log "SUCCESS" "Installation tests passed"
}

# Create uninstall script
create_uninstall() {
    log "INFO" "Creating uninstall script..."
    
    cat > "$INSTALL_DIR/uninstall.sh" << 'EOF'
#!/usr/bin/env bash
# CodeFixer v6.0 Uninstall Script

set -euo pipefail

readonly INSTALL_DIR="$HOME/.codefixer"
readonly BIN_DIR="$HOME/.local/bin"

log() {
    echo "[UNINSTALL] $1"
}

log "Removing CodeFixer v6.0..."

# Remove binaries
rm -f "$BIN_DIR/codefixer"
rm -f "$BIN_DIR/codefixer_v6"

# Remove installation directory
rm -rf "$INSTALL_DIR"

# Remove from PATH (manual step)
log "Please remove $BIN_DIR from your PATH in your shell configuration file"

log "CodeFixer v6.0 uninstalled successfully"
EOF
    
    chmod +x "$INSTALL_DIR/uninstall.sh"
    log "SUCCESS" "Uninstall script created: $INSTALL_DIR/uninstall.sh"
}

# Main installation function
main() {
    log "INFO" "Starting CodeFixer v$VERSION installation..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log "WARN" "Running as root is not recommended"
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check requirements
    check_requirements
    
    # Detect package manager
    local pm
    pm=$(detect_package_manager)
    log "INFO" "Detected package manager: $pm"
    
    # Install dependencies
    install_system_deps "$pm"
    install_python_deps
    install_node_deps
    install_ruby_deps
    install_go_deps
    install_rust_deps
    
    # Create directories
    create_directories
    
    # Install CodeFixer
    install_codefixer
    
    # Create configuration
    create_config
    
    # Set up environment
    setup_environment
    
    # Run tests
    run_tests
    
    # Create uninstall script
    create_uninstall
    
    # Success message
    log "SUCCESS" "CodeFixer v$VERSION installed successfully!"
    log "INFO" "Installation directory: $INSTALL_DIR"
    log "INFO" "Binary location: $BIN_DIR/codefixer"
    log "INFO" "Configuration: $CONFIG_DIR/config.yaml"
    log "INFO" "Logs: $LOG_DIR/"
    log "INFO" "Backups: $BACKUP_DIR/"
    log "INFO" "Cache: $CACHE_DIR/"
    
    echo
    log "INFO" "Usage examples:"
    log "INFO" "  codefixer --help"
    log "INFO" "  codefixer --version"
    log "INFO" "  codefixer --dry-run ."
    log "INFO" "  codefixer --fix ."
    log "INFO" "  codefixer --report ."
    
    echo
    log "INFO" "To uninstall: $INSTALL_DIR/uninstall.sh"
    
    echo
    log "SUCCESS" "Installation complete! 🎉"
}

# Run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi