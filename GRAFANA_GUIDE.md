# Grafana Guide - Stock Prediction System Monitoring

## What is Grafana?

**Grafana** is an open-source visualization and monitoring platform that transforms your application metrics into beautiful, interactive dashboards. Think of it as your "mission control center" for monitoring your stock prediction service.

## Why Grafana for Stock Prediction System?

### 🎯 **Business Value**

1. **Real-time Performance Monitoring**
   - See how many predictions your system is making per second
   - Monitor response times to ensure fast user experience
   - Track system health and uptime

2. **ML Model Performance Tracking**
   - Monitor prediction accuracy over time
   - Track which stocks are being predicted most
   - Identify patterns in prediction requests

3. **Operational Insights**
   - Cache performance optimization
   - Resource usage monitoring
   - Error rate tracking and alerting

4. **Business Intelligence**
   - Popular stock symbols
   - Peak usage times
   - User behavior patterns

## 📊 What Grafana Shows for Your System

### **Dashboard Panels Explained**

#### 1. **API Request Rate** 📈
```
Shows: Requests per second to your API
Why Important: Monitor traffic load and scaling needs
Alert When: > 50 requests/sec (may need scaling)
```

#### 2. **Prediction Requests** 🔮
```
Shows: How many stock predictions are being made
Why Important: Core business metric - actual ML usage
Trend Analysis: Peak hours, popular stocks
```

#### 3. **Cache Hit Ratio** ⚡
```
Shows: Percentage of requests served from cache
Why Important: Higher ratio = faster responses, lower costs
Target: > 80% for optimal performance
```

#### 4. **Response Time** ⏱️
```
Shows: How fast your API responds (95th percentile)
Why Important: User experience and SLA compliance
Target: < 500ms for good user experience
```

#### 5. **Stock Symbols Predicted** 📋
```
Shows: Top 10 most requested stock symbols
Why Important: Business insights, popular stocks
Use Case: Focus ML model improvements on popular stocks
```

#### 6. **Error Rate** ❌
```
Shows: Percentage of failed requests
Why Important: System reliability monitoring
Alert When: > 1% error rate
```

#### 7. **Memory Usage** 💾
```
Shows: Application memory consumption
Why Important: Prevent out-of-memory crashes
Alert When: > 80% of available memory
```

#### 8. **Prediction Accuracy Trend** 🎯
```
Shows: ML model accuracy over time
Why Important: Model performance degradation detection
Use Case: Know when to retrain models
```

#### 9. **Active Connections** 🔗
```
Shows: Current number of active HTTP connections
Why Important: Concurrent user monitoring
Use Case: Capacity planning
```

## 🚀 How to Access Grafana

### **Starting the System**
```bash
# Start all services including Grafana
docker-compose up -d

# Check if Grafana is running
docker-compose ps
```

### **Accessing Grafana**
- **URL**: http://localhost:3000
- **Username**: admin
- **Password**: admin
- **First Login**: You'll be prompted to change the password

## 📈 Real-World Usage Scenarios

### **Scenario 1: Performance Monitoring**
```
Problem: Users complaining about slow predictions
Solution: Check Grafana dashboard
- Look at "Response Time" panel
- Check "Cache Hit Ratio" 
- If cache ratio is low, increase cache TTL
- If response time is high, scale horizontally
```

### **Scenario 2: Business Intelligence**
```
Use Case: Which stocks should we optimize for?
Solution: Check "Stock Symbols Predicted" panel
- See most popular stocks (NVDA, TSLA, AAPL)
- Focus ML model improvements on top stocks
- Allocate more cache space for popular symbols
```

### **Scenario 3: System Health**
```
Daily Operations: Morning system check
Dashboard Review:
- Error Rate: Should be < 1%
- Memory Usage: Should be stable
- API Request Rate: Normal traffic patterns
- Prediction Accuracy: No sudden drops
```

### **Scenario 4: Capacity Planning**
```
Growth Planning: Need to scale?
Metrics to Check:
- API Request Rate trends (growing?)
- Response Time trends (increasing?)
- Memory Usage trends (approaching limits?)
- Active Connections (hitting max?)
```

## 🔧 Customizing Your Dashboard

### **Adding New Panels**

1. **Click "+" → Add Panel**
2. **Choose Visualization Type**:
   - Graph: Time series data
   - Stat: Single number metrics
   - Table: Tabular data
   - Gauge: Progress indicators

3. **Add Prometheus Query**:
   ```promql
   # Example: Prediction requests by stock symbol
   sum by (symbol) (rate(prediction_requests_total[5m]))
   
   # Example: Average prediction confidence
   avg(prediction_confidence)
   
   # Example: Cache size over time
   cache_size
   ```

### **Creating Alerts**

```bash
# Example: Alert when error rate > 5%
Alert Condition: 
  rate(http_requests_total{status=~"4..|5.."}[5m]) / rate(http_requests_total[5m]) * 100 > 5

# Example: Alert when memory usage > 1GB
Alert Condition:
  process_resident_memory_bytes > 1073741824
```

