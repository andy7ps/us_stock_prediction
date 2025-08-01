# Grafana Dashboard Creation Guide - Stock Prediction Service

## 🎯 Complete Step-by-Step Dashboard Creation

### Prerequisites
- Docker Compose stack running: `docker-compose up -d`
- Services accessible:
  - Grafana: http://localhost:3000
  - Prometheus: http://localhost:9090
  - Stock Prediction API: http://localhost:8080

## Step 1: Initial Grafana Setup

### 1.1 Access Grafana
```bash
# Open browser to Grafana
open http://localhost:3000
# Or manually navigate to: http://localhost:3000
```

### 1.2 First Login
- **Username**: `admin`
- **Password**: `admin`
- **Action**: Change password when prompted (or skip for development)

### 1.3 Verify Data Source
1. Go to **Configuration** → **Data Sources**
2. Click **Prometheus** (should already be configured)
3. Click **Test** button - should show "Data source is working"

## Step 2: Create New Dashboard

### 2.1 Create Dashboard
1. Click **+** (Plus icon) in left sidebar
2. Select **Dashboard**
3. Click **Add new panel**

### 2.2 Dashboard Settings
1. Click **Dashboard settings** (gear icon)
2. **General Tab**:
   - **Name**: `Stock Prediction Service Monitor`
   - **Description**: `Real-time monitoring for stock prediction API`
   - **Tags**: `stock-prediction`, `api`, `ml`, `monitoring`
3. **Time options**:
   - **Timezone**: `Browser`
   - **Auto refresh**: `5s,10s,30s,1m,5m,15m,30m,1h,2h,1d`
   - **Default**: `5s`

## Step 3: Create Essential Monitoring Panels

### Panel 1: API Request Rate 📈

**Purpose**: Monitor incoming API traffic

1. **Add Panel** → **Add new panel**
2. **Panel Title**: `API Request Rate`
3. **Query Tab**:
   ```promql
   # Query A: Total request rate
   rate(http_requests_total[5m])
   
   # Legend: {{method}} {{endpoint}}
   ```
4. **Visualization**: `Stat`
5. **Field Options**:
   - **Unit**: `reqps` (requests per second)
   - **Decimals**: `2`
6. **Thresholds**:
   - **Green**: `0` to `10`
   - **Yellow**: `10` to `50`
   - **Red**: `50+`
7. **Panel Size**: Width `6`, Height `8`

### Panel 2: Prediction Requests Over Time 🔮

**Purpose**: Track prediction usage patterns

1. **Add Panel** → **Add new panel**
2. **Panel Title**: `Prediction Requests`
3. **Query Tab**:
   ```promql
   # Query A: Prediction request rate
   rate(prediction_requests_total[5m])
   
   # Query B: Cumulative predictions
   increase(prediction_requests_total[1h])
   ```
4. **Visualization**: `Time series`
5. **Legend**: 
   - Query A: `Predictions/sec`
   - Query B: `Total/hour`
6. **Y-Axis**:
   - **Unit**: `short`
   - **Min**: `0`
7. **Panel Size**: Width `12`, Height `8`

### Panel 3: Cache Performance ⚡

**Purpose**: Monitor caching efficiency

1. **Add Panel** → **Add new panel**
2. **Panel Title**: `Cache Hit Ratio`
3. **Query Tab**:
   ```promql
   # Cache hit ratio percentage
   (cache_hits_total / (cache_hits_total + cache_misses_total)) * 100
   ```
4. **Visualization**: `Gauge`
5. **Field Options**:
   - **Unit**: `percent (0-100)`
   - **Min**: `0`
   - **Max**: `100`
6. **Thresholds**:
   - **Red**: `0` to `50`
   - **Yellow**: `50` to `80`
   - **Green**: `80` to `100`
7. **Panel Size**: Width `6`, Height `8`

### Panel 4: Response Time Distribution ⏱️

**Purpose**: Monitor API performance

1. **Add Panel** → **Add new panel**
2. **Panel Title**: `Response Time`
3. **Query Tab**:
   ```promql
   # Query A: 50th percentile
   histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))
   
   # Query B: 95th percentile
   histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
   
   # Query C: 99th percentile
   histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
   ```
4. **Visualization**: `Time series`
5. **Legend**:
   - Query A: `50th percentile`
   - Query B: `95th percentile`
   - Query C: `99th percentile`
6. **Y-Axis**:
   - **Unit**: `seconds (s)`
   - **Min**: `0`
7. **Panel Size**: Width `12`, Height `8`

### Panel 5: Popular Stock Symbols 📋

**Purpose**: Business intelligence on stock requests

1. **Add Panel** → **Add new panel**
2. **Panel Title**: `Most Requested Stocks`
3. **Query Tab**:
   ```promql
   # Top 10 most requested stocks
   topk(10, sum by (symbol) (increase(prediction_requests_total[1h])))
   ```
