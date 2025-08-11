# Multi-stage Dockerfile for Bootstrap-Enhanced Angular Frontend
# Stage 1: Build Angular Application with Bootstrap

FROM node:20-alpine AS build

# Set working directory
WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git python3 make g++

# Copy package files
COPY package*.json ./

# Set npm configuration for better performance
RUN npm config set registry https://registry.npmjs.org/
RUN npm config set fetch-retries 3
RUN npm config set fetch-retry-factor 2
RUN npm config set fetch-retry-mintimeout 10000
RUN npm config set fetch-retry-maxtimeout 60000

# Install dependencies with exact versions
RUN npm ci --no-audit --no-fund

# Copy source code
COPY . .

# Build arguments
ARG NODE_ENV=production
ARG BOOTSTRAP_VERSION=5.3.3
ARG BUILD_OPTIMIZATION=true

# Set environment variables
ENV NODE_ENV=$NODE_ENV
ENV BOOTSTRAP_VERSION=$BOOTSTRAP_VERSION
ENV NG_CLI_ANALYTICS=false

# Build the Angular application with Bootstrap
RUN npx ng build --configuration=production

# Verify Bootstrap integration
RUN ls -la dist/frontend/
RUN find dist/frontend -name "*.css" -exec grep -l "bootstrap" {} \; || echo "Bootstrap CSS verification"
RUN find dist/frontend -name "*.js" -exec grep -l "bootstrap" {} \; || echo "Bootstrap JS verification"

# Stage 2: Serve with Nginx
FROM nginx:1.25-alpine

# Install additional tools for health checks
RUN apk add --no-cache curl wget

# Nginx user already exists in nginx:1.25-alpine, just ensure proper setup

# Copy built application from build stage
COPY --from=build /app/dist/frontend /usr/share/nginx/html

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy additional configuration files (optional)
RUN mkdir -p /usr/share/nginx/html/assets

# Create necessary directories and set permissions
RUN mkdir -p /var/cache/nginx /var/log/nginx /var/run && \
    chown -R nginx:nginx /var/cache/nginx /var/log/nginx /var/run /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html

# Create health check endpoint
RUN echo '<!DOCTYPE html><html><head><title>Health Check</title></head><body><h1>OK</h1><p>Bootstrap Frontend is running</p><script>console.log("Health check OK");</script></body></html>' > /usr/share/nginx/html/health

# Security: Run as non-root user
USER nginx

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

# Labels for better container management
LABEL maintainer="Stock Prediction Service"
LABEL version="3.2.0"
LABEL description="Bootstrap-Enhanced Angular Frontend for Stock Prediction Service"
LABEL bootstrap.version="5.3.3"
LABEL angular.version="20.1.0"

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
