#!/usr/bin/env bash
#
# CodeFixer v6.0 - Senior Developer Edition
# Modular, scalable, production-ready code analysis and fixing tool
# (C) 2025 Senior Developer + AI

set -euo pipefail

# Script directory and module loading
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="$SCRIPT_DIR/lib"

# Load modules
source "$LIB_DIR/logger.sh"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/validator.sh"
source "$LIB_DIR/processor.sh"

# Version and paths
readonly VERSION="6.0.0"
readonly CONFIG_DIR="$HOME/.codefixer"
readonly BACKUP_DIR="$CONFIG_DIR/backups"
readonly LOG_DIR="$CONFIG_DIR/logs"
readonly CACHE_DIR="$CONFIG_DIR/cache"
readonly DEFAULT_CONFIG="$CONFIG_DIR/config.yaml"
readonly IGNORE_FILE=".codefixerignore"
readonly GITIGNORE_FILE=".gitignore"
readonly REPORT_JSON="$LOG_DIR/report.json"
readonly REPORT_MD="$LOG_DIR/report.md"

# Global state (minimized)
declare -a FILES_PROCESSED=()
declare -A FILE_ISSUES=()
declare -A FILE_FIXED=()
declare -A LANG_COUNT=()
declare -A LANG_ISSUES=()
declare -A LANG_FIXED=()

# Runtime variables
TOTAL_FILES=0
TOTAL_ISSUES=0
TOTAL_FIXED=0
TARGET_DIR="."

# Progress tracking
show_progress() {
    local curr="$1" total="$2" msg="$3"
    [[ "$(get_config CI_MODE)" == "true" ]] && return
    
    local percent=$((curr * 100 / total))
    local bar_len=30
    local fill=$((percent * bar_len / 100))
    
    printf "\r${COLORS[BLUE]}Progress: ["
    printf "%0.s=" $(seq 1 $fill)
    printf "%0.s " $(seq 1 $((bar_len-fill)))
    printf "] %3d%% (%d/%d) %s${COLORS[NC]}" "$percent" "$curr" "$total" "$msg"
}

# Backup system with atomic operations
backup_file() {
    local file="$1"
    [[ "$(get_config BACKUP_ENABLED)" != "true" ]] && return 0
    [[ "$(get_config DRY_RUN)" == "true" ]] && return 0
    
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local safe_name
    safe_name=$(echo "$file" | sed 's|/|_|g' | sed 's|^\._||')
    local backup_path="$BACKUP_DIR/${ts}_${safe_name}"
    
    # Atomic backup
    local temp_backup
    temp_backup=$(mktemp)
    if cp "$file" "$temp_backup" 2>/dev/null && mv "$temp_backup" "$backup_path" 2>/dev/null; then
        log_debug "Backed up $file to $backup_path"
    else
        log_error "Failed to backup $file"
        rm -f "$temp_backup"
        return 1
    fi
}

# Prompt system with timeout
prompt_fix() {
    local file="$1"
    [[ "$(get_config PROMPT_MODE)" != "true" ]] && return 0
    
    printf "\n${COLORS[YELLOW]}Apply auto-fix to $file? [y/N]: ${COLORS[NC]}"
    read -r -t 30 yn || yn="n"
    [[ "$yn" =~ ^[Yy]$ ]] || return 1
}

# Language-specific processors
process_shell() {
    local file="$1" issues=0 fixes=0
    
    if validate_tool "shellcheck"; then
        local out
        out=$(shellcheck -f json "$file" 2>/dev/null || true)
        local cnt
        cnt=$(echo "$out" | jq 'if type == "array" then length else 0 end' 2>/dev/null || echo 0)
        [[ $cnt -gt 0 ]] && issues=$((issues+cnt))
        
        if [[ "$(get_config AUTO_FIX)" == "true" && "$(get_config EXPERIMENTAL_FIXES)" == "true" && $cnt -gt 0 ]]; then
            log_warn "Experimental shell fixes disabled for safety. Use shellcheck --fix or manual fixes."
        fi
    fi
    
    printf '{"file":%s,"lang":"shell","issues":%d,"fixed":%d}\n' "$(jq -R <<<"$file")" "$issues" "$fixes"
}

