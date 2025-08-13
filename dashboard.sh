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
