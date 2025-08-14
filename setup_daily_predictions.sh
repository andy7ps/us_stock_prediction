#!/bin/bash

# Setup Daily Predictions Cron Job
# Stock Prediction Service v3.4.0
# Author: Stock Prediction Service Development Team
# Created: 2024-08-14

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
CRON_TIME="${CRON_TIME:-0 1 * * *}"  # Default: 1:00 AM UTC (9:00 AM Taipei)
USER="${USER:-$(whoami)}"

echo "🕒 Setting up Daily Predictions Cron Job"
echo "========================================"

# Function to check if cron is installed
check_cron_installed() {
    if ! command -v crontab &> /dev/null; then
        echo "❌ Error: crontab command not found. Please install cron."
        exit 1
    fi
    echo "✅ Cron is installed"
}

# Function to backup existing crontab
backup_crontab() {
    local backup_file="$PROJECT_ROOT/logs/crontab_backup_$(date +%Y%m%d_%H%M%S).txt"
    mkdir -p "$PROJECT_ROOT/logs"
    
    if crontab -l > /dev/null 2>&1; then
        crontab -l > "$backup_file"
        echo "✅ Existing crontab backed up to: $backup_file"
    else
        echo "ℹ️  No existing crontab found"
    fi
}

# Function to add daily prediction cron job
add_cron_job() {
    local temp_cron=$(mktemp)
    local script_path="$PROJECT_ROOT/scripts/daily_prediction.sh"
    local log_path="$PROJECT_ROOT/logs/daily_prediction_cron.log"
    
    # Get existing crontab (if any)
    crontab -l > "$temp_cron" 2>/dev/null || true
    
    # Check if our job already exists
    if grep -q "daily_prediction.sh" "$temp_cron" 2>/dev/null; then
        echo "⚠️  Daily prediction cron job already exists. Updating..."
        # Remove existing job
        grep -v "daily_prediction.sh" "$temp_cron" > "${temp_cron}.new" || true
        mv "${temp_cron}.new" "$temp_cron"
    fi
    
    # Add environment variables and new cron job
    cat >> "$temp_cron" << EOF

# Daily Stock Prediction Job - Added by setup_daily_predictions.sh
# Runs at 9:00 AM Taipei time (1:00 AM UTC)
PATH=/usr/local/bin:/usr/bin:/bin
API_BASE_URL=http://localhost:8081
DAILY_PREDICTION_SYMBOLS=NVDA,TSLA,AAPL,MSFT,GOOGL,AMZN,AUR,PLTR,SMCI,TSM,MP,SMR,SPY,META,NOC,RTX,LMT
$CRON_TIME cd $PROJECT_ROOT && $script_path >> $log_path 2>&1
EOF
    
    # Install the new crontab
    crontab "$temp_cron"
    rm "$temp_cron"
    
    echo "✅ Daily prediction cron job added successfully"
    echo "   Schedule: $CRON_TIME (1:00 AM UTC / 9:00 AM Taipei)"
    echo "   Script: $script_path"
    echo "   Log: $log_path"
}

# Function to verify cron job installation
verify_installation() {
    echo ""
    echo "📋 Current crontab for user $USER:"
    echo "=================================="
    crontab -l | grep -A 5 -B 5 "daily_prediction" || echo "No daily prediction job found"
    echo ""
}

# Function to test the script
test_script() {
    local script_path="$PROJECT_ROOT/scripts/daily_prediction.sh"
    
    echo "🧪 Testing daily prediction script..."
    
    if [ ! -f "$script_path" ]; then
        echo "❌ Error: Daily prediction script not found at $script_path"
        exit 1
    fi
    
    if [ ! -x "$script_path" ]; then
        echo "❌ Error: Daily prediction script is not executable"
        echo "   Run: chmod +x $script_path"
        exit 1
    fi
    
    echo "✅ Daily prediction script is ready"
}

