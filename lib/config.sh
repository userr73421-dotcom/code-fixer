#!/usr/bin/env bash
# Configuration module for CodeFixer
# Handles configuration loading, validation, and management

set -euo pipefail

# Default configuration
declare -A DEFAULT_CONFIG=(
    [MAX_DEPTH]="5"
    [PARALLEL_JOBS]="4"
    [AUTO_FIX]="false"
    [BACKUP_ENABLED]="true"
    [VERBOSE]="false"
    [CI_MODE]="false"
    [GENERATE_REPORT]="false"
    [PROMPT_MODE]="false"
    [EXPERIMENTAL_FIXES]="false"
    [GIT_ONLY]="false"
)

# Runtime configuration
declare -A CONFIG=()
declare -A TOOL_OVERRIDES=()
declare -a IGNORE_PATTERNS=()

load_defaults() {
    for key in "${!DEFAULT_CONFIG[@]}"; do
        CONFIG["$key"]="${DEFAULT_CONFIG[$key]}"
    done
}

validate_config() {
    local errors=0
    
    # Validate numeric values
    if ! [[ "${CONFIG[MAX_DEPTH]}" =~ ^[0-9]+$ ]]; then
        log_error "Invalid MAX_DEPTH: ${CONFIG[MAX_DEPTH]} (must be a number)"
        ((errors++))
    fi
    
    if ! [[ "${CONFIG[PARALLEL_JOBS]}" =~ ^[0-9]+$ ]]; then
        log_error "Invalid PARALLEL_JOBS: ${CONFIG[PARALLEL_JOBS]} (must be a number)"
        ((errors++))
    fi
    
    # Validate ranges
    if [[ "${CONFIG[MAX_DEPTH]}" -lt 1 || "${CONFIG[MAX_DEPTH]}" -gt 20 ]]; then
        log_warn "MAX_DEPTH ${CONFIG[MAX_DEPTH]} is unusual (recommended: 1-10)"
    fi
    
    if [[ "${CONFIG[PARALLEL_JOBS]}" -lt 1 || "${CONFIG[PARALLEL_JOBS]}" -gt 32 ]]; then
        log_warn "PARALLEL_JOBS ${CONFIG[PARALLEL_JOBS]} is unusual (recommended: 1-16)"
    fi
    
    # Validate boolean values
    local bool_vars=("AUTO_FIX" "BACKUP_ENABLED" "VERBOSE" "CI_MODE" "GENERATE_REPORT" "PROMPT_MODE" "EXPERIMENTAL_FIXES" "GIT_ONLY")
    for var in "${bool_vars[@]}"; do
        if [[ "${CONFIG[$var]}" != "true" && "${CONFIG[$var]}" != "false" ]]; then
            log_error "Invalid $var: ${CONFIG[$var]} (must be true or false)"
            ((errors++))
        fi
    done
    
    return $errors
}

load_yaml_config() {
    local config_file="$1"
    [[ -f "$config_file" ]] || return 0
    
    local in_ignore=false
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        
        case "$line" in
            "depth:"*)
                CONFIG[MAX_DEPTH]="${line#*: }"
                ;;
            "fix:"*)
                CONFIG[AUTO_FIX]="${line#*: }"
                ;;
            "ignore:"*)
                in_ignore=true
                ;;
            "  - "*)
                if [[ $in_ignore == true ]]; then
                    IGNORE_PATTERNS+=("${line#* - }")
                fi
                ;;
            [a-zA-Z0-9_]*:*)
                in_ignore=false
                local key="${line%%:*}"
                local value="${line#*: }"
                if [[ $key == tool_* ]]; then
                    local tool="${key#tool_}"
                    TOOL_OVERRIDES[$tool]="$value"
                fi
                ;;
            *)
                in_ignore=false
                ;;
        esac
    done < "$config_file"
}

load_ignore_files() {
    local ignore_file="${1:-.codefixerignore}"
    local gitignore_file="${2:-.gitignore}"
    
    [[ -f "$ignore_file" ]] && mapfile -t IGNORE_PATTERNS < "$ignore_file"
    [[ -f "$gitignore_file" ]] && while IFS= read -r line; do
        IGNORE_PATTERNS+=("$line")
    done < "$gitignore_file"
}

get_config() {
    local key="$1"
    local default="${2:-}"
    printf '%s' "${CONFIG[$key]:-$default}"
}

set_config() {
    local key="$1"
    local value="$2"
    CONFIG["$key"]="$value"
}

get_tool_override() {
    local tool="$1"
    printf '%s' "${TOOL_OVERRIDES[$tool]:-}"
}

is_ignored() {
    local file="$1"
    
    # Check git ignore first
    if command -v git >/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git check-ignore "$file" >/dev/null 2>&1 && return 0
    fi
    
    # Check ignore patterns
    for pattern in "${IGNORE_PATTERNS[@]}"; do
        [[ "$file" == $pattern ]] && return 0
        [[ "$file" == */$pattern ]] && return 0
    done
    
    return 1
}