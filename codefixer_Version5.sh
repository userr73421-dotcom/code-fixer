#!/usr/bin/env bash
#
# CodeFixer: Maximal Edition (Single Script, Parallel-Safe, Multi-Language, Configurable)
# (C) 2025 You + AI

set -euo pipefail

readonly VERSION="2.3.0"
readonly CONFIG_DIR="$HOME/.codefixer"
readonly BACKUP_DIR="$CONFIG_DIR/backups"
readonly LOG_DIR="$CONFIG_DIR/logs"
readonly CACHE_DIR="$CONFIG_DIR/cache"
readonly DEFAULT_CONFIG="$CONFIG_DIR/config.yaml"
readonly IGNORE_FILE=".codefixerignore"
readonly GITIGNORE_FILE=".gitignore"
readonly REPORT_JSON="$LOG_DIR/report.json"
readonly REPORT_MD="$LOG_DIR/report.md"

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

VERBOSE=false
DRY_RUN=false
AUTO_FIX=false
CI_MODE=false
GENERATE_REPORT=false
PROMPT_MODE=false
EXPERIMENTAL_FIXES=false
GIT_ONLY=false
BACKUP_ENABLED=true
TARGET_DIR="."
MAX_DEPTH=5
PARALLEL_JOBS=4
TOOL_OVERRIDE=()

# Stats
declare -a FILES_PROCESSED=()
declare -A FILE_ISSUES=()
declare -A FILE_FIXED=()
declare -A LANG_COUNT=()
declare -A LANG_ISSUES=()
declare -A LANG_FIXED=()
declare -a IGNORE_PATHS=()

log() {
    local level="$1"
    local message="$2"
    local now
    now=$(date '+%Y-%m-%d %H:%M:%S')
    local color=""
    case "$level" in
        ERROR)   color="${COLORS[RED]}" ;;
        WARN)    color="${COLORS[YELLOW]}" ;;
        INFO)    color="${COLORS[BLUE]}" ;;
        SUCCESS) color="${COLORS[GREEN]}" ;;
        DEBUG)   color="${COLORS[GRAY]}" ;;
        *)       color="${COLORS[NC]}" ;;
    esac
    local entry="[$now] [$level] $message"
    printf "%s\n" "$entry" >> "$LOG_DIR/codefixer.log"
    [[ "$level" != "DEBUG" || "$VERBOSE" == true ]] && printf "%b%s%b\n" "$color" "$entry" "${COLORS[NC]}"
}

show_progress() {
    local curr="$1" total="$2" msg="$3"
    if [[ "$CI_MODE" == true ]]; then return; fi
    local percent=$((curr * 100 / total))
    local bar_len=30
    local fill=$((percent * bar_len / 100))
    printf "\r${COLORS[BLUE]}Progress: ["
    printf "%0.s=" $(seq 1 $fill)
    printf "%0.s " $(seq 1 $((bar_len-fill)))
    printf "] %3d%% (%d/%d) %s${COLORS[NC]}" "$percent" "$curr" "$total" "$msg"
}

setup_dirs() { mkdir -p "$CONFIG_DIR" "$BACKUP_DIR" "$LOG_DIR" "$CACHE_DIR"; }

command_exists() {
    local tool="$1"
    [[ -n "${TOOL_OVERRIDE[$tool]:-}" ]] && return 0
    command -v "$tool" >/dev/null 2>&1 && return 0
    [[ -x "./node_modules/.bin/$tool" ]] && return 0
    return 1
}

get_command_path() {
    local tool="$1"
    if [[ -n "${TOOL_OVERRIDE[$tool]:-}" ]]; then
        printf '%s' "${TOOL_OVERRIDE[$tool]}"
        return 0
    fi
    command -v "$tool" 2>/dev/null && return 0
    [[ -x "./node_modules/.bin/$tool" ]] && printf './node_modules/.bin/%s' "$tool" && return 0
    return 1
}

