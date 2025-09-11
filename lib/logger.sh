#!/usr/bin/env bash
# Logger module for CodeFixer
# Provides structured logging with levels, colors, and file output

set -euo pipefail

# Color definitions
declare -A COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[1;33m'
    [BLUE]='\033[0;34m'
    [CYAN]='\033[0;36m'
    [GRAY]='\033[0;37m'
    [BOLD]='\033[1m'
    [NC]='\033[0m'
)

# Logger configuration
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-}"
VERBOSE="${VERBOSE:-false}"

# Log levels (higher number = more verbose)
declare -A LOG_LEVELS=(
    [ERROR]=1
    [WARN]=2
    [INFO]=3
    [DEBUG]=4
)

should_log() {
    local level="$1"
    local current_level="${LOG_LEVELS[$LOG_LEVEL]:-3}"
    local message_level="${LOG_LEVELS[$level]:-3}"
    [[ $message_level -le $current_level ]]
}

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if ! should_log "$level"; then
        return 0
    fi
    
    local color=""
    case "$level" in
        ERROR)   color="${COLORS[RED]}" ;;
        WARN)    color="${COLORS[YELLOW]}" ;;
        INFO)    color="${COLORS[BLUE]}" ;;
        SUCCESS) color="${COLORS[GREEN]}" ;;
        DEBUG)   color="${COLORS[GRAY]}" ;;
        *)       color="${COLORS[NC]}" ;;
    esac
    
    local entry="[$timestamp] [$level] $message"
    
    # Always log to file if specified
    if [[ -n "$LOG_FILE" ]]; then
        printf "%s\n" "$entry" >> "$LOG_FILE"
    fi
    
    # Console output
    if [[ "$level" != "DEBUG" || "$VERBOSE" == true ]]; then
        printf "%b%s%b\n" "$color" "$entry" "${COLORS[NC]}"
    fi
}

log_error() { log "ERROR" "$1"; }
log_warn() { log "WARN" "$1"; }
log_info() { log "INFO" "$1"; }
log_success() { log "SUCCESS" "$1"; }
log_debug() { log "DEBUG" "$1"; }