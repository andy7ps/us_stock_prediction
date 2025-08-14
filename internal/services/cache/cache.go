package cache

import (
	"crypto/md5"
	"fmt"
	"sync"
	"time"

	"stock-prediction-us/internal/metrics"
	"stock-prediction-us/internal/models"
)

// CacheEntry represents a cached prediction
type CacheEntry struct {
	Prediction *models.PredictionResponse
	Timestamp  time.Time
	TTL        time.Duration
}

// IsExpired checks if the cache entry has expired
func (e *CacheEntry) IsExpired() bool {
	return time.Since(e.Timestamp) > e.TTL
}

// PredictionCache manages prediction caching
type PredictionCache struct {
	cache   map[string]*CacheEntry
	mutex   sync.RWMutex
	metrics *metrics.Metrics
	defaultTTL time.Duration
}

// NewPredictionCache creates a new prediction cache
func NewPredictionCache(defaultTTL time.Duration, metrics *metrics.Metrics) *PredictionCache {
	cache := &PredictionCache{
		cache:      make(map[string]*CacheEntry),
		metrics:    metrics,
		defaultTTL: defaultTTL,
	}
	
	// Start cleanup goroutine
	go cache.cleanupExpired()
	
	return cache
}

// generateKey generates a cache key from prediction request
func (c *PredictionCache) generateKey(symbol string, data []float64) string {
	// Create a hash of the symbol and data for the cache key
	hash := md5.New()
	hash.Write([]byte(symbol))
	for _, price := range data {
		hash.Write([]byte(fmt.Sprintf("%.2f", price)))
	}
	return fmt.Sprintf("%x", hash.Sum(nil))
}

// Get retrieves a prediction from cache
func (c *PredictionCache) Get(symbol string, data []float64) (*models.PredictionResponse, bool) {
	key := c.generateKey(symbol, data)
	
	c.mutex.RLock()
	entry, exists := c.cache[key]
	c.mutex.RUnlock()
	
	if !exists {
		c.metrics.RecordCacheMiss()
		return nil, false
	}
	
	if entry.IsExpired() {
		// Remove expired entry
		c.mutex.Lock()
		delete(c.cache, key)
		c.mutex.Unlock()
		
		c.metrics.RecordCacheMiss()
		c.updateCacheSize()
		return nil, false
	}
	
	c.metrics.RecordCacheHit()
	return entry.Prediction, true
}

// Set stores a prediction in cache
func (c *PredictionCache) Set(symbol string, data []float64, prediction *models.PredictionResponse) {
	key := c.generateKey(symbol, data)
	
	entry := &CacheEntry{
		Prediction: prediction,
		Timestamp:  time.Now(),
		TTL:        c.defaultTTL,
	}
	
	c.mutex.Lock()
	c.cache[key] = entry
	c.mutex.Unlock()
	
	c.updateCacheSize()
}

// SetWithTTL stores a prediction in cache with custom TTL
func (c *PredictionCache) SetWithTTL(symbol string, data []float64, prediction *models.PredictionResponse, ttl time.Duration) {
	key := c.generateKey(symbol, data)
	
	entry := &CacheEntry{
		Prediction: prediction,
		Timestamp:  time.Now(),
		TTL:        ttl,
	}
	
	c.mutex.Lock()
	c.cache[key] = entry
	c.mutex.Unlock()
	
	c.updateCacheSize()
}

// Clear removes all entries from cache
func (c *PredictionCache) Clear() {
	c.mutex.Lock()
	c.cache = make(map[string]*CacheEntry)
	c.mutex.Unlock()
	
	c.updateCacheSize()
}

// Size returns the current cache size
func (c *PredictionCache) Size() int {
	c.mutex.RLock()
	size := len(c.cache)
	c.mutex.RUnlock()
	
	return size
}

// cleanupExpired removes expired entries periodically
func (c *PredictionCache) cleanupExpired() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()
	
	for range ticker.C {
		c.mutex.Lock()
		
		expiredKeys := make([]string, 0)
		for key, entry := range c.cache {
			if entry.IsExpired() {
				expiredKeys = append(expiredKeys, key)
			}
		}
		
		for _, key := range expiredKeys {
			delete(c.cache, key)
		}
		
		c.mutex.Unlock()
		
		if len(expiredKeys) > 0 {
			c.updateCacheSize()
		}
	}
}

// updateCacheSize updates the cache size metric
func (c *PredictionCache) updateCacheSize() {
	if c.metrics != nil {
		c.metrics.UpdateCacheSize(c.Size())
	}
}

// GetStats returns cache statistics
func (c *PredictionCache) GetStats() map[string]interface{} {
	c.mutex.RLock()
	defer c.mutex.RUnlock()
	
	stats := map[string]interface{}{
		"size":        len(c.cache),
		"default_ttl": c.defaultTTL.String(),
	}
	
	// Count expired entries
	expired := 0
	for _, entry := range c.cache {
		if entry.IsExpired() {
			expired++
		}
	}
	stats["expired_entries"] = expired
	
	return stats
}