process_python() {
    local file="$1" issues=0 fixes=0
    
    if validate_tool "pylint"; then
        local out
        out=$(pylint --output-format=json "$file" 2>/dev/null || true)
        local cnt
        cnt=$(echo "$out" | jq 'if type == "array" then length else 0 end' 2>/dev/null || echo 0)
        [[ $cnt -gt 0 ]] && issues=$((issues+cnt))
    fi
    
    if [[ "$(get_config AUTO_FIX)" == "true" ]]; then
        prompt_fix "$file" || return 0
        backup_file "$file" || return 1
        
        if validate_tool "black"; then
            if black --quiet "$file" 2>/dev/null; then
                ((fixes++))
            else
                log_warn "Black failed on $file"
            fi
        fi
        
        if validate_tool "isort"; then
            if isort --quiet "$file" 2>/dev/null; then
                ((fixes++))
            else
                log_warn "isort failed on $file"
            fi
        fi
    fi
    
    printf '{"file":%s,"lang":"python","issues":%d,"fixed":%d}\n' "$(jq -R <<<"$file")" "$issues" "$fixes"
}

process_javascript() {
    local file="$1" issues=0 fixes=0
    local eslint_bin="eslint"
    [[ -x "./node_modules/.bin/eslint" ]] && eslint_bin="./node_modules/.bin/eslint"
    
    if validate_tool "$eslint_bin"; then
        local out
        out=$($eslint_bin --format json "$file" 2>/dev/null || true)
        local errs
        errs=$(echo "$out" | jq 'if length > 0 then .[0].errorCount else 0 end' 2>/dev/null || echo 0)
        local warns
        warns=$(echo "$out" | jq 'if length > 0 then .[0].warningCount else 0 end' 2>/dev/null || echo 0)
        issues=$((issues+errs+warns))
        
        if [[ "$(get_config AUTO_FIX)" == "true" && $issues -gt 0 ]]; then
            prompt_fix "$file" || return 0
            backup_file "$file" || return 1
            $eslint_bin --fix "$file" && ((fixes++))
        fi
    fi
    
    if [[ "$(get_config AUTO_FIX)" == "true" && $(validate_tool "prettier") ]]; then
        prompt_fix "$file" || return 0
        backup_file "$file" || return 1
        prettier --write "$file" && ((fixes++))
    fi
    
    printf '{"file":%s,"lang":"javascript","issues":%d,"fixed":%d}\n' "$(jq -R <<<"$file")" "$issues" "$fixes"
}

process_json() {
    local file="$1" issues=0 fixes=0
    
    if ! validate_tool "jq"; then
        log_warn "jq not found, skipping JSON validation for $file"
        printf '{"file":%s,"lang":"json","issues":1,"fixed":0}\n' "$(jq -R <<<"$file")"
        return 0
    fi
    
    if ! validate_json "$file"; then
        issues=$((issues+1))
    fi
    
    if [[ "$(get_config AUTO_FIX)" == "true" && $issues -gt 0 ]]; then
        prompt_fix "$file" || return 0
        backup_file "$file" || return 1
        
        local tmp
        tmp=$(mktemp)
        if jq . "$file" > "$tmp" 2>/dev/null && mv "$tmp" "$file"; then
            ((fixes++))
        else
            log_error "Failed to fix JSON: $file"
            rm -f "$tmp"
        fi
    fi
    
    printf '{"file":%s,"lang":"json","issues":%d,"fixed":%d}\n' "$(jq -R <<<"$file")" "$issues" "$fixes"
}

process_yaml() {
    local file="$1" issues=0 fixes=0
    
    if validate_tool "yamllint"; then
        local out
        out=$(yamllint -f parsable "$file" 2>/dev/null || true)
        local cnt
        cnt=$(echo "$out" | grep -c 'error\|warning' || echo 0)
        [[ $cnt -gt 0 ]] && issues=$((issues+cnt))
    fi
    
    if [[ "$(get_config AUTO_FIX)" == "true" && $(validate_tool "prettier") ]]; then
        prompt_fix "$file" || return 0
        backup_file "$file" || return 1
        prettier --write --parser yaml "$file" && ((fixes++))
    fi
    
    printf '{"file":%s,"lang":"yaml","issues":%d,"fixed":%d}\n' "$(jq -R <<<"$file")" "$issues" "$fixes"
}

process_go() {
    local file="$1" issues=0 fixes=0
    
    if validate_tool "go"; then
        go vet "$file" 2>/dev/null || issues=$((issues+1))
        if validate_tool "staticcheck"; then
            staticcheck "$file" 2>/dev/null || issues=$((issues+1))
        fi
    fi
    
    if [[ "$(get_config AUTO_FIX)" == "true" && $(validate_tool "gofmt") ]]; then
        prompt_fix "$file" || return 0
        backup_file "$file" || return 1
        gofmt -w "$file" && ((fixes++))
    fi
    
    printf '{"file":%s,"lang":"go","issues":%d,"fixed":%d}\n' "$(jq -R <<<"$file")" "$issues" "$fixes"
}

