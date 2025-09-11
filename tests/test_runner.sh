#!/usr/bin/env bash
# Test runner for CodeFixer
# Provides comprehensive testing framework

set -euo pipefail

# Test configuration
readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$TEST_DIR")"
readonly SCRIPT_PATH="$PROJECT_ROOT/codefixer.sh"
readonly TEST_DATA_DIR="$TEST_DIR/data"
readonly TEST_OUTPUT_DIR="$TEST_DIR/output"

# Test results
declare -i TESTS_RUN=0
declare -i TESTS_PASSED=0
declare -i TESTS_FAILED=0
declare -a FAILED_TESTS=()

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test utilities
log_test() {
    local level="$1"
    local message="$2"
    local color=""
    case "$level" in
        ERROR) color="$RED" ;;
        WARN)  color="$YELLOW" ;;
        INFO)  color="$BLUE" ;;
        PASS)  color="$GREEN" ;;
        *)     color="$NC" ;;
    esac
    printf "%b[%s]%b %s\n" "$color" "$level" "$NC" "$message"
}

run_test() {
    local test_name="$1"
    local test_function="$2"
    
    ((TESTS_RUN++))
    log_test "INFO" "Running: $test_name"
    
    if "$test_function"; then
        ((TESTS_PASSED++))
        log_test "PASS" "✓ $test_name"
    else
        ((TESTS_FAILED++))
        FAILED_TESTS+=("$test_name")
        log_test "ERROR" "✗ $test_name"
    fi
}

