#!/bin/bash

# System Status Script for Stock Prediction Service v3.4.0
# Shows comprehensive status of daily predictions and accuracy tracking
# Author: Stock Prediction Service Development Team
# Created: 2025-08-18

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_BASE_URL="${API_BASE_URL:-http://localhost:8081}"

echo "📊 Stock Prediction Service v3.4.0 - System Status"
echo "=================================================="
echo "Timestamp: $(date)"
echo "API Base URL: $API_BASE_URL"
echo ""

# Function to check service health
check_service_health() {
    echo "🔍 Service Health Check"
    echo "----------------------"
    
    if curl -s -f "$API_BASE_URL/api/v1/health" > /dev/null 2>&1; then
        local health_response
        health_response=$(curl -s "$API_BASE_URL/api/v1/health" | jq '.' 2>/dev/null || echo "Health check passed but JSON parsing failed")
        echo "✅ Service is healthy"
        echo "$health_response"
    else
        echo "❌ Service is not responding"
        return 1
    fi
    echo ""
}

# Function to check Docker containers
check_docker_status() {
    echo "🐳 Docker Container Status"
    echo "--------------------------"
    
    if command -v docker &> /dev/null; then
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAMES|v3_)"
    else
        echo "Docker not available"
    fi
    echo ""
}

# Function to check cron jobs
check_cron_jobs() {
    echo "⏰ Scheduled Jobs (Cron)"
    echo "-----------------------"
    
    echo "Daily Prediction Jobs:"
    crontab -l | grep -E "(daily_prediction|Daily)" || echo "No daily prediction jobs found"
    echo ""
    
    echo "Accuracy Tracking Jobs:"
    crontab -l | grep -E "(accuracy|update_actual_prices|calculate_accuracy)" || echo "No accuracy tracking jobs found"
    echo ""
    
    echo "Other ML Jobs:"
    crontab -l | grep -E "(training|monitoring|backup)" || echo "No other ML jobs found"
    echo ""
}

# Function to check database status
check_database_status() {
    echo "🗄️ Database Status"
    echo "------------------"
    
    if [ -f "database_data/predictions.db" ]; then
        echo "✅ Database file exists: database_data/predictions.db"
        
        # Check total predictions
        local total_predictions
        total_predictions=$(sqlite3 database_data/predictions.db "SELECT COUNT(*) FROM prediction_tracking;" 2>/dev/null || echo "0")
        echo "📊 Total predictions: $total_predictions"
        
        # Check predictions with actual prices
        local with_actual
        with_actual=$(sqlite3 database_data/predictions.db "SELECT COUNT(*) FROM prediction_tracking WHERE actual_close IS NOT NULL;" 2>/dev/null || echo "0")
        echo "✅ Predictions with actual prices: $with_actual"
        
        # Check latest prediction date
        local latest_date
        latest_date=$(sqlite3 database_data/predictions.db "SELECT MAX(prediction_date) FROM prediction_tracking;" 2>/dev/null || echo "N/A")
        echo "📅 Latest prediction date: $latest_date"
        
        # Check daily execution logs
        local executions
        executions=$(sqlite3 database_data/predictions.db "SELECT COUNT(*) FROM daily_execution_log;" 2>/dev/null || echo "0")
        echo "📋 Daily execution records: $executions"
        
    else
        echo "❌ Database file not found"
    fi
    echo ""
}

# Function to show accuracy metrics
show_accuracy_metrics() {
    echo "🎯 Accuracy Metrics"
    echo "------------------"
    
    if curl -s -f "$API_BASE_URL/api/v1/predictions/performance" > /dev/null 2>&1; then
        local performance
        performance=$(curl -s "$API_BASE_URL/api/v1/predictions/performance" 2>/dev/null)
        
        if command -v jq &> /dev/null; then
            echo "📈 Overall Performance:"
            echo "   Total Symbols: $(echo "$performance" | jq -r '.total_symbols // "N/A"')"
            echo "   Total Predictions: $(echo "$performance" | jq -r '.total_predictions // "N/A"')"
            echo "   With Actual Data: $(echo "$performance" | jq -r '.predictions_with_actual // "N/A"')"
            echo "   Overall MAPE: $(echo "$performance" | jq -r '.overall_accuracy_mape // "N/A"')%"
            echo "   Direction Accuracy: $(echo "$performance" | jq -r '.overall_direction_accuracy // "N/A"')%"
            echo ""
            
            echo "🏆 Top Performing Symbols:"
            echo "$performance" | jq -r '.symbol_summaries[] | select(.predictions_with_actual > 0) | 
                "   \(.symbol): \(.average_accuracy_mape | round)% MAPE, \(.predictions_with_actual) predictions"' | head -5
        else
            echo "Performance data available but jq not installed for parsing"
        fi
    else
        echo "❌ Unable to fetch performance metrics"
    fi
    echo ""
}

