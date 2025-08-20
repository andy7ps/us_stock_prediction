#!/bin/bash

# 🐳 Docker-Based Model Training Script
# Trains ML models inside Docker containers with persistent data storage

set -e

# Configuration
COMPOSE_FILE="docker-compose.yml"
SERVICE_NAME="stock-prediction"
PERSISTENT_DATA_DIR="./persistent_data"
LOG_FILE="$PERSISTENT_DATA_DIR/logs/docker_training.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

# Create necessary directories
setup_directories() {
    log "🔄 Setting up persistent data directories..."
    
    mkdir -p "$PERSISTENT_DATA_DIR"/{ml_models,ml_cache,scalers,stock_data,logs,config,backups}
    mkdir -p "./database_data"
    
    # Create log file
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    
    log "✅ Directories created successfully"
}

# Check Docker setup
check_docker() {
    log "🔍 Checking Docker setup..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running"
        exit 1
    fi
    
    log "✅ Docker setup verified"
}

# Start Docker services
start_services() {
    log "🚀 Starting Docker services..."
    
    # Start only the backend service (no need for full stack during training)
    docker-compose up -d stock-prediction redis
    
    # Wait for services to be ready
    log "⏳ Waiting for services to be ready..."
    sleep 10
    
    # Check if service is running
    if ! docker-compose ps stock-prediction | grep -q "Up"; then
        error "Stock prediction service failed to start"
        docker-compose logs stock-prediction
        exit 1
    fi
    
    log "✅ Services started successfully"
}

# Train a specific symbol
train_symbol() {
    local symbol=$1
    local epochs=${2:-60}
    
    log "🤖 Training model for symbol: $symbol (epochs: $epochs)"
    
    # Execute training inside Docker container
    if docker-compose exec -T stock-prediction python3 "scripts/ml/train_${symbol,,}_model.py" 2>&1 | tee -a "$LOG_FILE"; then
        log "✅ Successfully trained $symbol model"
        return 0
    else
        error "Failed to train $symbol model"
        return 1
    fi
}

# Train multiple symbols
train_multiple() {
    local symbols=("$@")
    local success_count=0
    local total_count=${#symbols[@]}
    
    log "🎯 Starting training for ${total_count} symbols: ${symbols[*]}"
    
    for symbol in "${symbols[@]}"; do
        log "📊 Training $symbol..."
        if train_symbol "$symbol"; then
            ((success_count++))
        fi
    done
    
    log "📈 Training completed: $success_count/$total_count symbols successful"
    
    if [ $success_count -eq $total_count ]; then
        log "🎉 All models trained successfully!"
        return 0
    else
        warning "Some models failed to train. Check logs for details."
        return 1
    fi
}

# Verify trained models
verify_models() {
    log "🔍 Verifying trained models..."
    
    local model_count=$(find "$PERSISTENT_DATA_DIR/ml_models" -name "*.h5" 2>/dev/null | wc -l)
    local scaler_count=$(find "$PERSISTENT_DATA_DIR/ml_models" -name "*.pkl" 2>/dev/null | wc -l)
    
    log "📊 Found $model_count model files and $scaler_count scaler files"
    
    if [ $model_count -gt 0 ] && [ $scaler_count -gt 0 ]; then
        log "✅ Models verified successfully"
        
        # List trained models
        log "📋 Trained models:"
        find "$PERSISTENT_DATA_DIR/ml_models" -name "*.h5" -exec basename {} \; | sed 's/^/  - /' | tee -a "$LOG_FILE"
    else
        error "No trained models found"
        return 1
    fi
}

# Cleanup function
cleanup() {
    log "🧹 Cleaning up..."
    # Keep services running for API usage
    # docker-compose down
    log "✅ Cleanup completed (services kept running for API usage)"
}

# Main execution
main() {
    log "🐳 Docker Model Training Started"
    log "================================"
    
    # Setup
    setup_directories
    check_docker
    start_services
    
    # Parse command line arguments
    case "${1:-help}" in
        "single")
            if [ -z "$2" ]; then
                error "Symbol required for single training. Usage: $0 single NVDA"
                exit 1
            fi
            train_symbol "$2" "${3:-60}"
            ;;
        "phase2")
            log "🎯 Training Phase 2 symbols..."
            train_multiple "MSFT" "GOOGL" "AMZN" "SMR" "SPY"
            ;;
        "all")
            log "🎯 Training all supported symbols..."
            train_multiple "NVDA" "TSLA" "AAPL" "MSFT" "GOOGL" "AMZN" "AUR" "PLTR" "SMCI" "TSM" "MP" "SMR" "SPY"
            ;;
        "custom")
            shift
            if [ $# -eq 0 ]; then
                error "No symbols provided for custom training. Usage: $0 custom NVDA TSLA AAPL"
                exit 1
            fi
            train_multiple "$@"
            ;;
        "verify")
            verify_models
            ;;
        "help"|*)
            echo "🐳 Docker Model Training Script"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  single <symbol> [epochs]  - Train a single symbol (default: 60 epochs)"
            echo "  phase2                    - Train Phase 2 symbols (MSFT, GOOGL, AMZN, SMR, SPY)"
            echo "  all                       - Train all 13 supported symbols"
            echo "  custom <symbols...>       - Train custom list of symbols"
            echo "  verify                    - Verify trained models"
            echo "  help                      - Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 single NVDA 100       # Train NVDA with 100 epochs"
            echo "  $0 phase2                # Train Phase 2 symbols"
            echo "  $0 all                   # Train all symbols"
            echo "  $0 custom NVDA TSLA      # Train NVDA and TSLA"
            echo "  $0 verify                # Check trained models"
            exit 0
            ;;
    esac
    
    # Verify results
    verify_models
    
    # Cleanup
    cleanup
    
    log "🎉 Docker training completed successfully!"
}

# Trap for cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
