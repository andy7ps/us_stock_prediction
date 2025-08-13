#!/bin/bash

# Setup Cron Jobs for ML Stock Prediction - Persistent Data Edition
# ALL jobs use persistent_data/ directory structure

set -e

# PERSISTENT DATA PATHS - MANDATORY
PERSISTENT_DATA_DIR="./persistent_data"
LOG_DIR="$PERSISTENT_DATA_DIR/logs"
TRAINING_LOG_DIR="$LOG_DIR/training"
MONITORING_LOG_DIR="$LOG_DIR/monitoring"
CLEANUP_LOG_DIR="$LOG_DIR/cleanup"

# Ensure persistent data structure exists
if [ ! -d "$PERSISTENT_DATA_DIR" ]; then
    echo "🚨 ERROR: persistent_data directory not found!"
    echo "Run: ./setup_persistent_data.sh"
    exit 1
fi

# Create required log directories
mkdir -p "$TRAINING_LOG_DIR" "$MONITORING_LOG_DIR" "$CLEANUP_LOG_DIR"

# Get absolute path for cron jobs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🕐 Setting up Cron Jobs for ML Stock Prediction - Persistent Data Edition"
echo "========================================================================"
echo "Script directory: $SCRIPT_DIR"
echo "Persistent data directory: $PERSISTENT_DATA_DIR"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

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

print_critical() {
    echo -e "${PURPLE}[CRITICAL]${NC} $1"
}

# Create cron job entries with persistent data paths
create_cron_jobs() {
    print_status "Creating cron job entries with persistent data integration..."
    
    # Create temporary cron file
    local temp_cron_file="/tmp/ml_stock_prediction_cron_$(date +%s)"
    
    # Get current cron jobs (excluding our ML jobs)
    crontab -l 2>/dev/null | grep -v "# ML Stock Prediction Automatic Jobs" | grep -v "enhanced_training.sh" | grep -v "monitor_performance.sh" | grep -v "manage_ml_models.sh" > "$temp_cron_file" || true
    
    # Add header comment
    echo "" >> "$temp_cron_file"
    echo "# ML Stock Prediction Automatic Jobs - Persistent Data Edition" >> "$temp_cron_file"
    echo "# Generated on $(date)" >> "$temp_cron_file"
    echo "# All jobs use persistent_data/ directory structure" >> "$temp_cron_file"
    
    # Weekly comprehensive training (Sundays at 2 AM)
    echo "0 2 * * 0 cd $SCRIPT_DIR && ./enhanced_training.sh >> $TRAINING_LOG_DIR/weekly.log 2>&1" >> "$temp_cron_file"
    
    # Performance monitoring (Every 6 hours on weekdays)
    echo "0 6,12,18 * * 1-5 cd $SCRIPT_DIR && ./monitor_performance.sh >> $MONITORING_LOG_DIR/performance.log 2>&1" >> "$temp_cron_file"
    
    # Monthly comprehensive training (1st of each month at 1 AM)
    echo "0 1 1 * * cd $SCRIPT_DIR && ./enhanced_training.sh --force >> $TRAINING_LOG_DIR/monthly.log 2>&1" >> "$temp_cron_file"
    
    # Daily cleanup (Every day at 3 AM)
    echo "0 3 * * * cd $SCRIPT_DIR && ./manage_ml_models.sh clean >> $CLEANUP_LOG_DIR/daily.log 2>&1" >> "$temp_cron_file"
    
    # Backup models (Every day at 4 AM)
    echo "0 4 * * * cd $SCRIPT_DIR && ./manage_ml_models.sh backup >> $CLEANUP_LOG_DIR/backup.log 2>&1" >> "$temp_cron_file"
    
    # Monitor disk usage for persistent data (Every 2 hours)
    echo "0 */2 * * * cd $SCRIPT_DIR && du -sh $PERSISTENT_DATA_DIR >> $MONITORING_LOG_DIR/disk_usage.log 2>&1" >> "$temp_cron_file"
    
    # Install the new cron jobs
    crontab "$temp_cron_file"
    
    # Clean up temporary file
    rm "$temp_cron_file"
    
    print_success "Cron jobs installed successfully"
}

# Verify cron jobs
verify_cron_jobs() {
    print_status "Verifying installed cron jobs..."
    
    echo ""
    echo "📋 Current Cron Jobs:"
    echo "===================="
    crontab -l | grep -A 20 "ML Stock Prediction" || print_warning "No ML cron jobs found"
    echo ""
}