# Function to check log files
check_log_files() {
    echo "📝 Recent Log Activity"
    echo "---------------------"
    
    echo "Daily Prediction Logs:"
    if ls logs/daily_prediction_*.log >/dev/null 2>&1; then
        local latest_daily_log
        latest_daily_log=$(ls -t logs/daily_prediction_*.log | head -1)
        echo "   Latest: $latest_daily_log ($(wc -l < "$latest_daily_log") lines)"
        echo "   Last entry: $(tail -1 "$latest_daily_log" 2>/dev/null || echo "No entries")"
    else
        echo "   No daily prediction logs found"
    fi
    echo ""
    
    echo "Accuracy Tracking Logs:"
    if ls logs/accuracy_*.log >/dev/null 2>&1; then
        local latest_accuracy_log
        latest_accuracy_log=$(ls -t logs/accuracy_*.log | head -1 2>/dev/null || echo "")
        if [ -n "$latest_accuracy_log" ]; then
            echo "   Latest: $latest_accuracy_log ($(wc -l < "$latest_accuracy_log") lines)"
            echo "   Last entry: $(tail -1 "$latest_accuracy_log" 2>/dev/null || echo "No entries")"
        else
            echo "   No accuracy tracking logs found"
        fi
    else
        echo "   No accuracy tracking logs found"
    fi
    echo ""
}

# Function to show system recommendations
show_recommendations() {
    echo "💡 System Recommendations"
    echo "------------------------"
    
    # Check if accuracy tracking is set up
    if crontab -l | grep -q "update_actual_prices"; then
        echo "✅ Accuracy tracking cron jobs are configured"
    else
        echo "⚠️  Accuracy tracking not configured - run: ./setup_accuracy_tracking.sh"
    fi
    
    # Check if daily predictions are set up
    if crontab -l | grep -q "daily_prediction"; then
        echo "✅ Daily prediction cron jobs are configured"
    else
        echo "⚠️  Daily predictions not configured - run: ./setup_daily_predictions.sh"
    fi
    
    # Check database health
    local with_actual
    with_actual=$(sqlite3 database_data/predictions.db "SELECT COUNT(*) FROM prediction_tracking WHERE actual_close IS NOT NULL;" 2>/dev/null || echo "0")
    local total_predictions
    total_predictions=$(sqlite3 database_data/predictions.db "SELECT COUNT(*) FROM prediction_tracking;" 2>/dev/null || echo "1")
    
    local accuracy_percentage
    accuracy_percentage=$((with_actual * 100 / total_predictions))
    
    if [ "$accuracy_percentage" -lt 50 ]; then
        echo "⚠️  Low accuracy data coverage ($accuracy_percentage%) - run: ./scripts/update_actual_prices.sh"
    else
        echo "✅ Good accuracy data coverage ($accuracy_percentage%)"
    fi
    
    echo ""
    echo "🔧 Manual Commands:"
    echo "   Update actual prices: ./scripts/update_actual_prices.sh"
    echo "   Show accuracy: ./scripts/calculate_accuracy.sh summary"
    echo "   Test daily predictions: ./scripts/daily_prediction.sh"
    echo "   View cron jobs: crontab -l"
    echo ""
}

# Main execution
main() {
    check_service_health
    check_docker_status
    check_cron_jobs
    check_database_status
    show_accuracy_metrics
    check_log_files
    show_recommendations
    
    echo "🎉 System Status Check Complete!"
    echo ""
    echo "For detailed accuracy analysis, run: ./scripts/calculate_accuracy.sh all"
    echo "For manual price updates, run: ./scripts/update_actual_prices.sh"
    echo "For system logs, check: tail -f logs/*.log"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Show comprehensive system status for Stock Prediction Service"
        echo ""
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo ""
        echo "This script checks:"
        echo "  - Service health and API status"
        echo "  - Docker container status"
        echo "  - Cron job configuration"
        echo "  - Database status and predictions"
        echo "  - Accuracy metrics and performance"
        echo "  - Log file activity"
        echo "  - System recommendations"
        exit 0
        ;;
    *)
        main
        ;;
esac
