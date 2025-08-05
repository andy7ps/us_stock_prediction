# 🐳 Docker User Guide - Bootstrap Enhanced

## Overview
Complete Docker deployment guide for the Bootstrap-enhanced Stock Prediction Service v3.2, featuring Angular 20+ with Bootstrap 5.3.3 frontend and Go backend with persistent storage.

## 🎨 **Bootstrap Integration Features**

### Frontend Enhancements
- **Bootstrap 5.3.3**: Latest stable version with full component library
- **Bootstrap Icons 1.13.1**: Complete scalable icon library (1,800+ icons)
- **Mobile-First Design**: Responsive breakpoints for all screen sizes
- **Professional UI**: Card-based layout with glass effects and animations
- **Accessibility**: WCAG 2.1 compliance with enhanced screen reader support
- **Dark Mode**: System preference detection and automatic switching
- **PWA Ready**: Progressive Web App capabilities maintained

## 🏗️ **Architecture Overview**

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Network                           │
│  ┌─────────────────┐    ┌──────────────────┐               │
│  │  Bootstrap      │    │   Go Backend     │               │
│  │  Angular        │───▶│   API Server     │               │
│  │  Frontend       │    │   (Port 8081)    │               │
│  │  (Port 8080)    │    └──────────────────┘               │
│  └─────────────────┘              │                        │
│           │                       │                        │
│           │              ┌──────────────────┐               │
│           │              │   Prometheus     │               │
│           │              │   Monitoring     │               │
│           │              │   (Port 9090)    │               │
│           │              └──────────────────┘               │
│           │                       │                        │
│           │              ┌──────────────────┐               │
│           └─────────────▶│     Grafana      │               │
│                          │   Dashboards     │               │
│                          │   (Port 3000)    │               │
│                          └──────────────────┘               │
│                                   │                        │
│  ┌─────────────────────────────────────────────────────────┤
│  │              Persistent Storage                         │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│  │  │ ML Models   │ │ Stock Data  │ │ Monitoring  │       │
│  │  │ & Cache     │ │ & Logs      │ │ Data        │       │
│  │  └─────────────┘ └─────────────┘ └─────────────┘       │
│  └─────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────┘
```

## 🚀 **Quick Start**

### Prerequisites
- **Docker**: 20.10+ with Docker Compose
- **System Requirements**: 4GB RAM, 10GB disk space
- **Network**: Ports 8080, 8081, 3000, 9090 available

### One-Command Deployment
```bash
# Clone repository
git clone https://github.com/andy7ps/us_stock_prediction.git
cd us_stock_prediction

# Deploy Bootstrap-enhanced service
./deploy_docker_bootstrap.sh

# Access the application
# Frontend: http://localhost:8080
# Backend: http://localhost:8081
# Grafana: http://localhost:3000 (admin/admin)
```

## 📋 **Detailed Deployment**

### Step 1: Environment Setup
```bash
# Verify Docker installation
docker --version
docker-compose --version

# Check available ports
netstat -tuln | grep -E ':(8080|8081|3000|9090)'

# Setup persistent storage
./setup_persistent_storage.sh
```

### Step 2: Configuration
```bash
# Copy environment template
cp .env.example .env

# Edit configuration (optional)
nano .env
```

**Key Environment Variables:**
```bash
# Server Configuration
SERVER_PORT=8081
LOG_LEVEL=info

# Bootstrap Frontend
FRONTEND_URL=http://localhost:8080
BOOTSTRAP_MODE=enabled
UI_THEME=bootstrap

# Stock Configuration
STOCK_SYMBOL=NVDA
STOCK_LOOKBACK_DAYS=5

# Persistent Storage
ML_MODEL_PATH=/app/persistent_data/ml_models/nvda_lstm_model
STOCK_DATA_CACHE_PATH=/app/persistent_data/stock_data/cache
```

### Step 3: Build and Deploy
```bash
# Development deployment
./deploy_docker_bootstrap.sh

# Production deployment
./deploy_docker_bootstrap.sh --production

# Force rebuild
./deploy_docker_bootstrap.sh --rebuild

# Skip tests (faster deployment)
./deploy_docker_bootstrap.sh --skip-tests
```

## 🐳 **Container Details**

### Frontend Container (Bootstrap Angular)
```dockerfile
# Multi-stage build for optimized Bootstrap frontend
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build -- --configuration=production