# Test cron job scripts
test_scripts() {
    print_status "Testing cron job scripts with persistent data..."
    
    # Test enhanced training script
    if [ -f "$SCRIPT_DIR/enhanced_training.sh" ]; then
        if [ -x "$SCRIPT_DIR/enhanced_training.sh" ]; then
            print_success "enhanced_training.sh is executable"
        else
            print_error "enhanced_training.sh is not executable"
            chmod +x "$SCRIPT_DIR/enhanced_training.sh"
            print_success "Made enhanced_training.sh executable"
        fi
    else
        print_error "enhanced_training.sh not found"
    fi
    
    # Test monitoring script
    if [ -f "$SCRIPT_DIR/monitor_performance.sh" ]; then
        if [ -x "$SCRIPT_DIR/monitor_performance.sh" ]; then
            print_success "monitor_performance.sh is executable"
        else
            print_error "monitor_performance.sh is not executable"
            chmod +x "$SCRIPT_DIR/monitor_performance.sh"
            print_success "Made monitor_performance.sh executable"
        fi
    else
        print_error "monitor_performance.sh not found"
    fi
    
    # Test model management script
    if [ -f "$SCRIPT_DIR/manage_ml_models.sh" ]; then
        if [ -x "$SCRIPT_DIR/manage_ml_models.sh" ]; then
            print_success "manage_ml_models.sh is executable"
        else
            print_error "manage_ml_models.sh is not executable"
            chmod +x "$SCRIPT_DIR/manage_ml_models.sh"
            print_success "Made manage_ml_models.sh executable"
        fi
    else
        print_error "manage_ml_models.sh not found"
    fi
    
    # Test persistent data directory access
    if [ -w "$PERSISTENT_DATA_DIR" ]; then
        print_success "Persistent data directory is writable"
    else
        print_error "Persistent data directory is not writable: $PERSISTENT_DATA_DIR"
    fi
}

# Create monitoring dashboard script
create_dashboard() {
    print_status "Creating monitoring dashboard script..."
    
    cat > "$SCRIPT_DIR/dashboard.sh" << 'EOF'
#!/bin/bash

# ML Stock Prediction Dashboard - Persistent Data Edition

PERSISTENT_DATA_DIR="./persistent_data"
LOG_DIR="$PERSISTENT_DATA_DIR/logs"

echo "🎯 ML Stock Prediction System Dashboard - Persistent Data Edition"
echo "================================================================="
echo "Timestamp: $(date)"
echo "Persistent Data Directory: $PERSISTENT_DATA_DIR"
echo ""

# System status
echo "📊 System Status:"
echo "=================="
if [ -d "$PERSISTENT_DATA_DIR" ]; then
    echo "✅ Persistent data directory: $(du -sh $PERSISTENT_DATA_DIR | cut -f1)"
else
    echo "❌ Persistent data directory missing"
fi

# Model status
echo ""
echo "🧠 ML Models:"
echo "============="
if [ -d "$PERSISTENT_DATA_DIR/ml_models" ]; then
    find "$PERSISTENT_DATA_DIR/ml_models" -name "*.h5" -exec basename {} \; | sort
else
    echo "❌ No models directory found"
fi

# Recent logs
echo ""
echo "📝 Recent Activity:"
echo "==================="
if [ -f "$LOG_DIR/training/training.log" ]; then
    echo "Last training activity:"
    tail -3 "$LOG_DIR/training/training.log" 2>/dev/null || echo "No training logs"
fi

if [ -f "$LOG_DIR/monitoring/performance.log" ]; then
    echo ""
    echo "Last monitoring activity:"
    tail -3 "$LOG_DIR/monitoring/performance.log" 2>/dev/null || echo "No monitoring logs"
fi

# Disk usage
echo ""
echo "💾 Storage Usage:"
echo "=================="
df -h "$PERSISTENT_DATA_DIR" | tail -1

echo ""
echo "🔄 Cron Jobs Status:"
echo "===================="
crontab -l | grep -A 10 "ML Stock Prediction" || echo "No cron jobs found"
EOF
    
    chmod +x "$SCRIPT_DIR/dashboard.sh"
    print_success "Dashboard script created: $SCRIPT_DIR/dashboard.sh"
}

# Main setup function
main() {
    print_critical "=== Setting up Cron Jobs - Persistent Data Edition ==="
    print_status "Persistent data directory: $PERSISTENT_DATA_DIR"
    print_status "Script directory: $SCRIPT_DIR"
    
    # Test scripts first
    test_scripts
    
    # Create cron jobs
    create_cron_jobs
    
    # Verify installation
    verify_cron_jobs
    
    # Create dashboard
    create_dashboard
    
    print_success "=== Cron job setup completed ==="
    
    echo ""
    echo "📋 Scheduled Jobs (Persistent Data Edition):"
    echo "============================================="
    echo "🕐 Weekly Training:     Sundays at 2:00 AM"
    echo "🕐 Performance Monitor: Every 6 hours (weekdays)"
    echo "🕐 Monthly Training:    1st of month at 1:00 AM"
    echo "🕐 Daily Cleanup:       Every day at 3:00 AM"
    echo "🕐 Daily Backup:        Every day at 4:00 AM"
    echo "🕐 Disk Monitor:        Every 2 hours"
    echo ""
    echo "📁 All logs stored in: $LOG_DIR"
    echo "📊 View dashboard: ./dashboard.sh"
    echo ""
    print_critical "🔥 IMPORTANT: All jobs use persistent_data/ directory structure"
    print_warning "Ensure persistent_data/ directory is never deleted!"
}

# Run main function
main "$@"
