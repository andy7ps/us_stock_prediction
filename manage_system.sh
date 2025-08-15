#!/bin/bash

# System Management Script for Stock Prediction System v3.4.0
# Provides easy management of Docker services

set -e

# Version
SERVICE_VERSION="v3.4.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}[MANAGE]${NC} $1"
}

print_feature() {
    echo -e "${CYAN}  ✨${NC} $1"
}

# Configuration
COMPOSE_FILE="docker-compose-production.yml"
PROJECT_NAME="stock-prediction-prod"

show_help() {
    echo "Stock Prediction System Management Script v3.2.0"
    echo "================================================"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  start           Start all services"
    echo "  stop            Stop all services"
    echo "  restart         Restart all services"
    echo "  status          Show service status"
    echo "  logs            Show logs for all services"
    echo "  logs [service]  Show logs for specific service"
    echo "  health          Check health of all services"
    echo "  shell [service] Open shell in service container"
    echo "  rebuild         Rebuild and restart all services"
    echo "  cleanup         Clean up unused Docker resources"
    echo "  backup          Create backup of persistent data"
    echo "  restore [file]  Restore from backup file"
    echo "  update          Update system to latest version"
    echo "  monitor         Show real-time resource usage"
    echo "  test            Run comprehensive system tests"
    echo "  info            Show system information"
    echo ""
    echo "Services:"
    echo "  frontend        Angular frontend with Bootstrap 5.3.3"
    echo "  stock-prediction Go backend API with ML predictions"
    echo "  redis           Redis cache for high performance"
    echo "  prometheus      Prometheus metrics collection"
    echo "  grafana         Grafana dashboards and visualization"
    echo ""
    echo "Options:"
    echo "  --dev           Use development configuration"
    echo "  --verbose       Enable verbose output"
    echo "  --force         Force operation without confirmation"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start                    # Start all services"
    echo "  $0 logs frontend            # Show frontend logs"
    echo "  $0 shell stock-prediction   # Open shell in backend"
    echo "  $0 restart --dev           # Restart in dev mode"
    echo "  $0 backup                   # Create system backup"
    echo "  $0 monitor                  # Monitor resource usage"
    echo ""
    echo "Service URLs:"
    echo "  Frontend:  http://localhost:8080"
    echo "  Backend:   http://localhost:8081"
    echo "  Grafana:   http://localhost:3000 (admin/admin)"
    echo "  Prometheus: http://localhost:9090"
}

# Parse options
VERBOSE="false"
DEV_MODE="false"
FORCE="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --dev)
            DEV_MODE="true"
            COMPOSE_FILE="docker-compose.yml"
            PROJECT_NAME="stock-prediction-dev"
            shift
            ;;
        --verbose)
            VERBOSE="true"
            shift
            ;;
        --force)
            FORCE="true"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

COMMAND=$1
SERVICE=$2

if [ -z "$COMMAND" ]; then
    show_help
    exit 1
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed or not in PATH"
    exit 1
fi

# Check if compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    print_error "Docker Compose file not found: $COMPOSE_FILE"
    exit 1
fi