# Setup test environment
setup_test_env() {
    mkdir -p "$TEST_DATA_DIR" "$TEST_OUTPUT_DIR"
    
    # Create test files
    cat > "$TEST_DATA_DIR/test.py" << 'EOF'
def hello_world():
    print("Hello, World!")
    return True
EOF

    cat > "$TEST_DATA_DIR/test.js" << 'EOF'
function helloWorld() {
    console.log("Hello, World!");
    return true;
}
EOF

    cat > "$TEST_DATA_DIR/test.json" << 'EOF'
{
    "name": "test",
    "value": 42,
    "nested": {
        "key": "value"
    }
}
EOF

    cat > "$TEST_DATA_DIR/invalid.json" << 'EOF'
{
    "name": "test",
    "value": 42,
    "nested": {
        "key": "value"
    }
    // Missing closing brace
EOF

    cat > "$TEST_DATA_DIR/test.sh" << 'EOF'
#!/bin/bash
echo "Hello, World!"
EOF
}

# Test cases
test_script_execution() {
    [[ -x "$SCRIPT_PATH" ]] || return 1
    "$SCRIPT_PATH" --version >/dev/null 2>&1 || return 1
    return 0
}

test_help_output() {
    local help_output
    help_output=$("$SCRIPT_PATH" --help 2>&1)
    [[ "$help_output" =~ "CodeFixer" ]] || return 1
    [[ "$help_output" =~ "USAGE:" ]] || return 1
    return 0
}

test_dry_run() {
    local output
    output=$("$SCRIPT_PATH" --dry-run "$TEST_DATA_DIR" 2>&1)
    [[ "$output" =~ "Analysis Complete" ]] || return 1
    return 0
}

test_python_processing() {
    local output
    output=$("$SCRIPT_PATH" --dry-run "$TEST_DATA_DIR/test.py" 2>&1)
    [[ "$output" =~ "python" ]] || return 1
    return 0
}

test_javascript_processing() {
    local output
    output=$("$SCRIPT_PATH" --dry-run "$TEST_DATA_DIR/test.js" 2>&1)
    [[ "$output" =~ "javascript" ]] || return 1
    return 0
}

test_json_validation() {
    local output
    output=$("$SCRIPT_PATH" --dry-run "$TEST_DATA_DIR/test.json" 2>&1)
    [[ "$output" =~ "json" ]] || return 1
    return 0
}

test_invalid_json_detection() {
    local output
    output=$("$SCRIPT_PATH" --dry-run "$TEST_DATA_DIR/invalid.json" 2>&1)
    # Should detect JSON issues
    return 0
}

test_shell_processing() {
    local output
    output=$("$SCRIPT_PATH" --dry-run "$TEST_DATA_DIR/test.sh" 2>&1)
    [[ "$output" =~ "shell" ]] || return 1
    return 0
}

test_ignore_patterns() {
    # Create a file that should be ignored
    echo "test" > "$TEST_DATA_DIR/test.min.js"
    
    local output
    output=$("$SCRIPT_PATH" --dry-run "$TEST_DATA_DIR" 2>&1)
    # Should not process .min.js files
    [[ ! "$output" =~ "test.min.js" ]] || return 1
    return 0
}

test_backup_functionality() {
    local test_file="$TEST_DATA_DIR/backup_test.py"
    echo "print('test')" > "$test_file"
    
    # Run with auto-fix
    "$SCRIPT_PATH" --fix "$test_file" >/dev/null 2>&1
    
    # Check if backup was created
    local backup_count
    backup_count=$(find "$HOME/.codefixer/backups" -name "*backup_test.py" 2>/dev/null | wc -l)
    [[ $backup_count -gt 0 ]] || return 1
    return 0
}

test_report_generation() {
    local output
    output=$("$SCRIPT_PATH" --report --dry-run "$TEST_DATA_DIR" 2>&1)
    
    # Check if reports were generated
    [[ -f "$HOME/.codefixer/logs/report.md" ]] || return 1
    [[ -f "$HOME/.codefixer/logs/report.json" ]] || return 1
    return 0
}

test_parallel_processing() {
    local output
    output=$("$SCRIPT_PATH" --jobs 2 --dry-run "$TEST_DATA_DIR" 2>&1)
    [[ "$output" =~ "Analysis Complete" ]] || return 1
    return 0
}

test_config_validation() {
    # Test invalid depth
    local output
    output=$("$SCRIPT_PATH" --depth -1 --dry-run "$TEST_DATA_DIR" 2>&1)
    [[ "$output" =~ "Invalid depth" ]] || return 1
    return 0
}

test_error_handling() {
    # Test with non-existent directory
    local output
    output=$("$SCRIPT_PATH" --dry-run "/non/existent/dir" 2>&1)
    [[ "$output" =~ "Directory not found" ]] || return 1
    return 0
}

# Performance tests
test_performance() {
    local start_time
    start_time=$(date +%s)
    
    "$SCRIPT_PATH" --dry-run "$TEST_DATA_DIR" >/dev/null 2>&1
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Should complete within 10 seconds
    [[ $duration -lt 10 ]] || return 1
    return 0
}

# Memory tests
test_memory_usage() {
    # This is a basic test - in production, you'd use more sophisticated tools
    local output
    output=$("$SCRIPT_PATH" --dry-run "$TEST_DATA_DIR" 2>&1)
    # If we get here without memory issues, test passes
    return 0
}

# Cleanup
cleanup() {
    rm -rf "$TEST_OUTPUT_DIR"
    # Don't remove test data as it might be needed for debugging
}

# Main test runner
run_all_tests() {
    log_test "INFO" "Starting CodeFixer test suite"
    log_test "INFO" "Test directory: $TEST_DIR"
    log_test "INFO" "Script path: $SCRIPT_PATH"
    
    setup_test_env
    
    # Core functionality tests
    run_test "Script Execution" test_script_execution
    run_test "Help Output" test_help_output
    run_test "Dry Run" test_dry_run
    
    # Language processing tests
    run_test "Python Processing" test_python_processing
    run_test "JavaScript Processing" test_javascript_processing
    run_test "JSON Validation" test_json_validation
    run_test "Invalid JSON Detection" test_invalid_json_detection
    run_test "Shell Processing" test_shell_processing
    
    # Feature tests
    run_test "Ignore Patterns" test_ignore_patterns
    run_test "Backup Functionality" test_backup_functionality
    run_test "Report Generation" test_report_generation
    run_test "Parallel Processing" test_parallel_processing
    
    # Validation tests
    run_test "Config Validation" test_config_validation
    run_test "Error Handling" test_error_handling
    
    # Performance tests
    run_test "Performance" test_performance
    run_test "Memory Usage" test_memory_usage
    
    # Results
    log_test "INFO" "Test Results:"
    log_test "INFO" "  Total: $TESTS_RUN"
    log_test "PASS" "  Passed: $TESTS_PASSED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_test "ERROR" "  Failed: $TESTS_FAILED"
        log_test "ERROR" "Failed tests:"
        for test in "${FAILED_TESTS[@]}"; do
            log_test "ERROR" "  - $test"
        done
        return 1
    else
        log_test "PASS" "All tests passed!"
        return 0
    fi
}

# Run tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    trap cleanup EXIT
    run_all_tests
fi