4. **Visualization**: `Table`
5. **Transform**: 
   - **Add transformation** → **Organize fields**
   - **Hide**: `Time`
   - **Rename**: `Value` → `Requests/Hour`
6. **Field Options**:
   - **Unit**: `short`
   - **Decimals**: `0`
7. **Panel Size**: Width `6`, Height `8`

### Panel 6: Error Rate Monitoring ❌

**Purpose**: Track system reliability

1. **Add Panel** → **Add new panel**
2. **Panel Title**: `Error Rate`
3. **Query Tab**:
   ```promql
   # Error rate percentage
   (rate(http_requests_total{status=~"4..|5.."}[5m]) / rate(http_requests_total[5m])) * 100
   ```
4. **Visualization**: `Stat`
5. **Field Options**:
   - **Unit**: `percent (0-100)`
   - **Decimals**: `2`
6. **Thresholds**:
   - **Green**: `0` to `1`
   - **Yellow**: `1` to `5`
   - **Red**: `5+`
7. **Panel Size**: Width `6`, Height `4`

### Panel 7: System Resource Usage 💾

**Purpose**: Monitor system health

1. **Add Panel** → **Add new panel**
2. **Panel Title**: `Memory Usage`
3. **Query Tab**:
   ```promql
   # Memory usage in MB
   process_resident_memory_bytes / 1024 / 1024
   ```
4. **Visualization**: `Time series`
5. **Y-Axis**:
   - **Unit**: `bytes (MB)`
   - **Min**: `0`
6. **Panel Size**: Width `6`, Height `8`

### Panel 8: Prediction Accuracy Trend 🎯

**Purpose**: Monitor ML model performance

1. **Add Panel** → **Add new panel**
2. **Panel Title**: `Prediction Accuracy`
3. **Query Tab**:
   ```promql
   # Prediction accuracy percentage
   prediction_accuracy
   ```
4. **Visualization**: `Time series`
5. **Y-Axis**:
   - **Unit**: `percent (0-100)`
   - **Min**: `0`
   - **Max**: `100`
6. **Thresholds**:
   - **Red**: `0` to `60`
   - **Yellow**: `60` to `80`
   - **Green**: `80` to `100`
7. **Panel Size**: Width `6`, Height `8`

### Panel 9: Active Connections 🔗

**Purpose**: Monitor concurrent users

1. **Add Panel** → **Add new panel**
2. **Panel Title**: `Active Connections`
3. **Query Tab**:
   ```promql
   # Current active connections
   active_connections
   ```
4. **Visualization**: `Stat`
5. **Field Options**:
   - **Unit**: `short`
   - **Decimals**: `0`
6. **Panel Size**: Width `6`, Height `4`

## Step 4: Dashboard Layout Organization

### 4.1 Arrange Panels
**Recommended Layout (24-column grid):**

```
Row 1: Key Metrics (Top Priority)
┌─────────────┬─────────────┬─────────────┬─────────────┐
│ API Request │ Cache Hit   │ Error Rate  │ Active      │
│ Rate        │ Ratio       │             │ Connections │
│ (6x8)       │ (6x8)       │ (6x4)       │ (6x4)       │
└─────────────┴─────────────┴─────────────┴─────────────┘

Row 2: Performance Metrics
┌─────────────────────────────┬─────────────────────────────┐
│ Prediction Requests         │ Response Time Distribution  │
│ (12x8)                      │ (12x8)                      │
└─────────────────────────────┴─────────────────────────────┘

Row 3: Business Intelligence & System Health
┌─────────────────────────────┬─────────────┬─────────────┐
│ Most Requested Stocks       │ Memory      │ Prediction  │
│ (12x8)                      │ Usage       │ Accuracy    │
│                             │ (6x8)       │ (6x8)       │
└─────────────────────────────┴─────────────┴─────────────┘
```

### 4.2 Panel Positioning
1. **Drag and drop** panels to arrange them
2. **Resize** panels by dragging corners
3. **Align** panels using grid snap

## Step 5: Advanced Dashboard Features

### 5.1 Add Variables (Dynamic Filtering)

1. **Dashboard Settings** → **Variables**
2. **Add variable**:
   - **Name**: `stock_symbol`
   - **Type**: `Query`
   - **Data source**: `Prometheus`
   - **Query**: `label_values(prediction_requests_total, symbol)`
   - **Multi-value**: `true`
   - **Include All option**: `true`

3. **Use variable in panels**:
   ```promql
   # Filter by selected stock symbol
   rate(prediction_requests_total{symbol=~"$stock_symbol"}[5m])
   ```

### 5.2 Add Time Range Controls

1. **Dashboard Settings** → **Time options**
2. **Time options**:
   - **From**: `now-1h`
   - **To**: `now`
   - **Auto refresh**: `5s`

