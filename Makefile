# CodeFixer v6.0 - Senior Developer Edition
# Comprehensive build and development automation

.PHONY: help install test lint security clean build release deploy docs

# Configuration
VERSION := 6.0.0
SCRIPT_NAME := codefixer_v6.sh
TEST_DIR := tests
LIB_DIR := lib
DOCS_DIR := docs

# Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

# Help target
help: ## Show this help message
	@echo "CodeFixer v$(VERSION) - Senior Developer Edition"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(BLUE)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Installation
install: ## Install CodeFixer and dependencies
	@echo "$(GREEN)Installing CodeFixer v$(VERSION)...$(NC)"
	@chmod +x $(SCRIPT_NAME)
	@chmod +x $(TEST_DIR)/test_runner.sh
	@chmod +x $(LIB_DIR)/*.sh
	@./install.sh
	@echo "$(GREEN)Installation complete!$(NC)"

# Testing
test: ## Run all tests
	@echo "$(BLUE)Running test suite...$(NC)"
	@$(TEST_DIR)/test_runner.sh
	@echo "$(GREEN)All tests passed!$(NC)"

test-unit: ## Run unit tests only
	@echo "$(BLUE)Running unit tests...$(NC)"
	@$(TEST_DIR)/test_runner.sh --unit

test-integration: ## Run integration tests only
	@echo "$(BLUE)Running integration tests...$(NC)"
	@$(TEST_DIR)/test_runner.sh --integration

test-performance: ## Run performance tests
	@echo "$(BLUE)Running performance tests...$(NC)"
	@$(TEST_DIR)/test_runner.sh --performance

# Linting and formatting
lint: ## Run linting on all scripts
	@echo "$(BLUE)Running linting...$(NC)"
	@shellcheck $(SCRIPT_NAME) $(LIB_DIR)/*.sh $(TEST_DIR)/*.sh
	@echo "$(GREEN)Linting complete!$(NC)"

format: ## Format all scripts
	@echo "$(BLUE)Formatting scripts...$(NC)"
	@./$(SCRIPT_NAME) --fix .
	@echo "$(GREEN)Formatting complete!$(NC)"

# Security
security: ## Run security analysis
	@echo "$(BLUE)Running security analysis...$(NC)"
	@./$(SCRIPT_NAME) --dry-run --report .
	@echo "$(GREEN)Security analysis complete!$(NC)"

security-audit: ## Run comprehensive security audit
	@echo "$(BLUE)Running security audit...$(NC)"
	@./$(SCRIPT_NAME) --dry-run --report .
	@grep -r "eval\|exec\|system" . --include="*.sh" || true
	@grep -r "sudo\|su" . --include="*.sh" || true
	@echo "$(GREEN)Security audit complete!$(NC)"

# Build and release
build: test lint security ## Build the project
	@echo "$(BLUE)Building CodeFixer v$(VERSION)...$(NC)"
	@mkdir -p build
	@cp $(SCRIPT_NAME) build/
	@cp -r $(LIB_DIR) build/
	@cp -r $(TEST_DIR) build/
	@cp README*.md build/
	@cp LICENSE* build/
	@cp config*.yaml build/
	@cp *.txt build/
	@echo "$(GREEN)Build complete!$(NC)"

release: build ## Create release package
	@echo "$(BLUE)Creating release package...$(NC)"
	@tar -czf codefixer-v$(VERSION).tar.gz -C build .
	@echo "$(GREEN)Release package created: codefixer-v$(VERSION).tar.gz$(NC)"

# Documentation
docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	@mkdir -p $(DOCS_DIR)
	@./$(SCRIPT_NAME) --help > $(DOCS_DIR)/help.txt
	@./$(SCRIPT_NAME) --dry-run --report . > $(DOCS_DIR)/sample-report.md
	@echo "$(GREEN)Documentation generated!$(NC)"

# Development
dev-setup: ## Set up development environment
	@echo "$(BLUE)Setting up development environment...$(NC)"
	@chmod +x $(SCRIPT_NAME)
	@chmod +x $(TEST_DIR)/test_runner.sh
	@chmod +x $(LIB_DIR)/*.sh
	@./install.sh --dev
	@echo "$(GREEN)Development environment ready!$(NC)"

dev-test: ## Run development tests
	@echo "$(BLUE)Running development tests...$(NC)"
	@./$(SCRIPT_NAME) --dry-run --verbose .
	@$(TEST_DIR)/test_runner.sh
	@echo "$(GREEN)Development tests complete!$(NC)"

# Performance
benchmark: ## Run performance benchmarks
	@echo "$(BLUE)Running performance benchmarks...$(NC)"
	@time ./$(SCRIPT_NAME) --dry-run --jobs 1 .
	@time ./$(SCRIPT_NAME) --dry-run --jobs 4 .
	@time ./$(SCRIPT_NAME) --dry-run --jobs 8 .
	@echo "$(GREEN)Benchmarks complete!$(NC)"

profile: ## Profile the application
	@echo "$(BLUE)Profiling application...$(NC)"
	@valgrind --tool=callgrind ./$(SCRIPT_NAME) --dry-run . || true
	@echo "$(GREEN)Profiling complete!$(NC)"

# Cleanup
clean: ## Clean build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	@rm -rf build/
	@rm -f codefixer-v*.tar.gz
	@rm -rf $(DOCS_DIR)/
	@rm -rf ~/.codefixer/logs/
	@rm -rf ~/.codefixer/backups/
	@rm -rf ~/.codefixer/cache/
	@echo "$(GREEN)Cleanup complete!$(NC)"

# Docker
docker-build: ## Build Docker image
	@echo "$(BLUE)Building Docker image...$(NC)"
	@docker build -t codefixer:v$(VERSION) .
	@echo "$(GREEN)Docker image built!$(NC)"

docker-test: ## Run tests in Docker
	@echo "$(BLUE)Running tests in Docker...$(NC)"
	@docker run --rm codefixer:v$(VERSION) ./tests/test_runner.sh
	@echo "$(GREEN)Docker tests complete!$(NC)"

# CI/CD
ci: test lint security ## Run CI pipeline
	@echo "$(BLUE)Running CI pipeline...$(NC)"
	@echo "$(GREEN)CI pipeline complete!$(NC)"

# Quality assurance
qa: test lint security benchmark ## Run full quality assurance
	@echo "$(BLUE)Running quality assurance...$(NC)"
	@echo "$(GREEN)Quality assurance complete!$(NC)"

# All-in-one
all: clean install test lint security build release ## Run everything
	@echo "$(GREEN)All tasks complete!$(NC)"

# Default target
.DEFAULT_GOAL := help