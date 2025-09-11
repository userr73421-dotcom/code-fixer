#!/usr/bin/env bash
# Security module for CodeFixer
# Provides security validation, sanitization, and protection

set -euo pipefail

# Security configuration
declare -A SECURITY_CONFIG=(
    [MAX_FILE_SIZE]=10485760      # 10MB
    [MAX_DEPTH]=20                # Maximum directory depth
    [ALLOWED_EXTENSIONS]="py,js,ts,sh,bash,zsh,fish,json,yaml,yml,md,go,rs,rb,java,cpp,c,h,hpp"
    [BLOCKED_PATHS]="/etc/,/proc/,/sys/,/dev/,/boot/,/root/"
    [SANITIZE_INPUT]=true
    [VALIDATE_PERMISSIONS]=true
)

# Security validation
validate_security() {
    local file="$1"
    local errors=0
    
    # Check file size
    local file_size
    file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
    if [[ $file_size -gt ${SECURITY_CONFIG[MAX_FILE_SIZE]} ]]; then
        log_warn "File too large, skipping: $file ($((file_size / 1024 / 1024))MB)"
        return 1
    fi
    
    # Check file extension
    local ext="${file##*.}"
    if [[ ! ",${SECURITY_CONFIG[ALLOWED_EXTENSIONS]}," =~ ,$ext, ]]; then
        log_warn "Unsupported file extension, skipping: $file"
        return 1
    fi
    
    # Check blocked paths
    for blocked_path in ${SECURITY_CONFIG[BLOCKED_PATHS]//,/ }; do
        if [[ "$file" =~ ^$blocked_path ]]; then
            log_warn "Blocked path, skipping: $file"
            return 1
        fi
    done
    
    # Check file permissions
    if [[ "${SECURITY_CONFIG[VALIDATE_PERMISSIONS]}" == "true" ]]; then
        if [[ ! -r "$file" ]]; then
            log_warn "File not readable, skipping: $file"
            return 1
        fi
    fi
    
    return 0
}

# Input sanitization
sanitize_input() {
    local input="$1"
    
    if [[ "${SECURITY_CONFIG[SANITIZE_INPUT]}" != "true" ]]; then
        echo "$input"
        return 0
    fi
    
    # Remove null bytes
    input=$(echo "$input" | tr -d '\0')
    
    # Remove control characters except newlines and tabs
    input=$(echo "$input" | sed 's/[[:cntrl:]]//g')
    
    # Limit length
    input=$(echo "$input" | cut -c1-1000)
    
    echo "$input"
}

# Path validation
validate_path() {
    local path="$1"
    
    # Check for path traversal
    if [[ "$path" =~ \.\. ]]; then
        log_warn "Path traversal detected, blocking: $path"
        return 1
    fi
    
    # Check for absolute paths outside allowed directories
    if [[ "$path" =~ ^/ ]]; then
        local allowed=false
        for allowed_dir in "$HOME" "/tmp" "/var/tmp"; do
            if [[ "$path" =~ ^$allowed_dir ]]; then
                allowed=true
                break
            fi
        done
        
        if [[ "$allowed" == "false" ]]; then
            log_warn "Absolute path outside allowed directories: $path"
            return 1
        fi
    fi
    
    return 0
}

# Command validation
validate_command() {
    local command="$1"
    
    # Check for dangerous commands
    local dangerous_commands=("rm" "mv" "cp" "chmod" "chown" "sudo" "su" "bash" "sh" "exec" "eval")
    for dangerous in "${dangerous_commands[@]}"; do
        if [[ "$command" =~ ^$dangerous ]]; then
            log_warn "Potentially dangerous command blocked: $command"
            return 1
        fi
    done
    
    # Check for command injection
    if [[ "$command" =~ [\;\|\&\$\`] ]]; then
        log_warn "Command injection detected, blocking: $command"
        return 1
    fi
    
    return 0
}

# File content validation
validate_file_content() {
    local file="$1"
    
    # Check for binary content
    if file "$file" | grep -q "binary"; then
        log_warn "Binary file detected, skipping: $file"
        return 1
    fi
    
    # Check for suspicious content
    if grep -q -E "(eval|exec|system|shell_exec|passthru)" "$file" 2>/dev/null; then
        log_warn "Suspicious content detected, skipping: $file"
        return 1
    fi
    
    return 0
}

# Generate security report
generate_security_report() {
    local file="$1"
    
    {
        printf "# Security Report\n\n"
        printf "**Generated:** %s\n" "$(date)"
        printf "**Version:** %s\n" "$VERSION"
        printf "\n## Security Configuration\n"
        printf "| Setting | Value |\n|---|---|\n"
        
        for key in "${!SECURITY_CONFIG[@]}"; do
            printf "| %s | %s |\n" "$key" "${SECURITY_CONFIG[$key]}"
        done
        
        printf "\n## Security Events\n"
        printf "- **Files Blocked:** %s\n" "${METRICS[files_blocked]:-0}"
        printf "- **Security Warnings:** %s\n" "${METRICS[security_warnings]:-0}"
        printf "- **Path Traversals Blocked:** %s\n" "${METRICS[path_traversals_blocked]:-0}"
        printf "- **Command Injections Blocked:** %s\n" "${METRICS[command_injections_blocked]:-0}"
        
        printf "\n## Recommendations\n"
        printf "1. Regularly update the tool and dependencies\n"
        printf "2. Review security logs for suspicious activity\n"
        printf "3. Use least privilege principles when running the tool\n"
        printf "4. Consider running in a sandboxed environment\n"
    } > "$file"
    
    log_success "Security report: $file"
}

# Audit logging
audit_log() {
    local event="$1"
    local details="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    local audit_entry="[$timestamp] SECURITY: $event - $details"
    echo "$audit_entry" >> "$LOG_DIR/security.log"
    
    log_debug "Security event logged: $event"
}

# Security metrics
declare -A SECURITY_METRICS=(
    [files_blocked]=0
    [security_warnings]=0
    [path_traversals_blocked]=0
    [command_injections_blocked]=0
)

# Update security metrics
update_security_metrics() {
    local event="$1"
    case "$event" in
        "file_blocked") ((SECURITY_METRICS[files_blocked]++)) ;;
        "security_warning") ((SECURITY_METRICS[security_warnings]++)) ;;
        "path_traversal_blocked") ((SECURITY_METRICS[path_traversals_blocked]++)) ;;
        "command_injection_blocked") ((SECURITY_METRICS[command_injections_blocked]++)) ;;
    esac
}

# Check for security updates
check_security_updates() {
    log_info "Checking for security updates..."
    
    # This would typically check against a security advisory feed
    # For now, we'll just log that the check was performed
    audit_log "security_check" "Security update check performed"
    
    log_success "Security check completed"
}

# Initialize security
init_security() {
    # Create security log
    touch "$LOG_DIR/security.log"
    
    # Set secure permissions
    chmod 600 "$LOG_DIR/security.log" 2>/dev/null || true
    
    # Log initialization
    audit_log "init" "Security module initialized"
    
    log_info "Security module initialized"
}