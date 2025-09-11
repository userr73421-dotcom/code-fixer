# CodeFixer v6.0 - Senior Developer Edition
# Multi-stage Docker build for production deployment

# Build stage
FROM ubuntu:22.04 AS builder

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# Install Python and pip
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Install Go
RUN wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz \
    && rm go1.21.0.linux-amd64.tar.gz

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Ruby
RUN apt-get update && apt-get install -y \
    ruby \
    ruby-dev \
    && rm -rf /var/lib/apt/lists/*

# Production stage
FROM ubuntu:22.04 AS production

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PATH="/usr/local/go/bin:${PATH}"

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    bash \
    shellcheck \
    jq \
    yamllint \
    git \
    curl \
    wget \
    bc \
    file \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# Install Python and pip
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Go
COPY --from=builder /usr/local/go /usr/local/go

# Install Rust
COPY --from=builder /root/.cargo /root/.cargo
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Ruby
RUN apt-get update && apt-get install -y \
    ruby \
    ruby-dev \
    && rm -rf /var/lib/apt/lists/*

# Install language-specific tools
RUN pip3 install --no-cache-dir \
    pylint \
    black \
    isort \
    mypy \
    yamllint

RUN npm install -g \
    eslint \
    prettier \
    @typescript-eslint/parser \
    markdownlint \
    stylelint

RUN gem install rubocop

RUN go install golang.org/x/lint/golint@latest

RUN cargo install clippy rustfmt

# Create non-root user
RUN useradd -m -s /bin/bash codefixer

# Set up directories
RUN mkdir -p /app /home/codefixer/.codefixer/{logs,backups,cache}
RUN chown -R codefixer:codefixer /app /home/codefixer/.codefixer

# Copy application files
COPY --chown=codefixer:codefixer codefixer_v6.sh /app/
COPY --chown=codefixer:codefixer lib/ /app/lib/
COPY --chown=codefixer:codefixer tests/ /app/tests/
COPY --chown=codefixer:codefixer README*.md /app/
COPY --chown=codefixer:codefixer LICENSE* /app/
COPY --chown=codefixer:codefixer config*.yaml /app/
COPY --chown=codefixer:codefixer *.txt /app/

# Make scripts executable
RUN chmod +x /app/codefixer_v6.sh
RUN chmod +x /app/lib/*.sh
RUN chmod +x /app/tests/*.sh

# Switch to non-root user
USER codefixer
WORKDIR /app

# Set up environment
ENV HOME=/home/codefixer
ENV CONFIG_DIR=/home/codefixer/.codefixer
ENV LOG_DIR=/home/codefixer/.codefixer/logs
ENV BACKUP_DIR=/home/codefixer/.codefixer/backups
ENV CACHE_DIR=/home/codefixer/.codefixer/cache

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ./codefixer_v6.sh --version || exit 1

# Default command
ENTRYPOINT ["./codefixer_v6.sh"]
CMD ["--help"]

# Labels
LABEL maintainer="CodeFixer Team <team@codefixer.dev>"
LABEL version="6.0.0"
LABEL description="CodeFixer v6.0 - Senior Developer Edition"
LABEL org.opencontainers.image.title="CodeFixer"
LABEL org.opencontainers.image.description="Multi-language code analysis and auto-fixing tool"
LABEL org.opencontainers.image.version="6.0.0"
LABEL org.opencontainers.image.vendor="CodeFixer Team"
LABEL org.opencontainers.image.licenses="MIT"