process_rust() {
    local file="$1" issues=0 fixes=0
    
    if validate_tool "cargo"; then
        cargo clippy --quiet || issues=$((issues+1))
    fi
    
    if [[ "$(get_config AUTO_FIX)" == "true" && $(validate_tool "rustfmt") ]]; then
        prompt_fix "$file" || return 0
        backup_file "$file" || return 1
        rustfmt "$file" && ((fixes++))
    fi
    
    printf '{"file":%s,"lang":"rust","issues":%d,"fixed":%d}\n' "$(jq -R <<<"$file")" "$issues" "$fixes"
}

process_cpp() {
    local file="$1" issues=0 fixes=0
    
    if validate_tool "cppcheck"; then
        local out
        out=$(cppcheck --enable=warning,style,performance,portability "$file" 2>&1 || true)
        local cnt
        cnt=$(echo "$out" | grep -c 'error\|warning' || echo 0)
        [[ $cnt -gt 0 ]] && issues=$((issues+cnt))
    fi
    
    if [[ "$(get_config AUTO_FIX)" == "true" && $(validate_tool "clang-format") ]]; then
        prompt_fix "$file" || return 0
        backup_file "$file" || return 1
        clang-format -i "$file" && ((fixes++))
    fi
    
    printf '{"file":%s,"lang":"cpp","issues":%d,"fixed":%d}\n' "$(jq -R <<<"$file")" "$issues" "$fixes"
}

# Report generation
generate_report_md() {
    local file="$REPORT_MD"
    
    {
        printf "# CodeFixer Report\n\n"
        printf "**Generated:** %s\n" "$(date)"
        printf "**Version:** %s\n" "$VERSION"
        printf "**Files:** %d\n" "$TOTAL_FILES"
        printf "**Issues Found:** %d\n" "$TOTAL_ISSUES"
        printf "**Issues Fixed:** %d\n" "$TOTAL_FIXED"
        printf "\n## By Language\n"
        printf "| Language | Files | Issues | Fixed |\n|---|---|---|---|\n"
        
        for lang in "${!LANG_COUNT[@]}"; do
            printf "| %s | %d | %d | %d |\n" "$lang" "${LANG_COUNT[$lang]}" "${LANG_ISSUES[$lang]:-0}" "${LANG_FIXED[$lang]:-0}"
        done
        
        printf "\n## File Details\n"
        printf "| File | Issues | Fixed |\n|------|--------|-------|\n"
        
        for f in "${FILES_PROCESSED[@]}"; do
            printf "| %s | %s | %s |\n" "$f" "${FILE_ISSUES[$f]:-0}" "${FILE_FIXED[$f]:-0}"
        done
        
        printf "\n---\n*CodeFixer v%s*\n" "$VERSION"
    } > "$file"
    
    log_success "Markdown report: $file"
}

generate_report_json() {
    local file="$REPORT_JSON"
    
    {
        printf '{\n'
        printf "  \"version\": \"%s\",\n" "$VERSION"
        printf "  \"generated\": \"%s\",\n" "$(date)"
        printf "  \"files\": %d,\n" "$TOTAL_FILES"
        printf "  \"issues\": %d,\n" "$TOTAL_ISSUES"
        printf "  \"fixed\": %d,\n" "$TOTAL_FIXED"
        printf '  "by_language": {\n'
        
        local first=1
        for lang in "${!LANG_COUNT[@]}"; do
            [[ $first -eq 0 ]] && printf ",\n"
            printf "    \"%s\": { \"files\": %d, \"issues\": %d, \"fixed\": %d }" \
                "$lang" "${LANG_COUNT[$lang]}" "${LANG_ISSUES[$lang]:-0}" "${LANG_FIXED[$lang]:-0}"
            first=0
        done
        
        printf "\n  },\n"
        printf '  "details": [\n'
        
        first=1
        for f in "${FILES_PROCESSED[@]}"; do
            [[ $first -eq 0 ]] && printf ",\n"
            local esc_file
            esc_file=$(printf '%s' "$f" | sed 's/"/\\"/g')
            printf "    { \"file\": \"%s\", \"issues\": %s, \"fixed\": %s }" "$esc_file" "${FILE_ISSUES[$f]:-0}" "${FILE_FIXED[$f]:-0}"
            first=0
        done
        
        printf "\n  ]\n}\n"
    } > "$file"
    
    log_success "JSON report: $file"
}

