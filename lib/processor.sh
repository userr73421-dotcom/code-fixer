#!/usr/bin/env bash
# File processing module for CodeFixer
# Handles language detection and file processing

set -euo pipefail

# Language detection patterns
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

# Language processors
declare -A LANGUAGE_PROCESSORS=(
    [shell]="process_shell"
    [python]="process_python"
    [javascript]="process_javascript"
    [typescript]="process_javascript"
    [json]="process_json"
    [yaml]="process_yaml"
    [go]="process_go"
    [rust]="process_rust"
    [cpp]="process_cpp"
)

detect_language() {
    local file="$1"
    local ext="${file##*.}"
    local base
    base=$(basename "$file")
    local shebang
    shebang=$(head -n1 "$file" 2>/dev/null || true)
    
    # Check shebang
    case "$shebang" in
        "#!/bin/bash"*|"#!/usr/bin/bash"*|"#!/bin/sh"*) echo "shell"; return ;;
        "#!/usr/bin/env bash"*|"#!/usr/bin/env sh"*) echo "shell"; return ;;
        "#!/usr/bin/python"*|"#!/usr/bin/env python"*) echo "python"; return ;;
        "#!/usr/bin/node"*|"#!/usr/bin/env node"*) echo "javascript"; return ;;
    esac
    
    # Check special filenames
    case "$base" in
        Dockerfile*|dockerfile*) echo "dockerfile"; return ;;
        Makefile*|makefile*) echo "makefile"; return ;;
        Rakefile*|rakefile*) echo "ruby"; return ;;
    esac
    
    # Check extensions
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

get_language_processor() {
    local lang="$1"
    printf '%s' "${LANGUAGE_PROCESSORS[$lang]:-}"
}

find_files_for_language() {
    local target_dir="$1"
    local lang="$2"
    local -a found=()
    
    [[ -n "${FILE_PATTERNS[$lang]:-}" ]] || return 0
    
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
        is_ignored "$file" && continue
        found+=("$file")
    done < <(find "$target_dir" -maxdepth "$(get_config MAX_DEPTH)" \( "${find_args[@]}" \) -type f -print0 2>/dev/null)
    
    printf '%s\n' "${found[@]}"
}

git_files_for_language() {
    local lang="$1"
    local pat="${FILE_PATTERNS[$lang]}"
    local ext_pat
    ext_pat=$(echo "$pat" | sed -E 's/\*\./\\./g; s/ /|/g; s/\*/.*/g')
    git ls-files | grep -E "(${ext_pat})$" || true
}

process_file() {
    local file="$1"
    
    # Validate file
    validate_file "$file" || return 1
    
    # Detect language
    local lang
    lang=$(detect_language "$file")
    
    # Get processor function
    local processor
    processor=$(get_language_processor "$lang")
    
    if [[ -n "$processor" ]]; then
        # Call the appropriate processor
        "$processor" "$file"
    else
        # Unknown language, just report
        printf '{"file":%s,"lang":"%s","issues":0,"fixed":0}\n' "$(jq -R <<<"$file")" "$lang"
    fi
}

# Process files in parallel
process_files_parallel() {
    local files=("$@")
    local n_files=${#files[@]}
    local parallel_jobs
    parallel_jobs=$(get_config PARALLEL_JOBS)
    
    if [[ $n_files -eq 0 ]]; then
        log_warn "No files to process"
        return 0
    fi
    
    log_info "Processing $n_files files with $parallel_jobs parallel jobs"
    
    local stats_tmp
    stats_tmp=$(mktemp)
    
    # Use GNU parallel if available, otherwise fall back to xargs
    if command -v parallel >/dev/null 2>&1; then
        printf '%s\n' "${files[@]}" | parallel -j "$parallel_jobs" "$0" --worker > "$stats_tmp" 2>/dev/null || {
            log_warn "Parallel processing failed, falling back to sequential"
            process_files_sequential "${files[@]}" > "$stats_tmp"
        }
    else
        printf '%s\n' "${files[@]}" | xargs -n1 -P "$parallel_jobs" "$0" --worker > "$stats_tmp" 2>/dev/null || {
            log_warn "Parallel processing failed, falling back to sequential"
            process_files_sequential "${files[@]}" > "$stats_tmp"
        }
    fi
    
    # Process results
    process_results "$stats_tmp"
    rm -f "$stats_tmp"
}

# Process files sequentially
process_files_sequential() {
    local files=("$@")
    local n_files=${#files[@]}
    
    for ((i=0; i<n_files; i++)); do
        process_file "${files[$i]}" || log_error "Failed to process ${files[$i]}"
        show_progress $((i+1)) "$n_files" "$(basename "${files[$i]}")"
    done
}

# Process results and update statistics
process_results() {
    local stats_file="$1"
    local total_issues=0
    local total_fixed=0
    local total_files=0
    
    declare -A lang_count
    declare -A lang_issues
    declare -A lang_fixed
    
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
        
        lang_count["$lang"]=$((${lang_count[$lang]:-0} + 1))
        lang_issues["$lang"]=$((${lang_issues[$lang]:-0} + issues))
        lang_fixed["$lang"]=$((${lang_fixed[$lang]:-0} + fixed))
        
        total_issues=$((total_issues + issues))
        total_fixed=$((total_fixed + fixed))
        total_files=$((total_files + 1))
    done < "$stats_file"
    
    # Update global stats
    TOTAL_FILES=$total_files
    TOTAL_ISSUES=$total_issues
    TOTAL_FIXED=$total_fixed
    
    for k in "${!lang_count[@]}"; do
        LANG_COUNT["$k"]=${lang_count[$k]}
    done
    for k in "${!lang_issues[@]}"; do
        LANG_ISSUES["$k"]=${lang_issues[$k]}
    done
    for k in "${!lang_fixed[@]}"; do
        LANG_FIXED["$k"]=${lang_fixed[$k]}
    done
}