in_ignore() {
    local file="$1"
    if command -v git >/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git check-ignore "$file" >/dev/null 2>&1 && return 0
    fi
    for ignore in "${IGNORE_PATHS[@]}"; do
        [[ "$file" == $ignore ]] && return 0
        [[ "$file" == */$ignore ]] && return 0
    done
    return 1
}

backup_file() {
    local file="$1"
    [[ "${BACKUP_ENABLED:-true}" != true ]] && return
    [[ "$DRY_RUN" == true ]] && return
    local ts; ts=$(date +%Y%m%d_%H%M%S)
    cp "$file" "$BACKUP_DIR/${ts}_$(basename "$file")"
}

prompt_fix() {
    local file="$1"
    if [[ "$PROMPT_MODE" == true ]]; then
        printf "\n${COLORS[YELLOW]}Apply auto-fix to $file? [y/N]: ${COLORS[NC]}"
        read -r yn
        [[ "$yn" =~ ^[Yy]$ ]] || return 1
    fi
    return 0
}

load_ignore() {
    IGNORE_PATHS=()
    [[ -f "$IGNORE_FILE" ]] && mapfile -t IGNORE_PATHS < "$IGNORE_FILE"
    [[ -f "$GITIGNORE_FILE" ]] && while read -r line; do IGNORE_PATHS+=("$line"); done < "$GITIGNORE_FILE"
}

load_config() {
    if [[ -f "$DEFAULT_CONFIG" ]]; then
        local in_ignore=0
        while IFS= read -r line; do
            case "$line" in
                depth:*) MAX_DEPTH="${line#*: }" ;;
                fix:*) [[ "${line#*: }" == "true" ]] && AUTO_FIX=true ;;
                "ignore:"*) in_ignore=1 ;;
                "  - "*)
                    [[ $in_ignore -eq 1 ]] && IGNORE_PATHS+=("${line#* - }")
                    ;;
                [a-zA-Z0-9_]*:)
                    in_ignore=0
                    local key="${line%%:*}"
                    local value="${line#*: }"
                    if [[ $key == tool_* ]]; then
                        local tool="${key#tool_}"
                        TOOL_OVERRIDE[$tool]="$value"
                    fi
                    ;;
                *)
                    in_ignore=0
                    ;;
            esac
        done < "$DEFAULT_CONFIG"
    fi
}

declare -A FILE_PATTERNS=(
    [shell]="*.sh *.bash *.zsh *.fish"
    [python]="*.py *.pyw *.py3"
    [javascript]="*.js *.jsx *.mjs"
    [typescript]="*.ts *.tsx"
    [css]="*.css *.scss *.sass *.less"
    [json]="*.json *.jsonc"
    [yaml]="*.yml *.yaml"
    [markdown]="*.md *.markdown *.mdown"
    [go]="*.go"
    [rust]="*.rs"
    [ruby]="*.rb *.rake"
    [java]="*.java"
    [cpp]="*.cpp *.cxx *.cc *.c *.h *.hpp *.hxx"
)

git_files_for_lang() {
    local lang="$1"
    local pat="${FILE_PATTERNS[$lang]}"
    local ext_pat
    ext_pat=$(echo "$pat" | sed -E 's/\*\./\\./g; s/ /|/g; s/\*/.*/g')
    git ls-files | grep -E "(${ext_pat})$"
}

find_files() {
    local target_dir="${1:-.}"
    local lang="$2"
    local -a found=()
    [[ -z "${FILE_PATTERNS[$lang]:-}" ]] && return
    local patterns=(${FILE_PATTERNS[$lang]})
    local find_args=()
    for pat in "${patterns[@]}"; do
        find_args+=(-name "$pat" -o)
    done
    unset 'find_args[-1]'
    while IFS= read -r -d '' file; do
        [[ -f "$file" && -r "$file" ]] || continue
        [[ "$file" =~ \.(bak|backup|tmp|log|min\.(js|css))$ ]] && continue
        [[ "$file" =~ node_modules|\.git|__pycache__|\.cache ]] && continue
        in_ignore "$file" && continue
        found+=("$file")
    done < <(find "$target_dir" -maxdepth "$MAX_DEPTH" \( "${find_args[@]}" \) -type f -print0 2>/dev/null)
    printf '%s\n' "${found[@]}"
}