## 📊 Key Metrics for Stock Prediction System

### **Performance Metrics**
```promql
# Request rate
rate(http_requests_total[5m])

# Response time percentiles
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Error rate
rate(http_requests_total{status=~"4..|5.."}[5m]) / rate(http_requests_total[5m])
```

### **Business Metrics**
```promql
# Prediction requests
rate(prediction_requests_total[5m])

# Most popular stocks
topk(10, sum by (symbol) (prediction_requests_total))

# Prediction accuracy
prediction_accuracy
```

### **System Metrics**
```promql
# Memory usage
process_resident_memory_bytes

# CPU usage
rate(process_cpu_seconds_total[5m])

# Cache performance
cache_hits_total / (cache_hits_total + cache_misses_total)
```

## 🎨 Dashboard Best Practices

### **Layout Organization**
1. **Top Row**: Key business metrics (requests, predictions, accuracy)
2. **Middle Row**: Performance metrics (response time, errors)
3. **Bottom Row**: System metrics (memory, CPU, connections)

### **Color Coding**
- **Green**: Good performance (low error rate, high cache hit ratio)
- **Yellow**: Warning levels (moderate load, approaching limits)
- **Red**: Critical issues (high error rate, resource exhaustion)

### **Time Ranges**
- **Real-time**: Last 5 minutes (for immediate issues)
- **Operational**: Last 1 hour (for current performance)
- **Trending**: Last 24 hours (for daily patterns)
- **Analysis**: Last 7 days (for weekly trends)

## 🚨 Alerting Setup

### **Critical Alerts**
```yaml
# High Error Rate
- alert: HighErrorRate
  expr: rate(http_requests_total{status=~"4..|5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "High error rate detected"

# High Memory Usage
- alert: HighMemoryUsage
  expr: process_resident_memory_bytes > 1073741824
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Memory usage above 1GB"

# Low Prediction Accuracy
- alert: LowPredictionAccuracy
  expr: prediction_accuracy < 60
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "ML model accuracy below 60%"
```

## 📱 Mobile and Remote Access

### **Grafana Mobile App**
- Download Grafana mobile app
- Connect to your Grafana instance
- Monitor dashboards on the go

### **Sharing Dashboards**
```bash
# Create shareable link
Dashboard Settings → Share → Link

# Export dashboard
Dashboard Settings → JSON Model → Copy to clipboard

# Snapshot for external sharing
Dashboard → Share → Snapshot
```

## 🔍 Troubleshooting Grafana

### **Common Issues**

#### **Grafana Won't Start**
```bash
# Check Docker Compose logs
docker-compose logs grafana

# Common causes:
# - Port 3000 already in use
# - Volume permission issues
# - Configuration errors
```

#### **No Data in Dashboards**
```bash
# Check Prometheus connection
# Grafana → Configuration → Data Sources → Prometheus
# Test connection should show "Data source is working"

# Check if metrics are being generated
curl http://localhost:8080/metrics | grep prediction
```

#### **Dashboard Not Loading**
```bash
# Check dashboard JSON syntax
# Grafana → Dashboard → Settings → JSON Model

# Reimport dashboard
# Grafana → + → Import → Upload JSON file
```

## 💡 Advanced Features

### **Variables and Templating**
```bash
# Create variable for stock symbols
Variable Name: symbol
Type: Query
Query: label_values(prediction_requests_total, symbol)

# Use in panels
Query: rate(prediction_requests_total{symbol="$symbol"}[5m])
```

### **Annotations**
```bash
# Mark deployment times
# Grafana → Dashboard → Settings → Annotations
# Add annotation for deployment events
```

### **Playlist**
```bash
# Create rotating dashboard display
# Grafana → Playlists → New Playlist
# Add multiple dashboards for rotation
```

## 🎯 Business Value Summary

### **For Developers**
- **Performance Optimization**: Identify bottlenecks
- **Debugging**: Visual error tracking
- **Capacity Planning**: Resource usage trends

### **For Operations**
- **System Health**: Real-time monitoring
- **Alerting**: Proactive issue detection
- **SLA Monitoring**: Response time tracking

### **For Business**
- **Usage Analytics**: Popular stocks and patterns
- **ROI Tracking**: API usage and efficiency
- **Quality Metrics**: Prediction accuracy trends

### **For Management**
- **Executive Dashboard**: High-level KPIs
- **Growth Metrics**: Usage trends over time
- **Performance Reports**: System reliability stats

## 🚀 Getting Started Checklist

- [ ] Start Docker Compose: `docker-compose up -d`
- [ ] Access Grafana: http://localhost:3000
- [ ] Login with admin/admin
- [ ] Change default password
- [ ] Verify Prometheus data source
- [ ] Import stock prediction dashboard
- [ ] Generate some API traffic
- [ ] Watch metrics populate in real-time
- [ ] Set up alerts for critical metrics
- [ ] Share dashboard with team

---

**Grafana transforms your stock prediction service from a "black box" into a transparent, monitored, and optimized system that you can confidently run in production!** 📊✨
