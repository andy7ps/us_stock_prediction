# Stock Prediction Service v3.0

A high-performance, production-ready stock price prediction service built with Go and machine learning. This service provides real-time stock price predictions with caching, monitoring, and comprehensive error handling.

## Features

- **Real-time Stock Data**: Fetches live stock data from Yahoo Finance API
- **ML Predictions**: Uses machine learning models for price prediction
- **Intelligent Caching**: Redis-like in-memory caching with TTL
- **Rate Limiting**: Configurable rate limiting for API calls
- **Comprehensive Monitoring**: Prometheus metrics and Grafana dashboards
- **Health Checks**: Built-in health monitoring and status endpoints
- **Graceful Shutdown**: Proper application lifecycle management
- **Docker Support**: Full containerization with Docker Compose
- **Production Ready**: Structured logging, error handling, and configuration management

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   HTTP Client   │───▶│   API Gateway    │───▶│   Handlers      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                       ┌─────────────────┐              │
                       │   Prometheus    │◀─────────────┤
                       │   Metrics       │              │
                       └─────────────────┘              │
                                                         ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Yahoo Finance │◀───│   Yahoo Client   │◀───│   Services      │
│      API        │    └──────────────────┘    │                 │
└─────────────────┘                            │  ┌─────────────┐│
                                                │  │ Prediction  ││
┌─────────────────┐    ┌──────────────────┐    │  │  Service    ││
│   Python ML     │◀───│   ML Executor    │◀───│  └─────────────┘│
│    Models       │    └──────────────────┘    │                 │
└─────────────────┘                            │  ┌─────────────┐│
                                                │  │    Cache    ││
                                                │  │   Service   ││
                                                │  └─────────────┘│
                                                └─────────────────┘
```

## Quick Start

### Prerequisites

- Go 1.23+
- Python 3.11+
- Docker & Docker Compose
- Make (optional, for convenience)

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd stock-prediction-v3
   ```

2. **Setup environment**:
   ```bash
   make dev-setup
   # or manually:
   cp .env.example .env
   mkdir -p models logs
   ```

3. **Install dependencies**:
   ```bash
   make deps
   # or manually:
   go mod download
   ```

4. **Run the service**:
   ```bash
   make run
   # or manually:
   go run main.go
   ```

### Docker Deployment

1. **Build and run with Docker Compose**:
   ```bash
   make docker-run
   # or manually:
   docker-compose up -d
   ```

2. **View logs**:
   ```bash
   make docker-logs
   # or manually:
   docker-compose logs -f stock-prediction
   ```

3. **Access monitoring**:
   - Application: http://localhost:8080
   - Prometheus: http://localhost:9090
   - Grafana: http://localhost:3000 (admin/admin)

## API Endpoints

### Prediction Endpoints

- **GET /api/v1/predict/{symbol}**: Get stock price prediction
  - Query params: `days` (lookback period, default: 5)
  - Example: `GET /api/v1/predict/NVDA?days=10`

- **GET /api/v1/historical/{symbol}**: Get historical stock data
  - Query params: `days` (data period, default: 30)
  - Example: `GET /api/v1/historical/AAPL?days=60`

### Management Endpoints

- **GET /api/v1/health**: Service health check
- **GET /api/v1/stats**: Service statistics and cache info
- **POST /api/v1/cache/clear**: Clear prediction cache

### Monitoring