case $COMMAND in
    start)
        print_header "Starting Stock Prediction System"
        if [ "$DEV_MODE" = "true" ]; then
            print_status "Using development configuration"
        else
            print_status "Using production configuration"
        fi
        
        print_status "Starting services..."
        docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME up -d
        
        print_success "System started successfully"
        
        print_status "Waiting for services to be ready..."
        sleep 15
        
        print_header "Service Status:"
        docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME ps
        
        echo ""
        print_header "🌐 Access Points:"
        print_feature "Frontend:  http://localhost:8080"
        print_feature "Backend:   http://localhost:8081"
        print_feature "Grafana:   http://localhost:3000 (admin/admin)"
        print_feature "Prometheus: http://localhost:9090"
        ;;
        
    stop)
        print_header "Stopping Stock Prediction System"
        
        if [ "$FORCE" != "true" ]; then
            echo "This will stop all running services. Continue? (y/N)"
            read -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_status "Operation cancelled"
                exit 0
            fi
        fi
        
        docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME down
        print_success "System stopped successfully"
        ;;
        
    restart)
        print_header "Restarting Stock Prediction System"
        
        if [ -n "$SERVICE" ]; then
            print_status "Restarting service: $SERVICE"
            docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME restart $SERVICE
        else
            print_status "Restarting all services"
            docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME restart
        fi
        
        print_success "System restarted successfully"
        
        print_status "Waiting for services to be ready..."
        sleep 10
        
        print_header "Service Status:"
        docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME ps
        ;;
        
    status)
        print_header "Stock Prediction System Status"
        docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME ps
        
        echo ""
        print_header "Service Health Checks:"
        
        # Check backend
        if curl -s http://localhost:8081/api/v1/health > /dev/null 2>&1; then
            print_success "Backend API: Healthy ✅"
        else
            print_error "Backend API: Unhealthy ❌"
        fi
        
        # Check frontend
        if curl -s http://localhost:8080/health > /dev/null 2>&1; then
            print_success "Frontend: Healthy ✅"
        else
            print_error "Frontend: Unhealthy ❌"
        fi
        
        # Check Prometheus
        if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
            print_success "Prometheus: Healthy ✅"
        else
            print_error "Prometheus: Unhealthy ❌"
        fi
        
        # Check Grafana
        if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
            print_success "Grafana: Healthy ✅"
        else
            print_error "Grafana: Unhealthy ❌"
        fi
        
        # Check Redis
        if docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME exec -T redis redis-cli -a stockprediction2025 ping > /dev/null 2>&1; then
            print_success "Redis: Healthy ✅"
        else
            print_error "Redis: Unhealthy ❌"
        fi
        ;;
        
    logs)
        if [ -n "$SERVICE" ]; then
            print_header "Showing logs for $SERVICE"
            docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME logs -f --tail=100 $SERVICE
        else
            print_header "Showing logs for all services"
            docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME logs -f --tail=50
        fi
        ;;
        
    health)
        print_header "Comprehensive Health Check"
        
        echo ""
        print_status "Backend Health:"
        if curl -s http://localhost:8081/api/v1/health > /dev/null 2>&1; then
            curl -s http://localhost:8081/api/v1/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8081/api/v1/health
        else
            print_error "Backend is not responding"
        fi
        
        echo ""
        print_status "Sample Prediction Test:"
        if curl -s http://localhost:8081/api/v1/predict/NVDA > /dev/null 2>&1; then
            curl -s http://localhost:8081/api/v1/predict/NVDA | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8081/api/v1/predict/NVDA
        else
            print_error "Prediction API is not responding"
        fi
        
        echo ""
        print_status "Service Statistics:"
        if curl -s http://localhost:8081/api/v1/stats > /dev/null 2>&1; then
            curl -s http://localhost:8081/api/v1/stats | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8081/api/v1/stats
        else
            print_error "Stats API is not responding"
        fi
        ;;
        
    shell)
        if [ -z "$SERVICE" ]; then
            print_error "Please specify a service name"
            echo "Available services: frontend, stock-prediction, redis, prometheus, grafana"
            exit 1
        fi
        
        print_header "Opening shell in $SERVICE container"
        
        # Try bash first, then sh
        if docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME exec $SERVICE /bin/bash 2>/dev/null; then
            :
        elif docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME exec $SERVICE /bin/sh 2>/dev/null; then
            :
        else
            print_error "Could not open shell in $SERVICE container"
            exit 1
        fi
        ;;
        
    rebuild)
        print_header "Rebuilding Stock Prediction System"
        
        if [ "$FORCE" != "true" ]; then
            echo "This will rebuild all containers from scratch. Continue? (y/N)"
            read -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_status "Operation cancelled"
                exit 0
            fi
        fi
        
        print_status "Stopping services..."
        docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME down
        
        print_status "Rebuilding containers..."
        docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME build --no-cache
        
        print_status "Starting services..."
        docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME up -d
        
        print_success "System rebuilt and started successfully"
        ;;
        
    cleanup)
        print_header "Cleaning up Docker resources"
        
        if [ "$FORCE" != "true" ]; then
            echo "This will remove unused Docker resources. Continue? (y/N)"
            read -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_status "Operation cancelled"
                exit 0
            fi
        fi
        
        print_status "Removing unused containers..."
        docker container prune -f
        
        print_status "Removing unused images..."
        docker image prune -f
        
        print_status "Removing unused volumes..."
        docker volume prune -f
        
        print_status "Removing unused networks..."
        docker network prune -f
        
        print_success "Cleanup completed"
        
        echo ""
        print_status "Docker system usage after cleanup:"
        docker system df
        ;;
        
    backup)
        print_header "Creating system backup"
        
        BACKUP_DIR="./backups"
        BACKUP_FILE="stock_prediction_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        
        mkdir -p $BACKUP_DIR
        
        print_status "Creating backup: $BACKUP_FILE"
        print_status "This may take a few minutes..."
        
        tar -czf "$BACKUP_DIR/$BACKUP_FILE" \
            persistent_data/ \
            docker-compose*.yml \
            .env* \
            monitoring/ \
            nginx/ \
            scripts/ \
            --exclude=persistent_data/logs/* \
            --exclude=persistent_data/*/logs/* \
            --exclude=persistent_data/prometheus/wal/* \
            2>/dev/null || true
        
        BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
        print_success "Backup created: $BACKUP_DIR/$BACKUP_FILE ($BACKUP_SIZE)"
        
        echo ""
        print_status "Available backups:"
        ls -lh $BACKUP_DIR/*.tar.gz 2>/dev/null || echo "No previous backups found"
        ;;
        
    restore)
        if [ -z "$SERVICE" ]; then
            print_error "Please specify backup file"
            echo "Usage: $0 restore <backup_file>"
            echo ""
            print_status "Available backups:"
            ls -lh ./backups/*.tar.gz 2>/dev/null || echo "No backups found"
            exit 1
        fi
        
        BACKUP_FILE=$SERVICE
        
        if [ ! -f "$BACKUP_FILE" ]; then
            print_error "Backup file not found: $BACKUP_FILE"
            exit 1
        fi
        
        print_header "Restoring from backup: $BACKUP_FILE"
        print_warning "This will overwrite existing data. Continue? (y/N)"
        read -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Stopping services..."
            docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME down
            
            print_status "Backing up current data..."
            mv persistent_data persistent_data.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
            
            print_status "Restoring data..."
            tar -xzf "$BACKUP_FILE"
            
            print_status "Starting services..."
            docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME up -d
            
            print_success "Restore completed successfully"
        else
            print_status "Restore cancelled"
        fi
        ;;
        
    update)
        print_header "Updating Stock Prediction System"
        
        print_status "Pulling latest images..."
        docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME pull
        
        print_status "Rebuilding services..."
        docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME build --pull
        
        print_status "Restarting services..."
        docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME up -d
        
        print_success "Update completed successfully"
        
        print_status "Waiting for services to be ready..."
        sleep 15
        
        print_header "Updated Service Status:"
        docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME ps
        ;;
        
    monitor)
        print_header "Real-time Resource Monitoring"
        print_status "Press Ctrl+C to exit"
        echo ""
        
        docker stats --format "table {{.Container}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
        ;;
        
    test)
        print_header "Running comprehensive system tests"
        
        if [ -f "./test_docker_deployment.sh" ]; then
            ./test_docker_deployment.sh
        else
            print_error "Test script not found: ./test_docker_deployment.sh"
            exit 1
        fi
        ;;
        
    info)
        print_header "Stock Prediction System Information"
        
        echo ""
        print_status "System Configuration:"
        echo "  Compose File: $COMPOSE_FILE"
        echo "  Project Name: $PROJECT_NAME"
        echo "  Mode: $([ "$DEV_MODE" = "true" ] && echo "Development" || echo "Production")"
        
        echo ""
        print_status "Docker Information:"
        docker --version
        docker-compose --version
        
        echo ""
        print_status "System Resources:"
        docker system df
        
        echo ""
        print_status "Network Information:"
        docker network ls | grep stock-prediction || echo "No stock-prediction networks found"
        
        echo ""
        print_status "Volume Information:"
        docker volume ls | grep stock-prediction || echo "No stock-prediction volumes found"
        
        if [ "$VERBOSE" = "true" ]; then
            echo ""
            print_status "Container Details:"
            docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME ps
            
            echo ""
            print_status "Image Information:"
            docker images | grep -E "(stock-prediction|frontend|redis|prometheus|grafana)" || echo "No related images found"
        fi
        ;;
        
    *)
        print_error "Unknown command: $COMMAND"
        echo ""
        show_help
        exit 1
        ;;
esac
