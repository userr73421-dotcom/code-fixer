#!/usr/bin/env bash
# Validation module for CodeFixer
# Provides comprehensive input validation and safety checks

set -euo pipefail

# File validation
validate_file() {
    local file="$1"
    local errors=0
    
    # Basic file checks
    [[ -f "$file" ]] || { log_error "File not found: $file"; return 1; }
    [[ -r "$file" ]] || { log_error "File not readable: $file"; return 1; }
    [[ -s "$file" ]] || { log_warn "File is empty: $file"; return 1; }
    
    # Safety checks - prevent processing system files
    if [[ "$file" =~ ^/etc/ ]]; then
        log_warn "Skipping system configuration file: $file"
        return 1
    fi
    
    if [[ "$file" =~ ^/proc/ ]]; then
        log_warn "Skipping proc filesystem file: $file"
        return 1
    fi
    
    if [[ "$file" =~ ^/sys/ ]]; then
        log_warn "Skipping sys filesystem file: $file"
        return 1
    fi
    
    if [[ "$file" =~ ^/dev/ ]]; then
        log_warn "Skipping device file: $file"
        return 1
    fi
    
    # Check for binary files
    if file "$file" | grep -q "binary"; then
        log_warn "Skipping binary file: $file"
        return 1
    fi
    
    # Check file size (prevent processing huge files)
    local file_size
    file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
    if [[ $file_size -gt 10485760 ]]; then  # 10MB
        log_warn "File too large (>10MB), skipping: $file"
        return 1
    fi
    
    return 0
}

# Directory validation
validate_directory() {
    local dir="$1"
    
    [[ -d "$dir" ]] || { log_error "Directory not found: $dir"; return 1; }
    [[ -r "$dir" ]] || { log_error "Directory not readable: $dir"; return 1; }
    [[ -x "$dir" ]] || { log_error "Directory not executable: $dir"; return 1; }
    
    return 0
}

# Tool validation
validate_tool() {
    local tool="$1"
    local tool_override
    
    tool_override=$(get_tool_override "$tool")
    if [[ -n "$tool_override" ]]; then
        command -v "$tool_override" >/dev/null 2>&1 || {
            log_error "Tool override not found: $tool_override"
            return 1
        }
        return 0
    fi
    
    command -v "$tool" >/dev/null 2>&1 || {
        log_debug "Tool not found: $tool"
        return 1
    }
    
    [[ -x "./node_modules/.bin/$tool" ]] && return 0
    
    return 1
}

# Configuration validation
validate_runtime_config() {
    local errors=0
    
    # Check required directories
    local required_dirs=("$CONFIG_DIR" "$BACKUP_DIR" "$LOG_DIR" "$CACHE_DIR")
    for dir in "${required_dirs[@]}"; do
        if ! mkdir -p "$dir" 2>/dev/null; then
            log_error "Cannot create directory: $dir"
            ((errors++))
        fi
    done
    
    # Check permissions
    if ! [[ -w "$BACKUP_DIR" ]]; then
        log_error "Backup directory not writable: $BACKUP_DIR"
        ((errors++))
    fi
    
    if ! [[ -w "$LOG_DIR" ]]; then
        log_error "Log directory not writable: $LOG_DIR"
        ((errors++))
    fi
    
    return $errors
}

# JSON validation
validate_json() {
    local file="$1"
    
    if ! command -v jq >/dev/null 2>&1; then
        log_warn "jq not available, cannot validate JSON: $file"
        return 1
    fi
    
    jq empty "$file" 2>/dev/null || {
        log_warn "Invalid JSON: $file"
        return 1
    }
    
    return 0
}

# YAML validation
validate_yaml() {
    local file="$1"
    
    if command -v yamllint >/dev/null 2>&1; then
        yamllint "$file" >/dev/null 2>&1 || {
            log_warn "YAML validation failed: $file"
            return 1
        }
    fi
    
    return 0
}

# Shell script validation
validate_shell() {
    local file="$1"
    
    if command -v shellcheck >/dev/null 2>&1; then
        shellcheck "$file" >/dev/null 2>&1 || {
            log_warn "Shell script issues found: $file"
            return 1
        }
    fi
    
    return 0
}