- **GET /metrics**: Prometheus metrics endpoint
- **GET /**: Service information and available endpoints

## Configuration

The service can be configured via environment variables or a JSON config file:

### Environment Variables

```bash
# Server Configuration
SERVER_PORT=8080
SERVER_READ_TIMEOUT=10s
SERVER_WRITE_TIMEOUT=10s

# Stock Configuration
STOCK_SYMBOL=NVDA
STOCK_LOOKBACK_DAYS=5
STOCK_BUY_THRESHOLD=1.01
STOCK_SELL_THRESHOLD=0.99
STOCK_MAX_RETRIES=3
STOCK_REQUESTS_PER_SEC=10

# API Configuration
API_TIMEOUT=30s
API_USER_AGENT=StockPredictor/3.0

# ML Configuration
ML_PYTHON_SCRIPT=scripts/ml/predict.py
ML_MODEL_PATH=models/nvda_lstm_model
ML_SCALER_PATH=models/scaler.pkl
ML_PREDICTION_TTL=5m

# Logging
LOG_LEVEL=info
LOG_FORMAT=json
```

### JSON Configuration

Set `CONFIG_FILE=config.json` and create a JSON file with the same structure.

## Machine Learning Integration

The service integrates with Python ML models through a subprocess interface:

### Python Script Interface

The Python script should:
1. Accept comma-separated prices as a command-line argument
2. Output the predicted price to stdout
3. Handle errors gracefully

Example usage:
```bash
python3 scripts/ml/predict.py "100.0,101.0,102.0,103.0,104.0"
# Output: 105.23
```

### Model Requirements

- **Input**: Array of historical closing prices
- **Output**: Single predicted price value
- **Format**: Float64 with 2 decimal places

## Monitoring and Observability

### Metrics

The service exposes comprehensive Prometheus metrics:

- **API Metrics**: Request count, duration, errors
- **Prediction Metrics**: Prediction count, latency, accuracy
- **Cache Metrics**: Hit/miss ratio, cache size
- **Stock Data Metrics**: Fetch count, latency, errors
- **System Metrics**: Memory usage, CPU usage, active connections

### Health Checks

Health checks verify:
- Yahoo Finance API connectivity
- Python ML model availability
- Model file existence
- Service responsiveness

### Logging

Structured logging with configurable levels and formats:
- **Levels**: debug, info, warn, error
- **Formats**: json, text
- **Fields**: timestamp, level, message, context

## Development

### Available Make Targets

```bash
make help          # Show available targets
make deps          # Install dependencies
make fmt           # Format code
make lint          # Run linter
make test          # Run tests with coverage
make build         # Build binary
make run           # Run locally
make docker-build  # Build Docker image
make docker-run    # Run with Docker Compose
make test-api      # Test API endpoints
```

### Testing

```bash
# Run all tests
make test

# Run short tests
make test-short

# Test API endpoints
make test-api
```

### Code Quality

The project uses:
- **gofmt** for code formatting
- **golangci-lint** for linting
- **go test** with race detection
- **Code coverage** reporting

## Production Deployment

### Performance Tuning

1. **Caching**: Adjust `ML_PREDICTION_TTL` based on your needs
2. **Rate Limiting**: Configure `STOCK_REQUESTS_PER_SEC` for your API limits
3. **Timeouts**: Set appropriate `API_TIMEOUT` and server timeouts
4. **Resources**: Monitor memory and CPU usage via metrics

### Security Considerations

1. **API Keys**: Store sensitive data in environment variables
2. **Rate Limiting**: Implement additional rate limiting if needed
3. **CORS**: Configure CORS headers for your domain
4. **HTTPS**: Use reverse proxy (nginx) for TLS termination

### Scaling

1. **Horizontal Scaling**: Run multiple instances behind a load balancer
2. **Caching**: Consider external Redis for shared caching
3. **Database**: Add persistent storage for historical data
4. **ML Models**: Use model serving platforms for complex models

## Troubleshooting

### Common Issues

1. **Python Script Errors**:
   - Check Python dependencies: `pip install numpy pandas scikit-learn`
   - Verify script permissions: `chmod +x scripts/ml/predict.py`
   - Test script manually: `python3 scripts/ml/predict.py "100,101,102"`

2. **Yahoo Finance API Errors**:
   - Check network connectivity
   - Verify rate limiting settings
   - Monitor API response codes

3. **Memory Issues**:
   - Monitor cache size via `/api/v1/stats`
   - Adjust `ML_PREDICTION_TTL` to reduce cache usage
   - Check for memory leaks in metrics

### Debugging

1. **Enable Debug Logging**:
   ```bash
   export LOG_LEVEL=debug
   go run main.go
   ```

2. **Check Health Status**:
   ```bash
   curl http://localhost:8080/api/v1/health
   ```

3. **Monitor Metrics**:
   ```bash
   curl http://localhost:8080/metrics
   ```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Run `make fmt lint test`
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review the logs and metrics
3. Open an issue on GitHub