# Main processing function
process_directory() {
    local dir="${1:-.}"
    local files=()
    
    validate_directory "$dir" || return 1
    
    # Find files based on configuration
    if [[ "$(get_config GIT_ONLY)" == "true" ]]; then
        for lang in "${!FILE_PATTERNS[@]}"; do
            while IFS= read -r file; do
                [[ -n "$file" && -f "$file" ]] && files+=("$file")
            done < <(git_files_for_language "$lang")
        done
    else
        for lang in "${!FILE_PATTERNS[@]}"; do
            while IFS= read -r file; do
                [[ -n "$file" ]] && files+=("$file")
            done < <(find_files_for_language "$dir" "$lang")
        done
    fi
    
    local n_files=${#files[@]}
    if [[ $n_files -eq 0 ]]; then
        log_warn "No processable files found"
        return 0
    fi
    
    log_info "Found $n_files files to process"
    
    # Process files
    if [[ "$(get_config PARALLEL_JOBS)" -gt 1 && "$(get_config PROMPT_MODE)" != "true" && "$(get_config CI_MODE)" != "true" ]]; then
        process_files_parallel "${files[@]}"
    else
        process_files_sequential "${files[@]}"
    fi
    
    printf "\n"
}

# Help system
show_help() {
    cat << EOF
CodeFixer v$VERSION - Senior Developer Edition

USAGE:
    $0 [OPTIONS] [DIRECTORY]

OPTIONS:
    -h, --help              Show this help
    -v, --verbose           Verbose output
    -n, --dry-run           Analyze only, no changes
    -f, --fix               Enable auto-fix
    -d, --depth N           Max directory depth (default: 5)
    -j, --jobs N            Parallel jobs (default: 4)
    --no-backup             Disable backups
    --ci                    Quiet, CI-friendly output
    --report                Generate Markdown & JSON reports
    --prompt                Prompt before each fix
    --experimental-fixes    Enable experimental fixes
    --git-only              Only scan git-tracked files
    --worker                (internal) process a single file
    --version               Print version

CONFIG:
    Supports configuration via $DEFAULT_CONFIG
    Supports .codefixerignore and .gitignore files

EXAMPLES:
    $0 --fix .              # Analyze & fix
    $0 --dry-run ~/proj     # Analyze only
    $0 --report             # Generate reports

Supported: Shell, Python, JS/TS, JSON, YAML, Go, Rust, Ruby, Java, C++
EOF
}

# Argument parsing
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit 0 ;;
            -v|--verbose) set_config VERBOSE true ;;
            -n|--dry-run) set_config AUTO_FIX false; set_config DRY_RUN true ;;
            -f|--fix) set_config AUTO_FIX true; set_config DRY_RUN false ;;
            -d|--depth) shift; set_config MAX_DEPTH "${1:-5}" ;;
            -j|--jobs) shift; set_config PARALLEL_JOBS "${1:-4}" ;;
            --no-backup) set_config BACKUP_ENABLED false ;;
            --ci) set_config CI_MODE true ;;
            --report) set_config GENERATE_REPORT true ;;
            --prompt) set_config PROMPT_MODE true ;;
            --experimental-fixes) set_config EXPERIMENTAL_FIXES true ;;
            --git-only) set_config GIT_ONLY true ;;
            --worker) shift; process_file "$1"; exit 0 ;;
            --version) printf "CodeFixer %s\n" "$VERSION"; exit 0 ;;
            -*) log_error "Unknown flag: $1"; exit 1 ;;
            *) TARGET_DIR="$1" ;;
        esac
        shift
    done
}

# Main function
main() {
    # Initialize
    load_defaults
    setup_dirs
    load_ignore_files "$IGNORE_FILE" "$GITIGNORE_FILE"
    load_yaml_config "$DEFAULT_CONFIG"
    
    # Validate configuration
    if ! validate_config; then
        log_error "Configuration validation failed"
        exit 1
    fi
    
    if ! validate_runtime_config; then
        log_error "Runtime validation failed"
        exit 1
    fi
    
    # Set up logging
    LOG_FILE="$LOG_DIR/codefixer.log"
    LOG_LEVEL="$(get_config VERBOSE)"
    [[ "$LOG_LEVEL" == "true" ]] && LOG_LEVEL="DEBUG" || LOG_LEVEL="INFO"
    
    # Log startup
    log_info "Starting CodeFixer v$VERSION"
    log_info "Target: $TARGET_DIR"
    log_info "Mode: $(get_config DRY_RUN)"
    log_info "Auto-fix: $(get_config AUTO_FIX)"
    
    # Process directory
    process_directory "$TARGET_DIR"
    
    # Generate reports
    if [[ "$(get_config GENERATE_REPORT)" == "true" ]]; then
        generate_report_md
        generate_report_json
    fi
    
    # Summary
    printf "%b\n" "${COLORS[GREEN]}🎉 Analysis Complete!${COLORS[NC]}"
    printf "%b\n" "${COLORS[BLUE]}📊 Files: $TOTAL_FILES | Issues: $TOTAL_ISSUES | Fixed: $TOTAL_FIXED${COLORS[NC]}"
    
    # Exit code
    if [[ $TOTAL_ISSUES -gt 0 && "$(get_config CI_MODE)" == "true" ]]; then
        exit 1
    else
        exit 0
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main
fi