detect_language() {
    local file="$1"
    local ext="${file##*.}"
    local base; base=$(basename "$file")
    local shebang; shebang=$(head -n1 "$file" 2>/dev/null || true)
    case "$shebang" in
        "#!/bin/bash"*|"#!/usr/bin/bash"*|"#!/bin/sh"*) echo "shell"; return ;;
        "#!/usr/bin/env bash"*|"#!/usr/bin/env sh"*) echo "shell"; return ;;
        "#!/usr/bin/python"*|"#!/usr/bin/env python"*) echo "python"; return ;;
        "#!/usr/bin/node"*|"#!/usr/bin/env node"*) echo "javascript"; return ;;
    esac
    case "$base" in
        Dockerfile*|dockerfile*) echo "dockerfile"; return ;;
        Makefile*|makefile*) echo "makefile"; return ;;
        Rakefile*|rakefile*) echo "ruby"; return ;;
    esac
    case "$ext" in
        sh|bash|zsh|fish) echo "shell" ;;
        py|pyw|py3) echo "python" ;;
        js|jsx|mjs) echo "javascript" ;;
        ts|tsx) echo "typescript" ;;
        css|scss|sass|less) echo "css" ;;
        json|jsonc) echo "json" ;;
        yml|yaml) echo "yaml" ;;
        md|markdown|mdown) echo "markdown" ;;
        go) echo "go" ;;
        rs) echo "rust" ;;
        rb|rake) echo "ruby" ;;
        java) echo "java" ;;
        cpp|cxx|cc|c|h|hpp|hxx) echo "cpp" ;;
        *) echo "unknown" ;;
    esac
}

process_shell() {
    local file="$1" issues=0 fixes=0
    if command_exists "shellcheck"; then
        local out; out=$(shellcheck -f json "$file" 2>/dev/null || true)
        local cnt; cnt=$(echo "$out" | jq length 2>/dev/null || echo 0)
        [[ $cnt -gt 0 ]] && issues=$((issues+cnt))
        if [[ "$AUTO_FIX" == true && "$EXPERIMENTAL_FIXES" == true && $cnt -gt 0 ]]; then
            prompt_fix "$file" || return
            backup_file "$file"
            sed -i.bak -E '/^[^#]*\$(?!@|\*|#)[A-Za-z_][A-Za-z0-9_]*/s/\$([A-Za-z_][A-Za-z0-9_]*)/\${\1}/g' "$file"
            fixes=$((fixes+1))
        fi
    fi
    printf '{"file":%s,"lang":"shell","issues":%d,"fixed":%d}\n' "$(jq -R <<<"$file")" "$issues" "$fixes"
}

process_python() {
    local file="$1" issues=0 fixes=0
    if command_exists "pylint"; then
        local out; out=$(pylint --output-format=json "$file" 2>/dev/null || true)
        local cnt; cnt=$(echo "$out" | jq length 2>/dev/null || echo 0)
        [[ $cnt -gt 0 ]] && issues=$((issues+cnt))
    fi
    if [[ "$AUTO_FIX" == true ]]; then
        prompt_fix "$file" || return
        backup_file "$file"
        if command_exists "black"; then black --quiet "$file" && ((fixes++)); fi
        if command_exists "isort"; then isort --quiet "$file" && ((fixes++)); fi
    fi
    printf '{"file":%s,"lang":"python","issues":%d,"fixed":%d}\n' "$(jq -R <<<"$file")" "$issues" "$fixes"
}

