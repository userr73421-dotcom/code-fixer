#!/usr/bin/env bash
# CodeFixer Basic Usage Examples
# Senior Developer Edition

set -euo pipefail

echo "CodeFixer Basic Usage Examples"
echo "=============================="
echo

echo "1. Basic Analysis (Dry Run)"
echo "   ./codefixer.sh --dry-run ."
echo

echo "2. Auto-fix with Reports"
echo "   ./codefixer.sh --fix --report ."
echo

echo "3. CI/CD Mode"
echo "   ./codefixer.sh --ci --fix ."
echo

echo "4. Parallel Processing"
echo "   ./codefixer.sh --fix --jobs 8 ."
echo

echo "5. Interactive Mode"
echo "   ./codefixer.sh --fix --prompt ."
echo

echo "6. Git-only Mode"
echo "   ./codefixer.sh --git-only --fix ."
echo

echo "7. Verbose Output"
echo "   ./codefixer.sh --verbose --dry-run ."
echo

echo "8. Custom Depth"
echo "   ./codefixer.sh --depth 10 --fix ."
echo

echo "9. Generate Reports Only"
echo "   ./codefixer.sh --report ."
echo

echo "10. Help"
echo "    ./codefixer.sh --help"
echo

echo "For more examples, see the documentation in docs/"