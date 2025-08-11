# Build stage
FROM golang:1.23-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Runtime stage - using Debian for better Python package compatibility
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Python ML dependencies using pre-built wheels
RUN pip install --upgrade pip && \
    pip install --no-cache-dir \
    numpy==1.24.3 \
    pandas==2.0.3 \
    scikit-learn==1.3.0 \
    joblib==1.3.2

# Create app user
RUN groupadd -g 1001 appgroup && \
    useradd -u 1001 -g appgroup -s /bin/bash -m appuser

# Set working directory
WORKDIR /app

# Copy binary from builder stage
COPY --from=builder /app/main .

# Copy Python scripts (read-only, no persistence needed)
COPY --chown=appuser:appgroup scripts/ ./scripts/

# Create persistent data directory structure
RUN mkdir -p /app/persistent_data/{ml_models,ml_cache,scalers,stock_data/{historical,cache,predictions},logs,config,backups,monitoring/{prometheus,grafana}} && \
    chown -R appuser:appgroup /app/persistent_data

# Create traditional directories and link to persistent storage
RUN mkdir -p /app/models /app/logs /app/config && \
    chown -R appuser:appgroup /app/models /app/logs /app/config

# Copy default models and config if they exist (will be overridden by volumes)
COPY --chown=appuser:appgroup models/ ./models/

# Create data initialization script
RUN echo '#!/bin/bash\n\
# Initialize persistent data directories if empty\n\
echo "🔄 Initializing persistent data directories..."\n\
\n\
# Create directories if they dont exist\n\
mkdir -p /app/persistent_data/{ml_models,ml_cache,scalers,stock_data/{historical,cache,predictions},logs,config,backups}\n\
\n\
# Copy default models if persistent directory is empty\n\
if [ ! "$(ls -A /app/persistent_data/ml_models 2>/dev/null)" ] && [ -d /app/models ]; then\n\
    echo "📦 Copying default models to persistent storage..."\n\
    cp -r /app/models/* /app/persistent_data/ml_models/ 2>/dev/null || true\n\
fi\n\
\n\
# Set proper permissions\n\
chown -R appuser:appgroup /app/persistent_data\n\
chmod -R 755 /app/persistent_data\n\
\n\
echo "✅ Persistent data initialization completed"\n\
' > /app/init_data.sh && chmod +x /app/init_data.sh

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/api/v1/health || exit 1

# Initialize persistent data and run the application
CMD ["/bin/bash", "-c", "/app/init_data.sh && ./main"]