process_javascript() {
    local file="$1" issues=0 fixes=0
    local eslint_bin="eslint"
    [[ -x "./node_modules/.bin/eslint" ]] && eslint_bin="./node_modules/.bin/eslint"
    if command_exists "$eslint_bin"; then
        local out; out=$($eslint_bin --format json "$file" 2>/dev/null || true)
        local errs; errs=$(echo "$out" | jq '.[0].errorCount' 2>/dev/null || echo 0)
        local warns; warns=$(echo "$out" | jq '.[0].warningCount' 2>/dev/null || echo 0)
        issues=$((issues+errs+warns))
        if [[ "$AUTO_FIX" == true && $issues -gt 0 ]]; then
            prompt_fix "$file" || return
            backup_file "$file"
            $eslint_bin --fix "$file" && ((fixes++))
        fi
    fi
    if [[ "$AUTO_FIX" == true && $(command_exists "prettier") ]]; then
        prettier --write "$file" && ((fixes++))
    fi
    printf '{"file":%s,"lang":"javascript","issues":%d,"fixed":%d}\n' "$(jq -R <<<"$file")" "$issues" "$fixes"
}

process_json() {
    local file="$1" issues=0 fixes=0
    if ! command_exists "jq"; then
        printf '{"file":%s,"lang":"json","issues":1,"fixed":0}\n' "$(jq -R <<<"$file")"
        return
    fi
    jq empty "$file" 2>/dev/null || { issues=$((issues+1)); }
    if [[ "$AUTO_FIX" == true ]]; then
        prompt_fix "$file" || return
        backup_file "$file"
        local tmp; tmp=$(mktemp)
        jq . "$file" > "$tmp" && mv "$tmp" "$file" && ((fixes++))
    fi
    printf '{"file":%s,"lang":"json","issues":%d,"fixed":%d}\n' "$(jq -R <<<"$file")" "$issues" "$fixes"
}

process_yaml() {
    local file="$1" issues=0 fixes=0
    if command_exists "yamllint"; then
        local out; out=$(yamllint -f parsable "$file" 2>/dev/null || true)
        local cnt; cnt=$(echo "$out" | grep -c ':' || echo 0)
        [[ $cnt -gt 0 ]] && issues=$((issues+cnt))
    fi
    if [[ "$AUTO_FIX" == true && $(command_exists "prettier") ]]; then
        prompt_fix "$file" || return
        backup_file "$file"
        prettier --write --parser yaml "$file" && ((fixes++))
    fi
    printf '{"file":%s,"lang":"yaml","issues":%d,"fixed":%d}\n' "$(jq -R <<<"$file")" "$issues" "$fixes"
}

process_go() {
    local file="$1" issues=0 fixes=0
    if command_exists "go"; then
        go vet "$file" 2>/dev/null || issues=$((issues+1))
        if command_exists "staticcheck"; then
            staticcheck "$file" 2>/dev/null || issues=$((issues+1))
        fi
    fi
    if [[ "$AUTO_FIX" == true && $(command_exists "gofmt") ]]; then
        prompt_fix "$file" || return
        backup_file "$file"
        gofmt -w "$file" && ((fixes++))
    fi
    printf '{"file":%s,"lang":"go","issues":%d,"fixed":%d}\n' "$(jq -R <<<"$file")" "$issues" "$fixes"
}

process_rust() {
    local file="$1" issues=0 fixes=0
    if command_exists "cargo"; then
        cargo clippy --quiet || issues=$((issues+1))
    fi
    if [[ "$AUTO_FIX" == true && $(command_exists "rustfmt") ]]; then
        prompt_fix "$file" || return
        backup_file "$file"
        rustfmt "$file" && ((fixes++))
    fi
    printf '{"file":%s,"lang":"rust","issues":%d,"fixed":%d}\n' "$(jq -R <<<"$file")" "$issues" "$fixes"
}