# Function to show usage information
show_usage() {
    cat << EOF
📖 Daily Predictions Setup Complete!

🕒 Schedule Information:
   - Cron Schedule: $CRON_TIME
   - Local Time: 1:00 AM UTC (9:00 AM Taipei)
   - Frequency: Daily
   - Symbols: NVDA, TSLA, AAPL, MSFT, GOOGL, AMZN, AUR, PLTR, SMCI, TSM, MP, SMR, SPY, META, NOC, RTX, LMT

📁 File Locations:
   - Script: $PROJECT_ROOT/scripts/daily_prediction.sh
   - Logs: $PROJECT_ROOT/logs/daily_prediction_*.log
   - Cron Log: $PROJECT_ROOT/logs/daily_prediction_cron.log

🔧 Management Commands:
   - View cron jobs: crontab -l
   - Edit cron jobs: crontab -e
   - Remove cron jobs: crontab -r
   - View logs: tail -f $PROJECT_ROOT/logs/daily_prediction_cron.log

🧪 Testing:
   - Test script manually: $PROJECT_ROOT/scripts/daily_prediction.sh
   - Check service health: curl http://localhost:8081/api/v1/health
   - View daily status: curl http://localhost:8081/api/v1/predictions/daily-status

⚙️  Configuration:
   - Edit symbols: Modify DAILY_PREDICTION_SYMBOLS in crontab
   - Change schedule: Modify cron time in crontab
   - Force execution: Set FORCE_EXECUTE=true in environment

🚨 Troubleshooting:
   - Check cron service: sudo systemctl status cron
   - Check logs: tail -f $PROJECT_ROOT/logs/daily_prediction_*.log
   - Test API: curl -X POST http://localhost:8081/api/v1/predictions/daily-run

EOF
}

# Function to setup log rotation
setup_log_rotation() {
    local logrotate_config="/etc/logrotate.d/stock-prediction-daily"
    
    if [ -w "/etc/logrotate.d" ] || [ "$EUID" -eq 0 ]; then
        cat > "$logrotate_config" << EOF
$PROJECT_ROOT/logs/daily_prediction_*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 $USER $USER
}
EOF
        echo "✅ Log rotation configured at $logrotate_config"
    else
        echo "⚠️  Cannot setup log rotation (requires sudo). Logs will be cleaned by script."
    fi
}

# Main execution
main() {
    echo "Starting daily predictions setup..."
    echo "User: $USER"
    echo "Project Root: $PROJECT_ROOT"
    echo "Cron Schedule: $CRON_TIME"
    echo ""
    
    # Check prerequisites
    check_cron_installed
    test_script
    
    # Backup existing crontab
    backup_crontab
    
    # Add cron job
    add_cron_job
    
    # Setup log rotation
    setup_log_rotation
    
    # Verify installation
    verify_installation
    
    # Show usage information
    show_usage
    
    echo "🎉 Daily predictions setup completed successfully!"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help] [--remove] [--test]"
        echo ""
        echo "Options:"
        echo "  --help    Show this help message"
        echo "  --remove  Remove the daily prediction cron job"
        echo "  --test    Test the daily prediction script"
        echo ""
        echo "Environment Variables:"
        echo "  CRON_TIME    Cron schedule (default: '0 1 * * *')"
        echo "  USER         User for cron job (default: current user)"
        exit 0
        ;;
    --remove)
        echo "🗑️  Removing daily prediction cron job..."
        temp_cron=$(mktemp)
        crontab -l > "$temp_cron" 2>/dev/null || true
        grep -v "daily_prediction.sh" "$temp_cron" > "${temp_cron}.new" || true
        crontab "${temp_cron}.new"
        rm "$temp_cron" "${temp_cron}.new"
        echo "✅ Daily prediction cron job removed"
        exit 0
        ;;
    --test)
        echo "🧪 Testing daily prediction script..."
        "$PROJECT_ROOT/scripts/daily_prediction.sh"
        exit 0
        ;;
    "")
        main
        ;;
    *)
        echo "❌ Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