### 5.3 Add Annotations

1. **Dashboard Settings** → **Annotations**
2. **Add annotation**:
   - **Name**: `Deployments`
   - **Data source**: `Prometheus`
   - **Query**: `changes(up[5m]) > 0`

## Step 6: Save and Share Dashboard

### 6.1 Save Dashboard
1. **Save dashboard** (Ctrl+S or disk icon)
2. **Name**: `Stock Prediction Service Monitor`
3. **Folder**: `General` (or create new folder)
4. **Save**

### 6.2 Export Dashboard
1. **Dashboard Settings** → **JSON Model**
2. **Copy to clipboard** or **Save to file**
3. **Share** with team members

### 6.3 Create Shareable Link
1. **Share** button (top right)
2. **Link** tab
3. **Copy link** for sharing

## Step 7: Set Up Alerting

### 7.1 Create Alert Rules

**High Error Rate Alert:**
1. **Panel** → **Alert** tab
2. **Create Alert**:
   - **Name**: `High Error Rate`
   - **Condition**: `IS ABOVE 5` (5% error rate)
   - **Evaluation**: `every 1m for 2m`

**Low Cache Hit Rate Alert:**
1. **Panel** → **Alert** tab
2. **Create Alert**:
   - **Name**: `Low Cache Performance`
   - **Condition**: `IS BELOW 70` (70% hit rate)
   - **Evaluation**: `every 5m for 5m`

### 7.2 Configure Notifications
1. **Alerting** → **Notification channels**
2. **Add channel**:
   - **Type**: `Email`, `Slack`, `Webhook`
   - **Settings**: Configure based on type

## Step 8: Testing Your Dashboard

### 8.1 Generate Test Data
```bash
# Generate API traffic for testing
for i in {1..10}; do
  curl -s http://localhost:8080/api/v1/health >/dev/null
  curl -s http://localhost:8080/api/v1/predict/NVDA >/dev/null
  curl -s http://localhost:8080/api/v1/predict/TSLA >/dev/null
  curl -s http://localhost:8080/api/v1/predict/AAPL >/dev/null
  sleep 1
done
```

### 8.2 Verify Metrics
1. **Check Prometheus**: http://localhost:9090
2. **Query metrics**:
   ```promql
   http_requests_total
   prediction_requests_total
   cache_hits_total
   ```

### 8.3 Validate Dashboard
1. **Refresh dashboard** (F5)
2. **Check all panels** show data
3. **Test time ranges** (1h, 6h, 24h)
4. **Test auto-refresh**

## Step 9: Dashboard Maintenance

### 9.1 Regular Updates
- **Weekly**: Review panel performance and accuracy
- **Monthly**: Update queries based on new metrics
- **Quarterly**: Reorganize layout based on usage

### 9.2 Performance Optimization
```bash
# Optimize query performance
# Use recording rules for complex queries
# Limit time ranges for heavy queries
# Use appropriate step intervals
```

### 9.3 Backup Dashboard
```bash
# Export dashboard JSON regularly
# Store in version control
# Document changes and updates
```

## Step 10: Advanced Customization

### 10.1 Custom Themes
1. **Preferences** → **UI Theme**
2. **Choose**: `Dark`, `Light`, or `System`

### 10.2 Custom Colors
1. **Panel** → **Field** → **Standard options**
2. **Color scheme**: Choose color palette
3. **Thresholds**: Set custom colors

### 10.3 Custom Units
```bash
# Custom units for business metrics
predictions/hour
stocks/minute
confidence%
accuracy%
```

## 🎯 Complete Dashboard JSON Template

Here's a complete dashboard JSON you can import:

```json
{
  "dashboard": {
    "id": null,
    "title": "Stock Prediction Service Monitor",
    "tags": ["stock-prediction", "api", "ml"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "API Request Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "Requests/sec"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "reqps",
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 10},
                {"color": "red", "value": 50}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0}
      }
      // ... more panels
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "5s"
  }
}
```

## 🚀 Quick Start Commands

```bash
# Start services
docker-compose up -d

# Generate test data
./generate_test_traffic.sh

# Access Grafana
open http://localhost:3000

# Import dashboard
# Copy JSON template above
# Grafana → + → Import → Paste JSON
```

## 📊 Expected Results

After completing this guide, you'll have:

- ✅ **Professional monitoring dashboard** with 9 key panels
- ✅ **Real-time metrics** updating every 5 seconds
- ✅ **Business intelligence** on popular stocks and usage patterns
- ✅ **Performance monitoring** with response times and error rates
- ✅ **System health** monitoring with memory and connections
- ✅ **Alerting setup** for critical issues
- ✅ **Shareable dashboard** for team collaboration

Your dashboard will provide complete visibility into your stock prediction service's performance, usage patterns, and system health! 📈✨
