#!/usr/bin/env bash
# CodeFixer Installer
# Installs dependencies and (optionally) a pre-commit hook.

set -euo pipefail

readonly INSTALL_DIR="$HOME/.codefixer"
readonly LOG_DIR="$INSTALL_DIR/logs"
readonly BACKUP_DIR="$INSTALL_DIR/backups"
readonly CACHE_DIR="$INSTALL_DIR/cache"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APT_TOOLS=(shellcheck jq yamllint)
PIP_TOOLS=(pylint flake8 black isort mypy yamllint)
NPM_TOOLS=(eslint prettier @typescript-eslint/parser markdownlint stylelint)
GEM_TOOLS=(rubocop)
GO_TOOLS=(golang.org/x/lint/golint)
CARGO_TOOLS=(clippy rustfmt)
BREW_TOOLS=(shellcheck jq yamllint)

show_success() { echo -e "\033[1;32m[✔]\033[0m $1"; }
show_info()    { echo -e "\033[1;36m[INFO]\033[0m $1"; }
show_warn()    { echo -e "\033[1;33m[WARN]\033[0m $1"; }

setup_dirs() {
    mkdir -p "$INSTALL_DIR" "$LOG_DIR" "$BACKUP_DIR" "$CACHE_DIR"
    show_success "Directories created at $INSTALL_DIR"
}

install_apt() {
    sudo apt-get update
    sudo apt-get install -y "${APT_TOOLS[@]}"
}
install_brew() {
    brew install "${BREW_TOOLS[@]}"
}
install_pip() {
    pip3 install --user "${PIP_TOOLS[@]}"
}
install_npm() {
    npm install -g "${NPM_TOOLS[@]}"
}
install_gem() {
    gem install "${GEM_TOOLS[@]}"
}
install_go() {
    for tool in "${GO_TOOLS[@]}"; do
        go install "$tool@latest" || true
    done
}
install_cargo() {
    for tool in "${CARGO_TOOLS[@]}"; do
        cargo install --locked "$tool" || true
    done
}

install_all_dependencies() {
    show_info "Installing dependencies. This may take a few minutes."
    local found_pm=0
    if command -v apt-get >/dev/null; then install_apt; found_pm=1; fi
    if command -v brew >/dev/null; then install_brew; found_pm=1; fi
    if command -v pip3 >/dev/null; then install_pip; found_pm=1; fi
    if command -v npm >/dev/null; then install_npm; found_pm=1; fi
    if command -v gem >/dev/null; then install_gem; found_pm=1; fi
    if command -v go >/dev/null; then install_go; found_pm=1; fi
    if command -v cargo >/dev/null; then install_cargo; found_pm=1; fi
    if [[ $found_pm -eq 0 ]]; then
        show_warn "No known package manager found. Please install dependencies manually."
    else
        show_success "Dependencies installed."
    fi
}

install_precommit_hook() {
    local repo_dir="$1"
    local hook_path="$repo_dir/.git/hooks/pre-commit"
    if [[ ! -d "$repo_dir/.git" ]]; then
        show_warn "No .git directory found in $repo_dir, skipping pre-commit hook."
        return
    fi
    cat > "$hook_path" <<EOF
#!/bin/sh
"$SCRIPT_DIR/codefixer.sh" --fix --ci --report .
EOF
    chmod +x "$hook_path"
    show_success "Pre-commit hook installed at $hook_path"
}

main() {
    setup_dirs
    install_all_dependencies

    echo
    read -p "Do you want to set up a pre-commit hook in your current project? (y/N): " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        install_precommit_hook "$PWD"
    fi

    show_success "Installation complete. Run './codefixer.sh --help' to get started."
}

main "$@"