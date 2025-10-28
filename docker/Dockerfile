# Multi-stage build for smaller, more secure image
FROM debian:stable-slim AS base

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    pdftk-java \
    qpdf \
    inotify-tools \
    coreutils \
    file \
    procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/*

# Create non-root user for security
RUN groupadd -r duplexer && useradd -r -g duplexer -s /bin/bash duplexer

# Create application directories
RUN mkdir -p /duplex-inbox /paperless-consume /logs /app/config \
    && chown -R duplexer:duplexer /duplex-inbox /paperless-consume /logs /app

WORKDIR /app

# Copy application files
COPY scripts/merge_once.sh /app/merge_once.sh
COPY scripts/watch.sh /app/watch.sh
COPY scripts/health_check.sh /app/health_check.sh
COPY scripts/logrotate.sh /app/logrotate.sh
COPY config/duplexer.conf /app/config/duplexer.conf

# Set permissions
RUN chmod +x /app/*.sh \
    && chown -R duplexer:duplexer /app

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD /app/health_check.sh

# Switch to non-root user
USER duplexer

# Set up environment
ENV INBOX=/duplex-inbox \
    OUTBOX=/paperless-consume \
    LOGFILE=/logs/duplexer.log

# Expose any volumes
VOLUME ["/duplex-inbox", "/paperless-consume", "/logs"]

# Run the application
CMD ["/app/watch.sh"]