process_cpp() {
    local file="$1" issues=0 fixes=0
    if command_exists "cppcheck"; then
        local out; out=$(cppcheck --enable=warning,style,performance,portability "$file" 2>&1 || true)
        local cnt; cnt=$(echo "$out" | grep -c 'error\|warning' || echo 0)
        [[ $cnt -gt 0 ]] && issues=$((issues+cnt))
    fi
    if [[ "$AUTO_FIX" == true && $(command_exists "clang-format") ]]; then
        prompt_fix "$file" || return
        backup_file "$file"
        clang-format -i "$file" && ((fixes++))
    fi
    printf '{"file":%s,"lang":"cpp","issues":%d,"fixed":%d}\n' "$(jq -R <<<"$file")" "$issues" "$fixes"
}

process_file() {
    local file="$1"
    local lang; lang=$(detect_language "$file")
    case "$lang" in
        shell)      process_shell "$file" ;;
        python)     process_python "$file" ;;
        javascript) process_javascript "$file" ;;
        typescript) process_javascript "$file" ;;
        json)       process_json "$file" ;;
        yaml)       process_yaml "$file" ;;
        go)         process_go "$file" ;;
        rust)       process_rust "$file" ;;
        cpp)        process_cpp "$file" ;;
        dockerfile|makefile)
            printf '{"file":%s,"lang":"%s","issues":0,"fixed":0}\n' "$(jq -R <<<"$file")" "$lang"
            ;;
        unknown)
            printf '{"file":%s,"lang":"unknown","issues":0,"fixed":0}\n' "$(jq -R <<<"$file")"
            ;;
        *)
            printf '{"file":%s,"lang":"unknown","issues":0,"fixed":0}\n' "$(jq -R <<<"$file")"
            ;;
    esac
}

