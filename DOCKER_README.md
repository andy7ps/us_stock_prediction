# Stock Prediction Service v3.0

A high-performance, production-ready stock price prediction service built with Go and machine learning.

## Quick Start

```bash
# Run the service
docker run -d -p 8080:8080 --name stock-prediction YOUR_USERNAME/stock-prediction:latest

# Check health
curl http://localhost:8080/api/v1/health

# Get a prediction
curl http://localhost:8080/api/v1/predict/NVDA
```

## Features

- **Real-time Stock Data**: Fetches live stock data from Yahoo Finance API
- **ML Predictions**: Uses machine learning models for price prediction
- **Intelligent Caching**: Redis-like in-memory caching with TTL
- **Rate Limiting**: Configurable rate limiting for API calls
- **Comprehensive Monitoring**: Prometheus metrics integration
- **Health Checks**: Built-in health monitoring
- **Production Ready**: Structured logging, error handling, graceful shutdown

## API Endpoints

- `GET /api/v1/health` - Service health check
- `GET /api/v1/predict/{symbol}` - Get stock price prediction
- `GET /api/v1/historical/{symbol}` - Get historical stock data
- `GET /api/v1/stats` - Service statistics
- `GET /metrics` - Prometheus metrics

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_PORT` | `8080` | HTTP server port |
| `LOG_LEVEL` | `info` | Logging level (debug, info, warn, error) |
| `LOG_FORMAT` | `json` | Log format (json, text) |
| `STOCK_SYMBOL` | `NVDA` | Default stock symbol |
| `STOCK_LOOKBACK_DAYS` | `5` | Historical data lookback period |
| `API_TIMEOUT` | `30s` | API request timeout |
| `ML_PREDICTION_TTL` | `5m` | Prediction cache TTL |

## Docker Compose

For a complete setup with monitoring:

```yaml
version: '3.8'
services:
  stock-prediction:
    image: YOUR_USERNAME/stock-prediction:latest
    ports:
      - "8080:8080"
    environment:
      - LOG_LEVEL=info
      - STOCK_SYMBOL=NVDA
```

## Health Check

The container includes built-in health checks that verify:
- Yahoo Finance API connectivity
- ML model availability
- Service responsiveness

## Monitoring

The service exposes Prometheus metrics at `/metrics` endpoint for monitoring:
- API request metrics
- Prediction accuracy metrics
- Cache performance metrics
- System resource metrics

## Security

- Runs as non-root user (appuser:appgroup)
- Minimal attack surface with distroless-style runtime
- No sensitive data in environment variables

## Architecture

- **Multi-stage build**: Go builder + Python runtime
- **Size**: ~520MB optimized image
- **Base**: Python 3.11 slim with ML dependencies
- **Dependencies**: numpy, pandas, scikit-learn, joblib

## Support

- **GitHub**: [Repository URL]
- **Issues**: [Issues URL]
- **Documentation**: [Docs URL]

## License

MIT License - see LICENSE file for details.