FROM nginx:1.25-alpine
COPY --from=build /app/dist/frontend /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
```

**Features:**
- **Bootstrap 5.3.3**: Integrated CSS and JS components
- **Bootstrap Icons**: Complete icon library
- **Nginx Optimization**: Gzip compression, caching headers
- **Security Headers**: XSS protection, CSRF prevention
- **Mobile Optimization**: Touch-friendly responsive design

### Backend Container (Go API)
```dockerfile
FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o stock-prediction main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates wget
COPY --from=builder /app/stock-prediction /app/
EXPOSE 8081
```

**Features:**
- **Go 1.23**: Latest stable Go runtime
- **Multi-stage Build**: Optimized image size
- **Health Checks**: Built-in health monitoring
- **Persistent Storage**: Volume mounts for data persistence

## 📊 **Service Configuration**

### Docker Compose Services

#### Frontend Service
```yaml
frontend:
  build:
    context: ./frontend
    dockerfile: Dockerfile
    args:
      - BOOTSTRAP_VERSION=5.3.3
  ports:
    - "8080:80"
  environment:
    - NGINX_HOST=localhost
    - BOOTSTRAP_THEME=enabled
  volumes:
    - ./frontend/nginx.conf:/etc/nginx/nginx.conf:ro
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:80/health"]
    interval: 30s
    timeout: 10s
    retries: 3
```

#### Backend Service
```yaml
stock-prediction:
  build: .
  ports:
    - "8081:8081"
  environment:
    - FRONTEND_URL=http://localhost:8080
    - BOOTSTRAP_MODE=enabled
    - CORS_ORIGINS=http://localhost:8080
  volumes:
    - ./persistent_data:/app/persistent_data
  healthcheck:
    test: ["CMD", "wget", "--spider", "http://localhost:8081/api/v1/health"]
    interval: 30s
    timeout: 10s
    retries: 3
```

## 🔧 **Management Commands**

### Container Management
```bash
# View running containers
docker-compose ps

# View logs
docker-compose logs -f

# Restart specific service
docker-compose restart frontend

# Scale services (if needed)
docker-compose up -d --scale frontend=2

# Update containers
docker-compose pull
docker-compose up -d
```

### Health Monitoring
```bash
# Comprehensive health check
./health_check_bootstrap.sh

# Check specific service
docker-compose exec frontend curl http://localhost:80/health
docker-compose exec stock-prediction wget -qO- http://localhost:8081/api/v1/health

# Monitor resource usage
docker stats
```

### Data Management
```bash
# Backup persistent data
tar -czf backup-$(date +%Y%m%d).tar.gz persistent_data/

# Restore from backup
tar -xzf backup-20250805.tar.gz

