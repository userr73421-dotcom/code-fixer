#!/usr/bin/env bash
# Performance monitoring module for CodeFixer
# Provides metrics collection and performance analysis

set -euo pipefail

# Performance metrics
declare -A METRICS=()
declare -A TIMERS=()
declare -i MEMORY_PEAK=0
declare -i CPU_USAGE=0

# Start timer
start_timer() {
    local name="$1"
    TIMERS["$name"]=$(date +%s.%N)
}

# End timer
end_timer() {
    local name="$1"
    local start_time="${TIMERS[$name]}"
    local end_time
    end_time=$(date +%s.%N)
    
    local duration
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    METRICS["${name}_duration"]="$duration"
    
    unset TIMERS["$name"]
}

# Get current memory usage
get_memory_usage() {
    local pid=$$
    local memory_kb
    memory_kb=$(ps -o rss= -p "$pid" 2>/dev/null || echo "0")
    echo $((memory_kb * 1024))  # Convert to bytes
}

# Get current CPU usage
get_cpu_usage() {
    local pid=$$
    local cpu_percent
    cpu_percent=$(ps -o %cpu= -p "$pid" 2>/dev/null || echo "0")
    echo "${cpu_percent%.*}"  # Remove decimal
}

# Update performance metrics
update_metrics() {
    local current_memory
    current_memory=$(get_memory_usage)
    [[ $current_memory -gt $MEMORY_PEAK ]] && MEMORY_PEAK=$current_memory
    
    CPU_USAGE=$(get_cpu_usage)
    METRICS[memory_peak]="$MEMORY_PEAK"
    METRICS[cpu_usage]="$CPU_USAGE"
}

# Log performance metrics
log_metrics() {
    log_debug "Performance Metrics:"
    for key in "${!METRICS[@]}"; do
        log_debug "  $key: ${METRICS[$key]}"
    done
}

# Generate performance report
generate_performance_report() {
    local file="$1"
    
    {
        printf "# Performance Report\n\n"
        printf "**Generated:** %s\n" "$(date)"
        printf "**Version:** %s\n" "$VERSION"
        printf "\n## Metrics\n"
        printf "| Metric | Value |\n|---|---|\n"
        
        for key in "${!METRICS[@]}"; do
            printf "| %s | %s |\n" "$key" "${METRICS[$key]}"
        done
        
        printf "\n## Summary\n"
        printf "- **Peak Memory:** %s bytes\n" "${METRICS[memory_peak]:-0}"
        printf "- **CPU Usage:** %s%%\n" "${METRICS[cpu_usage]:-0}"
        printf "- **Total Duration:** %s seconds\n" "${METRICS[total_duration]:-0}"
        printf "- **Files Processed:** %s\n" "${METRICS[files_processed]:-0}"
        printf "- **Files Per Second:** %s\n" "${METRICS[files_per_second]:-0}"
    } > "$file"
    
    log_success "Performance report: $file"
}

# Calculate files per second
calculate_files_per_second() {
    local files_processed="${METRICS[files_processed]:-0}"
    local total_duration="${METRICS[total_duration]:-1}"
    
    if [[ $total_duration -gt 0 ]]; then
        local fps
        fps=$(echo "scale=2; $files_processed / $total_duration" | bc -l 2>/dev/null || echo "0")
        METRICS[files_per_second]="$fps"
    else
        METRICS[files_per_second]="0"
    fi
}

# Monitor system resources
monitor_system() {
    local interval="${1:-5}"
    
    while true; do
        update_metrics
        sleep "$interval"
    done &
    
    local monitor_pid=$!
    echo "$monitor_pid"
}

# Stop monitoring
stop_monitoring() {
    local monitor_pid="$1"
    kill "$monitor_pid" 2>/dev/null || true
}

# Check system health
check_system_health() {
    local warnings=0
    
    # Check memory usage
    local memory_usage
    memory_usage=$(get_memory_usage)
    if [[ $memory_usage -gt 1073741824 ]]; then  # 1GB
        log_warn "High memory usage: $((memory_usage / 1024 / 1024))MB"
        ((warnings++))
    fi
    
    # Check CPU usage
    local cpu_usage
    cpu_usage=$(get_cpu_usage)
    if [[ $cpu_usage -gt 80 ]]; then
        log_warn "High CPU usage: ${cpu_usage}%"
        ((warnings++))
    fi
    
    # Check disk space
    local disk_usage
    disk_usage=$(df "$HOME" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 90 ]]; then
        log_warn "High disk usage: ${disk_usage}%"
        ((warnings++))
    fi
    
    return $warnings
}

# Optimize performance
optimize_performance() {
    # Set optimal file descriptors limit
    ulimit -n 4096 2>/dev/null || true
    
    # Set optimal process limits
    ulimit -u 1024 2>/dev/null || true
    
    # Optimize bash settings
    set +u  # Allow undefined variables for better performance
    shopt -s nullglob  # Enable null globbing
    
    log_debug "Performance optimizations applied"
}

# Cleanup resources
cleanup_resources() {
    # Kill any background processes
    jobs -p | xargs kill 2>/dev/null || true
    
    # Clear temporary files
    find /tmp -name "codefixer_*" -mtime +1 -delete 2>/dev/null || true
    
    log_debug "Resources cleaned up"
}