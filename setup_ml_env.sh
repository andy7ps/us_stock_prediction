#!/bin/bash

# 🐍 ML Environment Setup Script
# Creates ml_env virtual environment with all required ML packages
# For deployment on other machines with identical environment

set -e

# Configuration
ML_ENV_DIR="ml_env"
PYTHON_VERSION="3.11"
LOG_FILE="setup_ml_env.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1" | tee -a "$LOG_FILE"
}

# Check system requirements
check_system() {
    log "🔍 Checking system requirements..."
    
    # Check Python version
    if ! command -v python3 &> /dev/null; then
        error "Python 3 is not installed. Please install Python 3.11 or higher."
        exit 1
    fi
    
    PYTHON_VER=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
    log "Found Python version: $PYTHON_VER"
    
    # Check if python3-venv is available
    if ! python3 -m venv --help &> /dev/null; then
        error "python3-venv is not available. Please install it:"
        echo "  Ubuntu/Debian: sudo apt-get install python3-venv"
        echo "  CentOS/RHEL: sudo yum install python3-venv"
        echo "  macOS: Should be included with Python"
        exit 1
    fi
    
    # Check pip
    if ! python3 -m pip --version &> /dev/null; then
        error "pip is not available. Please install python3-pip"
        exit 1
    fi
    
    success "System requirements check passed"
}

# Check available disk space
check_disk_space() {
    log "💾 Checking available disk space..."
    
    AVAILABLE_SPACE=$(df . | tail -1 | awk '{print $4}')
    REQUIRED_SPACE=3000000  # 3GB in KB
    
    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        warning "Low disk space detected. ML environment requires ~3GB."
        warning "Available: $(($AVAILABLE_SPACE / 1024 / 1024))GB, Required: ~3GB"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        success "Sufficient disk space available: $(($AVAILABLE_SPACE / 1024 / 1024))GB"
    fi
}

# Remove existing ml_env if it exists
cleanup_existing() {
    if [ -d "$ML_ENV_DIR" ]; then
        warning "Existing ml_env directory found"
        read -p "Remove existing ml_env and create fresh? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "🗑️ Removing existing ml_env directory..."
            rm -rf "$ML_ENV_DIR"
            success "Existing ml_env removed"
        else
            error "Cannot proceed with existing ml_env directory"
            exit 1
        fi
    fi
}

# Create virtual environment
create_venv() {
    log "🐍 Creating Python virtual environment: $ML_ENV_DIR"
    
    if python3 -m venv "$ML_ENV_DIR"; then
        success "Virtual environment created successfully"
    else
        error "Failed to create virtual environment"
        exit 1
    fi
    
    # Verify virtual environment
    if [ ! -f "$ML_ENV_DIR/bin/activate" ]; then
        error "Virtual environment activation script not found"
        exit 1
    fi
    
    success "Virtual environment verification passed"
}

# Upgrade pip in virtual environment
upgrade_pip() {
    log "📦 Upgrading pip in virtual environment..."
    
    source "$ML_ENV_DIR/bin/activate"
    
    if pip install --upgrade pip; then
        success "Pip upgraded successfully"
    else
        error "Failed to upgrade pip"
        exit 1
    fi
    
    deactivate
}

