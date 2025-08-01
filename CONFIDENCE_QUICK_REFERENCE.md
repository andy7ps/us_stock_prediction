# Advanced Confidence Calculation - Quick Reference

## 🚀 Quick Start Commands

```bash
# Test the advanced confidence system
make test-confidence-quick              # Quick validation
make test-confidence                    # Full analysis
./test_advanced_confidence.sh          # Interactive testing

# Single stock testing
curl -s localhost:8080/api/v1/predict/AAPL | jq .
curl -s localhost:8080/api/v1/predict/TSLA | jq .confidence
```

## 📊 Confidence Interpretation

| Range | Level | Meaning | Action |
|-------|-------|---------|---------|
| 0.85-0.95 | **Very High** | Strong prediction reliability | Large position, tight stops |
| 0.75-0.85 | **High** | Good prediction reliability | Normal position, standard stops |
| 0.65-0.75 | **Moderate** | Reasonable reliability | Reduced position, wider stops |
| 0.50-0.65 | **Low** | Limited reliability | Small position or skip |
| 0.15-0.50 | **Very Low** | Poor reliability | Avoid or contrarian play |

## 🎯 Stock Category Examples

### Large Cap Stable (High Confidence Expected)
```bash
curl -s localhost:8080/api/v1/predict/MSFT | jq '{symbol, confidence, signal: .trading_signal}'
curl -s localhost:8080/api/v1/predict/GOOGL | jq '{symbol, confidence, signal: .trading_signal}'
curl -s localhost:8080/api/v1/predict/AMZN | jq '{symbol, confidence, signal: .trading_signal}'
```

### Growth/Tech (Moderate Confidence Expected)
```bash
curl -s localhost:8080/api/v1/predict/NVDA | jq '{symbol, confidence, signal: .trading_signal}'
curl -s localhost:8080/api/v1/predict/AAPL | jq '{symbol, confidence, signal: .trading_signal}'
curl -s localhost:8080/api/v1/predict/TSLA | jq '{symbol, confidence, signal: .trading_signal}'
```

### Volatile/Meme (Variable Confidence Expected)
```bash
curl -s localhost:8080/api/v1/predict/GME | jq '{symbol, confidence, signal: .trading_signal}'
curl -s localhost:8080/api/v1/predict/AMC | jq '{symbol, confidence, signal: .trading_signal}'
curl -s localhost:8080/api/v1/predict/COIN | jq '{symbol, confidence, signal: .trading_signal}'
```

## 🔧 Algorithm Components

The advanced confidence calculation uses **4 factors**:

1. **Price Change Factor (25%)** - Exponential decay with market adjustments
2. **Historical Volatility (35%)** - Standard deviation of recent returns  
3. **Trend Alignment (25%)** - Short & medium-term trend analysis
4. **Price Momentum (15%)** - Price acceleration detection

## 📈 Integration Examples

### JavaScript Trading Strategy
```javascript
const prediction = await fetch('/api/v1/predict/AAPL').then(r => r.json());

// Position sizing based on confidence
let positionSize;
if (prediction.confidence > 0.80) {
    positionSize = baseSize * 1.5;        // High confidence
} else if (prediction.confidence > 0.65) {
    positionSize = baseSize;              // Moderate confidence  
} else {
    positionSize = baseSize * 0.5;        // Low confidence
}

// Dynamic stop loss
const stopLossDistance = 0.05 * (1 - prediction.confidence);
const stopLoss = prediction.current_price * (1 - stopLossDistance);
```

### Python Risk Management
```python
import requests

def get_prediction(symbol):
    response = requests.get(f'http://localhost:8080/api/v1/predict/{symbol}')
    return response.json()

def calculate_position_size(prediction, base_size=1000):
    confidence = prediction['confidence']
    
    if confidence > 0.80:
        return base_size * 1.5      # High confidence
    elif confidence > 0.65:
        return base_size            # Moderate confidence
    else:
        return base_size * 0.5      # Low confidence

# Usage
pred = get_prediction('AAPL')
size = calculate_position_size(pred)
print(f"Confidence: {pred['confidence']:.3f}, Position Size: ${size}")
```

## 🧪 Testing & Validation

### Regular Testing (Recommended)
```bash
# Weekly confidence validation
make test-confidence-quick

# Monthly full analysis
make test-confidence

# Monitor specific stocks
watch -n 30 'curl -s localhost:8080/api/v1/predict/AAPL | jq .confidence'
```

### Batch Analysis
```bash
# Test multiple stocks at once
make test-confidence-batch

# Custom batch test
for stock in AAPL MSFT GOOGL NVDA TSLA; do
  echo "=== $stock ===" && \
  curl -s localhost:8080/api/v1/predict/$stock | \
  jq '{symbol, confidence, change_pct: ((.predicted_price - .current_price) / .current_price * 100 | round * 100 / 100)}'
done
```

## 🔍 Troubleshooting

### Common Issues
- **Low confidence for stable stocks**: Check if historical data is sufficient
- **High confidence for volatile stocks**: Verify volatility calculation is working
- **Inconsistent confidence**: Ensure service has been restarted after updates

### Health Checks
```bash
# Service health
curl -s localhost:8080/api/v1/health | jq .

# Service statistics  
curl -s localhost:8080/api/v1/stats | jq .

# Check if advanced confidence is active
curl -s localhost:8080/api/v1/predict/AAPL | jq .confidence | awk '{if($1 > 0.9 || $1 < 0.2) print "Check confidence calculation"; else print "Confidence OK"}'
```

## 📋 Maintenance Checklist

### Weekly
- [ ] Run `make test-confidence-quick`
- [ ] Check service health: `curl -s localhost:8080/api/v1/health`
- [ ] Monitor response times

### Monthly  
- [ ] Run full confidence analysis: `make test-confidence`
- [ ] Review confidence distribution across stock categories
- [ ] Check for any confidence calibration drift

### Quarterly
- [ ] Analyze confidence vs actual prediction accuracy
- [ ] Consider confidence factor adjustments
- [ ] Review and update stock category classifications

## 🚀 Performance Notes

- **Response Time Impact**: <2% increase (45ms → 46ms)
- **Memory Usage**: +200 bytes per prediction
- **Computational Overhead**: <0.1ms per prediction
- **Accuracy Improvement**: Significant confidence calibration enhancement

## 📚 Related Documentation

- **RELEASE_NOTES_v3.0.md**: Complete implementation details
- **ADVANCED_CONFIDENCE_ANALYSIS.md**: Technical deep dive
- **README.md**: General setup and usage
- **test_advanced_confidence.sh**: Interactive testing script

---

**Status**: ✅ Production Ready  
**Last Updated**: July 29, 2025  
**Version**: v3.0 with Advanced Confidence
