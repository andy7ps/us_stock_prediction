package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

// Metrics holds all application metrics
type Metrics struct {
	// API metrics
	APIRequestsTotal     prometheus.Counter
	APIRequestDuration   prometheus.Histogram
	APIErrorsTotal       prometheus.Counter
	
	// Prediction metrics
	PredictionsTotal     prometheus.Counter
	PredictionLatency    prometheus.Histogram
	PredictionErrors     prometheus.Counter
	PredictionAccuracy   prometheus.Gauge
	
	// Cache metrics
	CacheHits            prometheus.Counter
	CacheMisses          prometheus.Counter
	CacheSize            prometheus.Gauge
	
	// Stock data metrics
	StockDataFetches     prometheus.Counter
	StockDataErrors      prometheus.Counter
	StockDataLatency     prometheus.Histogram
	
	// System metrics
	ActiveConnections    prometheus.Gauge
	MemoryUsage          prometheus.Gauge
	CPUUsage             prometheus.Gauge
}

// NewMetrics creates and registers all metrics
func NewMetrics() *Metrics {
	return &Metrics{
		// API metrics
		APIRequestsTotal: promauto.NewCounter(prometheus.CounterOpts{
			Name: "api_requests_total",
			Help: "Total number of API requests",
		}),
		
		APIRequestDuration: promauto.NewHistogram(prometheus.HistogramOpts{
			Name:    "api_request_duration_seconds",
			Help:    "Duration of API requests",
			Buckets: prometheus.DefBuckets,
		}),
		
		APIErrorsTotal: promauto.NewCounter(prometheus.CounterOpts{
			Name: "api_errors_total",
			Help: "Total number of API errors",
		}),
		
		// Prediction metrics
		PredictionsTotal: promauto.NewCounter(prometheus.CounterOpts{
			Name: "predictions_total",
			Help: "Total number of predictions made",
		}),
		
		PredictionLatency: promauto.NewHistogram(prometheus.HistogramOpts{
			Name:    "prediction_latency_seconds",
			Help:    "Latency of prediction requests",
			Buckets: []float64{0.1, 0.5, 1.0, 2.0, 5.0, 10.0},
		}),
		
		PredictionErrors: promauto.NewCounter(prometheus.CounterOpts{
			Name: "prediction_errors_total",
			Help: "Total number of prediction errors",
		}),
		
		PredictionAccuracy: promauto.NewGauge(prometheus.GaugeOpts{
			Name: "prediction_accuracy",
			Help: "Current prediction accuracy",
		}),
		
		// Cache metrics
		CacheHits: promauto.NewCounter(prometheus.CounterOpts{
			Name: "cache_hits_total",
			Help: "Total number of cache hits",
		}),
		
		CacheMisses: promauto.NewCounter(prometheus.CounterOpts{
			Name: "cache_misses_total",
			Help: "Total number of cache misses",
		}),
		
		CacheSize: promauto.NewGauge(prometheus.GaugeOpts{
			Name: "cache_size",
			Help: "Current cache size",
		}),
		
		// Stock data metrics
		StockDataFetches: promauto.NewCounter(prometheus.CounterOpts{
			Name: "stock_data_fetches_total",
			Help: "Total number of stock data fetches",
		}),
		
		StockDataErrors: promauto.NewCounter(prometheus.CounterOpts{
			Name: "stock_data_errors_total",
			Help: "Total number of stock data fetch errors",
		}),
		
		StockDataLatency: promauto.NewHistogram(prometheus.HistogramOpts{
			Name:    "stock_data_latency_seconds",
			Help:    "Latency of stock data fetches",
			Buckets: []float64{0.1, 0.5, 1.0, 2.0, 5.0},
		}),
		
		// System metrics
		ActiveConnections: promauto.NewGauge(prometheus.GaugeOpts{
			Name: "active_connections",
			Help: "Number of active connections",
		}),
		
		MemoryUsage: promauto.NewGauge(prometheus.GaugeOpts{
			Name: "memory_usage_bytes",
			Help: "Current memory usage in bytes",
		}),
		
		CPUUsage: promauto.NewGauge(prometheus.GaugeOpts{
			Name: "cpu_usage_percent",
			Help: "Current CPU usage percentage",
		}),
	}
}

// RecordAPIRequest records an API request
func (m *Metrics) RecordAPIRequest(duration float64, success bool) {
	m.APIRequestsTotal.Inc()
	m.APIRequestDuration.Observe(duration)
	if !success {
		m.APIErrorsTotal.Inc()
	}
}

// RecordPrediction records a prediction
func (m *Metrics) RecordPrediction(duration float64, success bool) {
	m.PredictionsTotal.Inc()
	m.PredictionLatency.Observe(duration)
	if !success {
		m.PredictionErrors.Inc()
	}
}

// RecordCacheHit records a cache hit
func (m *Metrics) RecordCacheHit() {
	m.CacheHits.Inc()
}

// RecordCacheMiss records a cache miss
func (m *Metrics) RecordCacheMiss() {
	m.CacheMisses.Inc()
}

// UpdateCacheSize updates the cache size metric
func (m *Metrics) UpdateCacheSize(size int) {
	m.CacheSize.Set(float64(size))
}

// RecordStockDataFetch records a stock data fetch
func (m *Metrics) RecordStockDataFetch(duration float64, success bool) {
	m.StockDataFetches.Inc()
	m.StockDataLatency.Observe(duration)
	if !success {
		m.StockDataErrors.Inc()
	}
}

// UpdatePredictionAccuracy updates the prediction accuracy metric
func (m *Metrics) UpdatePredictionAccuracy(accuracy float64) {
	m.PredictionAccuracy.Set(accuracy)
}

// UpdateActiveConnections updates the active connections metric
func (m *Metrics) UpdateActiveConnections(count int) {
	m.ActiveConnections.Set(float64(count))
}

// UpdateSystemMetrics updates system resource metrics
func (m *Metrics) UpdateSystemMetrics(memoryBytes int64, cpuPercent float64) {
	m.MemoryUsage.Set(float64(memoryBytes))
	m.CPUUsage.Set(cpuPercent)
}