# Install ML packages
install_ml_packages() {
    log "🤖 Installing ML packages (this may take 10-15 minutes)..."
    
    source "$ML_ENV_DIR/bin/activate"
    
    # Core ML packages with specific versions for compatibility
    local packages=(
        "numpy==1.24.3"
        "pandas==2.0.3"
        "scikit-learn==1.3.0"
        "joblib==1.3.2"
        "tensorflow==2.15.0"
        "keras==2.15.0"
        "yfinance==0.2.18"
        "requests==2.31.0"
        "xgboost==2.0.0"
        "lightgbm==4.1.0"
        "matplotlib==3.8.0"
        "seaborn==0.13.0"
        "plotly==5.17.0"
        "numba==0.58.0"
        "tqdm==4.66.0"
        "peewee==3.16.3"
        "websockets==11.0.3"
        "markdown==3.5.1"
        "pygments==2.16.1"
        "fonttools==4.43.1"
    )
    
    local total=${#packages[@]}
    local current=0
    
    for package in "${packages[@]}"; do
        current=$((current + 1))
        info "Installing package $current/$total: $package"
        
        if pip install --no-cache-dir "$package"; then
            success "✅ Installed: $package"
        else
            error "❌ Failed to install: $package"
            deactivate
            exit 1
        fi
    done
    
    deactivate
    success "All ML packages installed successfully"
}

# Verify installation
verify_installation() {
    log "🔍 Verifying ML environment installation..."
    
    source "$ML_ENV_DIR/bin/activate"
    
    # Test critical imports
    local test_script="
import sys
print(f'Python version: {sys.version}')
print('Testing package imports...')

try:
    import numpy as np
    print(f'✅ NumPy: {np.__version__}')
except ImportError as e:
    print(f'❌ NumPy: {e}')
    sys.exit(1)

try:
    import pandas as pd
    print(f'✅ Pandas: {pd.__version__}')
except ImportError as e:
    print(f'❌ Pandas: {e}')
    sys.exit(1)

try:
    import sklearn
    print(f'✅ Scikit-learn: {sklearn.__version__}')
except ImportError as e:
    print(f'❌ Scikit-learn: {e}')
    sys.exit(1)

try:
    import tensorflow as tf
    print(f'✅ TensorFlow: {tf.__version__}')
except ImportError as e:
    print(f'❌ TensorFlow: {e}')
    sys.exit(1)

try:
    import yfinance as yf
    print(f'✅ yfinance: {yf.__version__}')
except ImportError as e:
    print(f'❌ yfinance: {e}')
    sys.exit(1)

try:
    import joblib
    print(f'✅ Joblib: {joblib.__version__}')
except ImportError as e:
    print(f'❌ Joblib: {e}')
    sys.exit(1)

print('🎉 All critical packages imported successfully!')
"
    
    if python3 -c "$test_script"; then
        success "Package verification passed"
    else
        error "Package verification failed"
        deactivate
        exit 1
    fi
    
    deactivate
}

# Create activation helper script
create_activation_script() {
    log "📝 Creating activation helper script..."
    
    cat > "activate_ml_env.sh" << 'EOF'
#!/bin/bash

# 🐍 ML Environment Activation Script
# Quick activation of ml_env virtual environment

if [ ! -d "ml_env" ]; then
    echo "❌ ml_env directory not found. Run setup_ml_env.sh first."
    exit 1
fi

if [ ! -f "ml_env/bin/activate" ]; then
    echo "❌ ml_env activation script not found. Run setup_ml_env.sh first."
    exit 1
fi

echo "🐍 Activating ML environment..."
source ml_env/bin/activate

echo "✅ ML environment activated!"
echo "📊 Available packages:"
python3 -c "
import tensorflow as tf
import yfinance as yf
import sklearn
import pandas as pd
import numpy as np
print(f'  - TensorFlow: {tf.__version__}')
print(f'  - yfinance: {yf.__version__}')
print(f'  - scikit-learn: {sklearn.__version__}')
print(f'  - pandas: {pd.__version__}')
print(f'  - numpy: {np.__version__}')
"

echo ""
echo "🎯 Ready for ML training!"
echo "💡 To deactivate: type 'deactivate'"
echo "🚀 To run training: ./ml_env/bin/python3 scripts/ml/train_nvda_model.py"

# Keep shell active with ml_env
exec bash
EOF
    
    chmod +x "activate_ml_env.sh"
    success "Activation helper script created: activate_ml_env.sh"
}

# Create requirements.txt for future reference
create_requirements() {
    log "📋 Creating requirements.txt for future reference..."
    
    source "$ML_ENV_DIR/bin/activate"
    
    if pip freeze > requirements_ml_env.txt; then
        success "Requirements saved to requirements_ml_env.txt"
    else
        warning "Failed to create requirements.txt"
    fi
    
    deactivate
}

# Display usage instructions
show_usage() {
    echo ""
    echo "🎉 ML Environment Setup Complete!"
    echo "=================================="
    echo ""
    echo "📁 Environment Location: $(pwd)/$ML_ENV_DIR"
    echo "📊 Environment Size: $(du -sh $ML_ENV_DIR | cut -f1)"
    echo ""
    echo "🚀 Usage Instructions:"
    echo ""
    echo "1. Activate environment:"
    echo "   source $ML_ENV_DIR/bin/activate"
    echo "   # OR use helper script:"
    echo "   ./activate_ml_env.sh"
    echo ""
    echo "2. Run training scripts:"
    echo "   ./$ML_ENV_DIR/bin/python3 scripts/ml/train_nvda_model.py"
    echo "   ./$ML_ENV_DIR/bin/python3 scripts/ml/train_tsla_model.py"
    echo ""
    echo "3. Deactivate environment:"
    echo "   deactivate"
    echo ""
    echo "📋 Files Created:"
    echo "   - $ML_ENV_DIR/                 # Virtual environment"
    echo "   - activate_ml_env.sh           # Activation helper"
    echo "   - requirements_ml_env.txt      # Package list"
    echo "   - setup_ml_env.log             # Setup log"
    echo ""
    echo "🔄 To recreate on another machine:"
    echo "   1. Copy this script (setup_ml_env.sh)"
    echo "   2. Run: ./setup_ml_env.sh"
    echo "   3. Copy your training scripts to scripts/ml/"
    echo ""
    echo "💡 Note: For Docker deployment, virtual environment is not needed."
    echo "   Docker containers provide complete isolation."
}

# Main execution
main() {
    echo "🐍 ML Environment Setup Script"
    echo "=============================="
    echo ""
    echo "This script will create a complete ML environment with:"
    echo "  - Python virtual environment (ml_env)"
    echo "  - TensorFlow, scikit-learn, yfinance"
    echo "  - All required ML packages"
    echo "  - Activation helper scripts"
    echo ""
    
    # Initialize log
    echo "ML Environment Setup Log - $(date)" > "$LOG_FILE"
    
    # System checks
    check_system
    check_disk_space
    cleanup_existing
    
    # Environment setup
    create_venv
    upgrade_pip
    install_ml_packages
    
    # Verification and helpers
    verify_installation
    create_activation_script
    create_requirements
    
    # Success
    success "ML environment setup completed successfully!"
    show_usage
}

# Handle script arguments
case "${1:-setup}" in
    "setup"|"install")
        main
        ;;
    "verify")
        if [ ! -d "$ML_ENV_DIR" ]; then
            error "ml_env directory not found. Run setup first."
            exit 1
        fi
        verify_installation
        ;;
    "clean")
        if [ -d "$ML_ENV_DIR" ]; then
            log "🗑️ Removing ml_env directory..."
            rm -rf "$ML_ENV_DIR"
            rm -f "activate_ml_env.sh" "requirements_ml_env.txt" "setup_ml_env.log"
            success "ML environment cleaned up"
        else
            info "No ml_env directory found"
        fi
        ;;
    "help"|*)
        echo "🐍 ML Environment Setup Script"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  setup     - Create complete ML environment (default)"
        echo "  install   - Same as setup"
        echo "  verify    - Verify existing ML environment"
        echo "  clean     - Remove ML environment and helper files"
        echo "  help      - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                # Create ML environment"
        echo "  $0 setup          # Create ML environment"
        echo "  $0 verify         # Test existing environment"
        echo "  $0 clean          # Remove environment"
        exit 0
        ;;
esac
