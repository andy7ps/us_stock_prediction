#!/bin/bash

# Cron Jobs Setup Script
# Sets up automatic training and monitoring schedules

set -e

PROJECT_DIR="$(pwd)"
USER=$(whoami)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create cron job entries
create_cron_entries() {
    local temp_cron=$(mktemp)
    
    # Get existing crontab (if any)
    crontab -l 2>/dev/null > "$temp_cron" || true
    
    # Remove any existing ML training jobs
    grep -v "enhanced_training.sh\|monitor_performance.sh" "$temp_cron" > "${temp_cron}.clean" || true
    mv "${temp_cron}.clean" "$temp_cron"
    
    log_info "Adding new cron jobs..."
    
    # Add header comment
    echo "" >> "$temp_cron"
    echo "# ML Stock Prediction Automatic Jobs" >> "$temp_cron"
    echo "# Generated on $(date)" >> "$temp_cron"
    
    # Weekly training (Sunday 2 AM)
    echo "0 2 * * 0 cd $PROJECT_DIR && ./enhanced_training.sh >> logs/training/cron.log 2>&1" >> "$temp_cron"
    
    # Daily performance monitoring (every 6 hours during market days)
    echo "0 6,12,18 * * 1-5 cd $PROJECT_DIR && ./monitor_performance.sh >> logs/monitoring/cron.log 2>&1" >> "$temp_cron"
    
    # Monthly comprehensive training (1st of month, 1 AM)
    echo "0 1 1 * * cd $PROJECT_DIR && ./enhanced_training.sh --force >> logs/training/monthly.log 2>&1" >> "$temp_cron"
    
    # Daily cleanup (3 AM)
    echo "0 3 * * * cd $PROJECT_DIR && ./manage_ml_models.sh clean >> logs/cleanup.log 2>&1" >> "$temp_cron"
    
    # Install the new crontab
    crontab "$temp_cron"
    rm "$temp_cron"
    
    log_success "Cron jobs installed successfully"
}

# Create log directories
setup_log_directories() {
    log_info "Setting up log directories..."
    
    mkdir -p logs/training
    mkdir -p logs/monitoring
    mkdir -p logs/cron
    
    # Create log rotation configuration
    cat > logs/logrotate.conf << EOF
$PROJECT_DIR/logs/training/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 $USER $USER
}

$PROJECT_DIR/logs/monitoring/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 $USER $USER
}
EOF
    
    log_success "Log directories and rotation configured"
}

# Create systemd service (alternative to cron)
create_systemd_service() {
    local service_dir="$HOME/.config/systemd/user"
    mkdir -p "$service_dir"
    
    # Training service
    cat > "$service_dir/ml-training.service" << EOF
[Unit]
Description=ML Stock Prediction Training
After=network.target

[Service]
Type=oneshot
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/enhanced_training.sh
User=$USER
StandardOutput=append:$PROJECT_DIR/logs/training/systemd.log
StandardError=append:$PROJECT_DIR/logs/training/systemd.log

[Install]
WantedBy=default.target
EOF

    # Training timer (weekly)
    cat > "$service_dir/ml-training.timer" << EOF
[Unit]
Description=Run ML Training Weekly
Requires=ml-training.service

[Timer]
OnCalendar=Sun 02:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Monitoring service
    cat > "$service_dir/ml-monitoring.service" << EOF
[Unit]
Description=ML Performance Monitoring
After=network.target

[Service]
Type=oneshot
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/monitor_performance.sh
User=$USER
StandardOutput=append:$PROJECT_DIR/logs/monitoring/systemd.log
StandardError=append:$PROJECT_DIR/logs/monitoring/systemd.log

[Install]
WantedBy=default.target
EOF

    # Monitoring timer (every 6 hours on weekdays)
    cat > "$service_dir/ml-monitoring.timer" << EOF
[Unit]
Description=Run ML Monitoring Every 6 Hours
Requires=ml-monitoring.service

[Timer]
OnCalendar=Mon..Fri 06,12,18:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    log_success "Systemd services created in $service_dir"
    log_info "To enable systemd timers, run:"
    log_info "  systemctl --user daemon-reload"
    log_info "  systemctl --user enable ml-training.timer"
    log_info "  systemctl --user enable ml-monitoring.timer"
    log_info "  systemctl --user start ml-training.timer"
    log_info "  systemctl --user start ml-monitoring.timer"
}

