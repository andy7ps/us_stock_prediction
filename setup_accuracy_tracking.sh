#!/bin/bash

# Setup Accuracy Tracking Cron Jobs
# Stock Prediction Service v3.4.0
# Author: Stock Prediction Service Development Team
# Created: 2025-08-18

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
USER="${USER:-$(whoami)}"

echo "🎯 Setting up Accuracy Tracking Cron Jobs"
echo "=========================================="

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
    local backup_file="$PROJECT_ROOT/logs/crontab_backup_accuracy_$(date +%Y%m%d_%H%M%S).txt"
    mkdir -p "$PROJECT_ROOT/logs"
    
    if crontab -l > "$backup_file" 2>/dev/null; then
        echo "✅ Existing crontab backed up to: $backup_file"
    else
        echo "ℹ️  No existing crontab to backup"
        touch "$backup_file"
    fi
}

# Function to add accuracy tracking cron jobs
add_accuracy_cron_jobs() {
    echo "📝 Adding accuracy tracking cron jobs..."
    
    # Get current crontab
    local temp_cron
    temp_cron=$(mktemp)
    crontab -l > "$temp_cron" 2>/dev/null || true
    
    # Check if accuracy tracking jobs already exist
    if grep -q "# Accuracy Tracking Jobs" "$temp_cron" 2>/dev/null; then
        echo "⚠️  Accuracy tracking jobs already exist. Removing old ones..."
        # Remove existing accuracy tracking jobs
        sed -i '/# Accuracy Tracking Jobs/,/^$/d' "$temp_cron"
    fi
    
    # Add new accuracy tracking jobs
    cat >> "$temp_cron" << EOF

# Accuracy Tracking Jobs - Added by setup_accuracy_tracking.sh
# Update actual prices and calculate accuracy metrics
PATH=/usr/local/bin:/usr/bin:/bin
API_BASE_URL=http://localhost:8081

# Update actual prices daily at 10:00 AM Taipei time (2:00 AM UTC)
# This runs after markets close to get the latest closing prices
0 2 * * 1-5 cd $PROJECT_ROOT && $PROJECT_ROOT/scripts/update_actual_prices.sh >> $PROJECT_ROOT/logs/accuracy_tracking_cron.log 2>&1

# Calculate accuracy metrics daily at 10:30 AM Taipei time (2:30 AM UTC)
30 2 * * 1-5 cd $PROJECT_ROOT && $PROJECT_ROOT/scripts/calculate_accuracy.sh summary >> $PROJECT_ROOT/logs/accuracy_summary_cron.log 2>&1

# Weekly comprehensive accuracy analysis on Sundays at 3:00 AM UTC (11:00 AM Taipei)
0 3 * * 0 cd $PROJECT_ROOT && $PROJECT_ROOT/scripts/calculate_accuracy.sh all >> $PROJECT_ROOT/logs/accuracy_weekly_cron.log 2>&1

EOF
    
    # Install the new crontab
    if crontab "$temp_cron"; then
        echo "✅ Accuracy tracking cron jobs added successfully"
    else
        echo "❌ Failed to install cron jobs"
        rm -f "$temp_cron"
        exit 1
    fi
    
    rm -f "$temp_cron"
}

# Function to test the scripts
test_scripts() {
    echo "🧪 Testing accuracy tracking scripts..."
    
    # Test update actual prices script
    if [ -f "$PROJECT_ROOT/scripts/update_actual_prices.sh" ]; then
        echo "✅ update_actual_prices.sh exists and is executable"
    else
        echo "❌ update_actual_prices.sh not found or not executable"
        exit 1
    fi
    
    # Test calculate accuracy script
    if [ -f "$PROJECT_ROOT/scripts/calculate_accuracy.sh" ]; then
        echo "✅ calculate_accuracy.sh exists and is executable"
    else
        echo "❌ calculate_accuracy.sh not found or not executable"
        exit 1
    fi
    
    # Test API connectivity
    if curl -s -f "http://localhost:8081/api/v1/health" > /dev/null 2>&1; then
        echo "✅ API connectivity test passed"
    else
        echo "⚠️  API connectivity test failed (service may not be running)"
    fi
}

# Function to display current cron jobs
display_cron_jobs() {
    echo ""
    echo "📋 Current crontab for user $USER:"
    echo "=================================="
    crontab -l 2>/dev/null | grep -A 10 -B 2 "Accuracy Tracking" || echo "No accuracy tracking jobs found"
}

# Main execution
main() {
    echo "Starting accuracy tracking setup..."
    echo "User: $USER"
    echo "Project Root: $PROJECT_ROOT"
    echo ""
    
    check_cron_installed
    test_scripts
    backup_crontab
    add_accuracy_cron_jobs
    display_cron_jobs
    
    echo ""
    echo "📖 Accuracy Tracking Setup Complete!"
    echo ""
    echo "🕒 Schedule Information:"
    echo "   - Update Actual Prices: 2:00 AM UTC daily (weekdays only)"
    echo "   - Calculate Accuracy: 2:30 AM UTC daily (weekdays only)"
    echo "   - Weekly Analysis: 3:00 AM UTC Sundays"
    echo ""
    echo "📁 Log Files:"
    echo "   - Accuracy Updates: $PROJECT_ROOT/logs/accuracy_tracking_cron.log"
    echo "   - Daily Summary: $PROJECT_ROOT/logs/accuracy_summary_cron.log"
    echo "   - Weekly Analysis: $PROJECT_ROOT/logs/accuracy_weekly_cron.log"
    echo ""
    echo "🔧 Management Commands:"
    echo "   - View cron jobs: crontab -l"
    echo "   - Edit cron jobs: crontab -e"
    echo "   - Test update script: $PROJECT_ROOT/scripts/update_actual_prices.sh --test"
    echo "   - Test accuracy script: $PROJECT_ROOT/scripts/calculate_accuracy.sh summary"
    echo ""
    echo "🧪 Manual Testing:"
    echo "   - Update prices: $PROJECT_ROOT/scripts/update_actual_prices.sh"
    echo "   - Show accuracy: $PROJECT_ROOT/scripts/calculate_accuracy.sh all"
    echo "   - Symbol accuracy: $PROJECT_ROOT/scripts/calculate_accuracy.sh symbol NVDA"
    echo ""
    echo "🚨 Troubleshooting:"
    echo "   - Check cron service: sudo systemctl status cron"
    echo "   - Check logs: tail -f $PROJECT_ROOT/logs/accuracy_*_cron.log"
    echo "   - Test API: curl http://localhost:8081/api/v1/health"
    echo ""
    echo "🎉 Accuracy tracking setup completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0"
        echo ""
        echo "Setup automatic accuracy tracking for stock predictions"
        echo ""
        echo "This script will:"
        echo "  1. Install cron jobs to update actual prices daily"
        echo "  2. Install cron jobs to calculate accuracy metrics"
        echo "  3. Setup weekly comprehensive analysis"
        echo ""
        echo "The jobs will run automatically on weekdays after market close"
        exit 0
        ;;
    *)
        main
        ;;
esac
