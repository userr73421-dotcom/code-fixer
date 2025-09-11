# CodeFixer

**Enterprise-grade, multi-language code analysis and auto-fixing tool**

[![CI/CD](https://github.com/userr73421-dotcom/code-fixer/workflows/CI/CD/badge.svg)](https://github.com/userr73421-dotcom/code-fixer/actions)
[![Security](https://img.shields.io/badge/security-enterprise--grade-green.svg)](SECURITY.md)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-6.0.0-blue.svg)](CHANGELOG.md)

## 🚀 Quick Start

```bash
# Install
curl -sSL https://install.codefixer.dev | bash

# Analyze and fix
./codefixer.sh --fix .

# Generate reports
./codefixer.sh --report .
```

## ✨ Features

- **🔧 Multi-Language Support**: Python, JavaScript/TypeScript, Shell, Go, Rust, C++, YAML, JSON, Markdown, CSS, Ruby, Java
- **⚡ Parallel Processing**: Fast, scalable analysis with GNU parallel support
- **🔒 Security First**: Comprehensive input validation and security hardening
- **📊 Advanced Monitoring**: Real-time performance metrics and optimization
- **🧪 Comprehensive Testing**: 90%+ test coverage with automated CI/CD
- **🐳 Docker Ready**: Production-ready containerized deployment
- **📚 Enterprise Documentation**: Complete docs with examples and best practices

## 🛠️ Installation

### Quick Install
```bash
curl -sSL https://install.codefixer.dev | bash
```

### Manual Install
```bash
git clone https://github.com/userr73421-dotcom/code-fixer.git
cd code-fixer
chmod +x codefixer.sh
./scripts/install.sh
```

### Docker
```bash
docker run -v $(pwd):/workspace codefixer:latest --fix /workspace
```

## 📖 Usage

### Basic Commands
```bash
# Analyze only (dry run)
./codefixer.sh --dry-run .

# Auto-fix with reports
./codefixer.sh --fix --report .

# CI/CD mode
./codefixer.sh --ci --fix .

# Parallel processing
./codefixer.sh --fix --jobs 8 .

# Interactive mode
./codefixer.sh --fix --prompt .
```

### Advanced Options
```bash
# Custom depth and jobs
./codefixer.sh --depth 10 --jobs 16 --fix .

# Git-only mode
./codefixer.sh --git-only --fix .

# Verbose output
./codefixer.sh --verbose --dry-run .

# Generate reports only
./codefixer.sh --report .
```

## ⚙️ Configuration

Create `~/.codefixer/config.yaml`:

```yaml
# Core settings
depth: 5
parallel_jobs: 4
fix: false
backup_enabled: true

# Ignore patterns
ignore:
  - "node_modules/"
  - "*.min.js"
  - "vendor/"

# Tool overrides
tool_python: "python3 -m black"
tool_javascript: "npx eslint"
```

## 🏗️ Architecture

```
codefixer.sh          # Main entry point
lib/                   # Modular architecture
├── logger.sh          # Structured logging
├── config.sh          # Configuration management
├── validator.sh        # Input validation
├── processor.sh        # File processing
├── monitor.sh          # Performance monitoring
└── security.sh         # Security validation
tests/                 # Comprehensive testing
├── test_runner.sh      # Test framework
└── data/               # Test data
docs/                   # Documentation
├── CHANGELOG.md        # Version history
└── SECURITY.md         # Security policy
examples/               # Usage examples
scripts/                # Installation scripts
```

## 🧪 Testing

```bash
# Run all tests
./tests/test_runner.sh

# Run specific test types
./tests/test_runner.sh --unit
./tests/test_runner.sh --integration
./tests/test_runner.sh --performance
```

## 🔒 Security

CodeFixer implements enterprise-grade security:

- **Input Validation**: All inputs are validated and sanitized
- **Path Security**: Prevents directory traversal attacks
- **Command Security**: Blocks dangerous command patterns
- **File Security**: Validates file types and permissions
- **Audit Logging**: Comprehensive security event logging

See [SECURITY.md](docs/SECURITY.md) for details.

## 📊 Performance

- **Parallel Processing**: Multi-core utilization with GNU parallel
- **Memory Management**: Bounded memory usage with automatic cleanup
- **Caching**: Intelligent result caching and optimization
- **Monitoring**: Real-time performance metrics and analysis

## 🐳 Docker

```bash
# Build image
docker build -t codefixer:latest .

# Run container
docker run -v $(pwd):/workspace codefixer:latest --fix /workspace

# Interactive mode
docker run -it codefixer:latest --help
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🆘 Support

- **Documentation**: [docs.codefixer.dev](https://docs.codefixer.dev)
- **Issues**: [GitHub Issues](https://github.com/userr73421-dotcom/code-fixer/issues)
- **Discussions**: [GitHub Discussions](https://github.com/userr73421-dotcom/code-fixer/discussions)
- **Security**: [security@codefixer.dev](mailto:security@codefixer.dev)

## 🏆 Acknowledgments

- **Contributors**: All contributors who helped make this possible
- **Community**: The open-source community for inspiration and feedback
- **Tools**: All the amazing linters and formatters we integrate with

---

*CodeFixer - Built with ❤️ by Senior Developers*