# Create monitoring dashboard script
create_dashboard() {
    cat > dashboard.sh << 'EOF'
#!/bin/bash

# Simple monitoring dashboard

echo "=== ML Stock Prediction Dashboard ==="
echo "Generated: $(date)"
echo

echo "=== Model Status ==="
./manage_ml_models.sh status | grep -E "(✅|❌)"
echo

echo "=== Recent Training Logs ==="
if [ -f "logs/training/training.log" ]; then
    tail -n 5 logs/training/training.log
else
    echo "No training logs found"
fi
echo

echo "=== Recent Performance ==="
if [ -f "logs/monitoring/performance_history.jsonl" ]; then
    echo "Last 3 performance checks:"
    tail -n 3 logs/monitoring/performance_history.jsonl | jq -r '"\(.timestamp) \(.symbol): \(.confidence) confidence"' 2>/dev/null || tail -n 3 logs/monitoring/performance_history.jsonl
else
    echo "No performance data found"
fi
echo

echo "=== System Health ==="
echo "Disk usage: $(df . | awk 'NR==2 {print $5}')"
echo "Memory usage: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
echo "Load average: $(uptime | awk -F'load average:' '{print $2}')"
echo

echo "=== Next Scheduled Jobs ==="
echo "Cron jobs:"
crontab -l 2>/dev/null | grep -E "(enhanced_training|monitor_performance)" || echo "No cron jobs found"
EOF

    chmod +x dashboard.sh
    log_success "Dashboard script created: ./dashboard.sh"
}

# Main setup function
main() {
    local setup_cron=true
    local setup_systemd=false
    local setup_dashboard=true
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-cron)
                setup_cron=false
                shift
                ;;
            --systemd)
                setup_systemd=true
                shift
                ;;
            --no-dashboard)
                setup_dashboard=false
                shift
                ;;
            --help)
                echo "Usage: $0 [--no-cron] [--systemd] [--no-dashboard]"
                echo "  --no-cron       Skip cron job setup"
                echo "  --systemd       Create systemd services (in addition to or instead of cron)"
                echo "  --no-dashboard  Skip dashboard creation"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    log_info "=== Setting up automatic ML training and monitoring ==="
    log_info "Project directory: $PROJECT_DIR"
    
    # Setup log directories
    setup_log_directories
    
    # Setup cron jobs
    if [ "$setup_cron" = true ]; then
        log_info "Setting up cron jobs..."
        create_cron_entries
        
        # Show installed cron jobs
        echo
        log_info "Installed cron jobs:"
        crontab -l | grep -E "(enhanced_training|monitor_performance|manage_ml_models)" || true
    fi
    
    # Setup systemd services
    if [ "$setup_systemd" = true ]; then
        log_info "Setting up systemd services..."
        create_systemd_service
    fi
    
    # Create dashboard
    if [ "$setup_dashboard" = true ]; then
        log_info "Creating monitoring dashboard..."
        create_dashboard
    fi
    
    echo
    log_success "=== Setup completed successfully! ==="
    echo
    log_info "Automatic schedules configured:"
    log_info "  📅 Weekly training: Sundays at 2:00 AM"
    log_info "  📊 Performance monitoring: Every 6 hours (weekdays)"
    log_info "  🔄 Monthly comprehensive training: 1st of month at 1:00 AM"
    log_info "  🧹 Daily cleanup: Every day at 3:00 AM"
    echo
    log_info "Manual commands available:"
    log_info "  ./enhanced_training.sh --force    # Force training now"
    log_info "  ./monitor_performance.sh          # Check performance now"
    log_info "  ./dashboard.sh                    # View dashboard"
    log_info "  ./manage_ml_models.sh status      # Check model status"
    echo
    log_info "Logs will be stored in:"
    log_info "  logs/training/     # Training logs"
    log_info "  logs/monitoring/   # Performance monitoring logs"
    echo
    log_warning "Note: Make sure your Go service is running for performance monitoring to work"
}

# Run main function with all arguments
main "$@"