# Clean up old data
docker-compose down --volumes
docker system prune -f
```

## 🎨 **Bootstrap Customization**

### Theme Configuration
The Bootstrap theme can be customized through environment variables and CSS overrides:

```bash
# Environment variables
BOOTSTRAP_THEME=enabled
UI_PRIMARY_COLOR=#667eea
UI_SECONDARY_COLOR=#764ba2
UI_DARK_MODE=auto
```

### Custom CSS Override
```css
/* Custom Bootstrap theme in frontend/src/styles.css */
:root {
  --bs-primary: #667eea;
  --bs-secondary: #764ba2;
  --bs-success: #28a745;
  --bs-gradient: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.btn-primary {
  background: var(--bs-gradient);
  border: none;
}
```

### Component Customization
```typescript
// Custom Bootstrap component configuration
export const BOOTSTRAP_CONFIG = {
  theme: 'custom',
  primaryColor: '#667eea',
  secondaryColor: '#764ba2',
  enableAnimations: true,
  mobileFirst: true,
  darkMode: 'auto'
};
```

## 📱 **Mobile & Responsive Features**

### Responsive Breakpoints
- **xs**: < 576px (phones)
- **sm**: ≥ 576px (landscape phones)
- **md**: ≥ 768px (tablets)
- **lg**: ≥ 992px (desktops)
- **xl**: ≥ 1200px (large desktops)

### Mobile Optimizations
```nginx
# Nginx mobile optimizations
location ~* \.(css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    add_header Vary "Accept-Encoding";
}

# Touch-friendly configurations
add_header X-UA-Compatible "IE=edge";
add_header X-Mobile-Optimized "width";
```

## 🔒 **Security Configuration**

### Container Security
```yaml
# Security-hardened container configuration
security_opt:
  - no-new-privileges:true
read_only: true
tmpfs:
  - /tmp
  - /var/run
user: "1001:1001"
```

### Network Security
```yaml
networks:
  stock-prediction-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### Nginx Security Headers
```nginx
# Security headers for Bootstrap frontend
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Content-Security-Policy "default-src 'self' 'unsafe-inline'" always;
```

## 📈 **Performance Optimization**

### Frontend Performance
```nginx
# Gzip compression for Bootstrap assets
gzip on;
gzip_types
    text/css
    application/javascript
    application/json
    font/woff
    font/woff2;

# Browser caching
location ~* \.(css|js|woff|woff2)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

### Backend Performance
```yaml
# Go backend optimization
environment:
  - GOMAXPROCS=4
  - GOGC=100
  - GOMEMLIMIT=1GiB
```

### Database Performance
```yaml
# Redis caching (optional)
redis:
  image: redis:7.2-alpine
  command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
```

## 🧪 **Testing & Validation**

### Automated Testing
```bash
# Run all tests
./test_bootstrap_frontend.sh

# Performance testing
./performance_test_bootstrap.sh

# Load testing
docker run --rm -i loadimpact/k6 run - <test-script.js
```

### Manual Testing Checklist
- [ ] Frontend loads at http://localhost:8080
- [ ] Bootstrap components render correctly
- [ ] Mobile responsiveness works
- [ ] API endpoints respond correctly
- [ ] Monitoring dashboards accessible
- [ ] Persistent data survives container restart

### Browser Testing
```bash
# Test different browsers (if available)
google-chrome http://localhost:8080
firefox http://localhost:8080
safari http://localhost:8080
```

## 🔧 **Troubleshooting**

### Common Issues

#### Frontend Not Loading
```bash
# Check container status
docker-compose ps frontend

# Check logs
docker-compose logs frontend

# Verify Bootstrap integration
docker-compose exec frontend find /usr/share/nginx/html -name "*.css" -exec grep -l "bootstrap" {} \;
```

#### API Connection Issues
```bash
# Test backend connectivity
curl http://localhost:8081/api/v1/health

# Check CORS configuration
curl -H "Origin: http://localhost:8080" http://localhost:8081/api/v1/health

# Verify environment variables
docker-compose exec stock-prediction env | grep CORS
```

#### Performance Issues
```bash
# Check resource usage
docker stats

# Monitor response times
curl -w "@curl-format.txt" -o /dev/null -s http://localhost:8080

# Check nginx access logs
docker-compose logs frontend | grep "GET /"
```

### Debug Mode
```bash
# Enable debug logging
export LOG_LEVEL=debug
docker-compose up -d

# Enable verbose nginx logging
# Edit nginx.conf and set error_log debug
```

## 📊 **Monitoring & Observability**

### Grafana Dashboards
Access Grafana at http://localhost:3000 (admin/admin)

**Available Dashboards:**
- **Bootstrap Frontend Metrics**: Page load times, user interactions
- **API Performance**: Response times, error rates
- **System Resources**: CPU, memory, disk usage
- **Business Metrics**: Prediction accuracy, user engagement

### Prometheus Metrics
Access Prometheus at http://localhost:9090

**Key Metrics:**
- `http_requests_total`: Total HTTP requests
- `http_request_duration_seconds`: Request duration
- `bootstrap_page_load_time`: Frontend load times
- `api_prediction_accuracy`: ML model accuracy

### Custom Metrics
```go
// Add custom metrics in Go backend
var (
    bootstrapPageViews = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "bootstrap_page_views_total",
            Help: "Total page views on Bootstrap frontend",
        },
        []string{"page", "device_type"},
    )
)
```

## 🚀 **Production Deployment**

### Production Checklist
- [ ] SSL/TLS certificates configured
- [ ] Environment variables secured
- [ ] Resource limits set
- [ ] Backup strategy implemented
- [ ] Monitoring alerts configured
- [ ] Security scanning completed
- [ ] Performance benchmarks met

### Production Configuration
```yaml
# docker-compose.prod.yml
version: '3.8'
services:
  frontend:
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
```

### SSL Configuration
```nginx
# HTTPS configuration for production
server {
    listen 443 ssl http2;
    ssl_certificate /etc/ssl/certs/cert.pem;
    ssl_certificate_key /etc/ssl/private/key.pem;
    
    # Include Bootstrap-optimized locations
    include /etc/nginx/conf.d/bootstrap-locations.conf;
}
```

## 📞 **Support & Resources**

### Documentation Links
- **Bootstrap Documentation**: https://getbootstrap.com/docs/5.3/
- **Bootstrap Icons**: https://icons.getbootstrap.com/
- **Angular Bootstrap**: https://ng-bootstrap.github.io/
- **Docker Best Practices**: https://docs.docker.com/develop/best-practices/

### Community Support
- **GitHub Issues**: https://github.com/andy7ps/us_stock_prediction/issues
- **Bootstrap Community**: https://github.com/twbs/bootstrap/discussions
- **Docker Community**: https://forums.docker.com/

### Professional Support
- **Email**: andy7ps@eland.idv.tw
- **Documentation**: Complete guides in `/docs` directory
- **Training**: Available upon request

---

## 🎉 **Conclusion**

The Bootstrap-enhanced Docker deployment provides a professional, scalable, and maintainable solution for the Stock Prediction Service. With comprehensive monitoring, security features, and mobile-first design, it's ready for production use.

**Key Benefits:**
- ✨ Professional Bootstrap 5.3.3 UI
- 📱 Mobile-first responsive design
- 🔒 Enterprise-grade security
- 📊 Comprehensive monitoring
- 🚀 Production-ready deployment
- 🛠️ Easy maintenance and updates

**Ready to deploy!** Run `./deploy_docker_bootstrap.sh` to get started.

---

*Last updated: August 5, 2025*  
*Bootstrap Version: 5.3.3*  
*Docker Compose Version: 3.8*