process_directory() {
    local dir="${1:-.}"
    local files=() file
    for lang in "${!FILE_PATTERNS[@]}"; do
        if [[ "$GIT_ONLY" == true ]]; then
            while IFS= read -r file; do
                [[ -n "$file" && -f "$file" ]] && files+=("$file")
            done < <(git_files_for_lang "$lang")
        else
            while IFS= read -r file; do
                [[ -n "$file" ]] && files+=("$file")
            done < <(find_files "$dir" "$lang")
        fi
    done
    local n_files=${#files[@]}
    if [[ $n_files -eq 0 ]]; then
        log "WARN" "No processable files found."
        return
    fi
    log "INFO" "Found $n_files files."
    local stats_tmp; stats_tmp=$(mktemp)
    if [[ "$PARALLEL_JOBS" -gt 1 && "$PROMPT_MODE" == false && "$CI_MODE" == false ]]; then
        printf '%s\n' "${files[@]}" | xargs -n1 -P "$PARALLEL_JOBS" "$0" --worker > "$stats_tmp"
    else
        for ((n=0; n<n_files; n++)); do
            process_file "${files[$n]}" >> "$stats_tmp"
            show_progress $((n+1)) "$n_files" "$(basename "${files[$n]}")"
        done
    fi
    printf "\n"
    # Aggregate stats from JSON lines
    local total_issues=0 total_fixed=0 total_files=0
    declare -A lang_count lang_issues lang_fixed
    FILES_PROCESSED=()
    FILE_ISSUES=()
    FILE_FIXED=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local file lang issues fixed
        file=$(echo "$line" | jq -r '.file')
        lang=$(echo "$line" | jq -r '.lang')
        issues=$(echo "$line" | jq -r '.issues')
        fixed=$(echo "$line" | jq -r '.fixed')
        FILES_PROCESSED+=("$file")
        FILE_ISSUES["$file"]=$issues
        FILE_FIXED["$file"]=$fixed
        lang_count["$lang"]=$((lang_count["$lang"]+1))
        lang_issues["$lang"]=$((lang_issues["$lang"]+issues))
        lang_fixed["$lang"]=$((lang_fixed["$lang"]+fixed))
        total_issues=$((total_issues+issues))
        total_fixed=$((total_fixed+fixed))
        total_files=$((total_files+1))
    done < "$stats_tmp"
    rm "$stats_tmp"
    # Export for report
    TOTAL_FILES=$total_files
    TOTAL_ISSUES=$total_issues
    TOTAL_FIXED=$total_fixed
    for k in "${!lang_count[@]}"; do LANG_COUNT["$k"]=${lang_count[$k]}; done
    for k in "${!lang_issues[@]}"; do LANG_ISSUES["$k"]=${lang_issues[$k]}; done
    for k in "${!lang_fixed[@]}"; do LANG_FIXED["$k"]=${lang_fixed[$k]}; done
}

generate_report_md() {
    local file="$REPORT_MD"
    printf "# CodeFixer Report\n\n" > "$file"
    printf "**Generated:** %s\n" "$(date)" >> "$file"
    printf "**Files:** %d  \n" "$TOTAL_FILES" >> "$file"
    printf "**Issues Found:** %d  \n" "$TOTAL_ISSUES" >> "$file"
    printf "**Issues Fixed:** %d  \n" "$TOTAL_FIXED" >> "$file"
    printf "\n## By Language\n" >> "$file"
    printf "| Language | Files | Issues | Fixed |\n|---|---|---|---|\n" >> "$file"
    for lang in "${!LANG_COUNT[@]}"; do
        printf "| %s | %d | %d | %d |\n" "$lang" "${LANG_COUNT[$lang]}" "${LANG_ISSUES[$lang]:-0}" "${LANG_FIXED[$lang]:-0}" >> "$file"
    done
    printf "\n| File | Issues | Fixed |\n|------|--------|-------|\n" >> "$file"
    for f in "${FILES_PROCESSED[@]}"; do
        printf "| %s | %s | %s |\n" "$f" "${FILE_ISSUES[$f]:-0}" "${FILE_FIXED[$f]:-0}" >> "$file"
    done
    printf "\n---\n*CodeFixer v%s*\n" "$VERSION" >> "$file"
    log "SUCCESS" "Markdown report: $file"
}

generate_report_json() {
    local file="$REPORT_JSON"
    printf '{\n' > "$file"
    printf "  \"generated\": \"%s\",\n" "$(date)" >> "$file"
    printf "  \"files\": %d,\n" "$TOTAL_FILES" >> "$file"
    printf "  \"issues\": %d,\n" "$TOTAL_ISSUES" >> "$file"
    printf "  \"fixed\": %d,\n" "$TOTAL_FIXED" >> "$file"
    printf '  "by_language": {\n' >> "$file"
    local first=1
    for lang in "${!LANG_COUNT[@]}"; do
        [[ $first -eq 0 ]] && printf ",\n" >> "$file"
        printf "    \"%s\": { \"files\": %d, \"issues\": %d, \"fixed\": %d }" \
            "$lang" "${LANG_COUNT[$lang]}" "${LANG_ISSUES[$lang]:-0}" "${LANG_FIXED[$lang]:-0}" >> "$file"
        first=0
    done
    printf "\n  },\n" >> "$file"
    printf '  "details": [\n' >> "$file"
    first=1
    for f in "${FILES_PROCESSED[@]}"; do
        [[ $first -eq 0 ]] && printf ",\n" >> "$file"
        local esc_file
        esc_file=$(printf '%s' "$f" | sed 's/"/\\"/g')
        printf "    { \"file\": \"%s\", \"issues\": %s, \"fixed\": %s }" "$esc_file" "${FILE_ISSUES[$f]:-0}" "${FILE_FIXED[$f]:-0}" >> "$file"
        first=0
    done
    printf "\n  ]\n}\n" >> "$file"
    log "SUCCESS" "JSON report: $file"
}

show_help() {
    printf "CodeFixer v%s - Multi-Language Code Analyzer & Auto-Fixer\n\n" "$VERSION"
    printf "USAGE:\n    %s [OPTIONS] [DIRECTORY]\n\n" "$0"
    printf "OPTIONS:\n"
    printf "    -h, --help          Show this help\n"
    printf "    -v, --verbose       Verbose output\n"
    printf "    -n, --dry-run       Analyze only, no changes\n"
    printf "    -f, --fix           Enable auto-fix\n"
    printf "    -d, --depth N       Max directory depth (default: 5)\n"
    printf "    -j, --jobs N        Parallel jobs (default: 4)\n"
    printf "    --no-backup         Disable backups\n"
    printf "    --ci                Quiet, CI-friendly output\n"
    printf "    --report            Generate Markdown & JSON reports\n"
    printf "    --prompt            Prompt before each fix (disables parallel)\n"
    printf "    --experimental-fixes Enable risky/experimental fixes\n"
    printf "    --git-only          Only scan files tracked by git\n"
    printf "    --worker            (internal) process a single file\n"
    printf "    --version           Print version\n\n"
    printf "CONFIG:\n"
    printf "    Supports depth:, fix:, ignore: arrays, and tool_{lang}: overrides in %s\n" "$DEFAULT_CONFIG"
    printf "    (YAML comments/nesting not supported)\n"
    printf "\nEXAMPLES:\n"
    printf "    %s --fix .              # Analyze & fix\n" "$0"
    printf "    %s --dry-run ~/proj     # Analyze only\n" "$0"
    printf "    %s --report             # Markdown & JSON report\n" "$0"
    printf "\nSupported: Shell, Python, JS/TS, JSON, YAML, Go, Rust, Ruby, Java, C++\n"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit 0 ;;
            -v|--verbose) VERBOSE=true ;;
            -n|--dry-run) DRY_RUN=true; AUTO_FIX=false ;;
            -f|--fix) AUTO_FIX=true; DRY_RUN=false ;;
            -d|--depth) shift; MAX_DEPTH="${1:-5}" ;;
            -j|--jobs) shift; PARALLEL_JOBS="${1:-4}" ;;
            --no-backup) BACKUP_ENABLED=false ;;
            --ci) CI_MODE=true ;;
            --report) GENERATE_REPORT=true ;;
            --prompt) PROMPT_MODE=true ;;
            --experimental-fixes) EXPERIMENTAL_FIXES=true ;;
            --git-only) GIT_ONLY=true ;;
            --worker) shift; process_file "$1"; exit 0 ;;
            --version) printf "CodeFixer %s\n" "$VERSION"; exit 0 ;;
            -*) log "ERROR" "Unknown flag: $1"; exit 1 ;;
            *) TARGET_DIR="$1" ;;
        esac
        shift
    done
}

main() {
    setup_dirs
    load_ignore
    load_config
    log "INFO" "Starting CodeFixer v$VERSION"
    log "INFO" "Target: $TARGET_DIR"
    log "INFO" "Mode: $([ "$DRY_RUN" == true ] && echo DRY RUN || echo ACTIVE)"
    log "INFO" "Auto-fix: $([ "$AUTO_FIX" == true ] && echo ENABLED || echo DISABLED)"
    process_directory "$TARGET_DIR"
    printf "%b\n" "${COLORS[GREEN]}\n🎉 Analysis Complete!${COLORS[NC]}"
    printf "%b\n" "${COLORS[BLUE]}📊 Files: $TOTAL_FILES | Issues: $TOTAL_ISSUES | Fixed: $TOTAL_FIXED${COLORS[NC]}"
    [[ "$GENERATE_REPORT" == true ]] && generate_report_md && generate_report_json
    [[ "$TOTAL_ISSUES" -gt 0 && "$CI_MODE" == true ]] && exit 1 || exit 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main
fi