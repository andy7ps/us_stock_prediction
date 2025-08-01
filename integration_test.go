// +build integration

package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const baseURL = "http://localhost:8080"

func TestHealthEndpoint(t *testing.T) {
	resp, err := http.Get(baseURL + "/api/v1/health")
	require.NoError(t, err)
	defer resp.Body.Close()

	assert.Equal(t, http.StatusOK, resp.StatusCode)

	var health map[string]interface{}
	err = json.NewDecoder(resp.Body).Decode(&health)
	require.NoError(t, err)

	assert.Contains(t, health, "status")
	assert.Contains(t, health, "timestamp")
	assert.Contains(t, health, "version")
}

func TestPredictionEndpoint(t *testing.T) {
	resp, err := http.Get(baseURL + "/api/v1/predict/AAPL")
	require.NoError(t, err)
	defer resp.Body.Close()

	// Should return 200 or 503 (if Yahoo API is down)
	assert.True(t, resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusServiceUnavailable)

	if resp.StatusCode == http.StatusOK {
		var prediction map[string]interface{}
		err = json.NewDecoder(resp.Body).Decode(&prediction)
		require.NoError(t, err)

		assert.Contains(t, prediction, "symbol")
		assert.Contains(t, prediction, "current_price")
		assert.Contains(t, prediction, "predicted_price")
		assert.Contains(t, prediction, "trading_signal")
		assert.Contains(t, prediction, "confidence")
		assert.Equal(t, "AAPL", prediction["symbol"])
	}
}

func TestStatsEndpoint(t *testing.T) {
	resp, err := http.Get(baseURL + "/api/v1/stats")
	require.NoError(t, err)
	defer resp.Body.Close()

	assert.Equal(t, http.StatusOK, resp.StatusCode)

	var stats map[string]interface{}
	err = json.NewDecoder(resp.Body).Decode(&stats)
	require.NoError(t, err)

	assert.Contains(t, stats, "cache")
	assert.Contains(t, stats, "model")
	assert.Contains(t, stats, "system")
}

func TestMetricsEndpoint(t *testing.T) {
	resp, err := http.Get(baseURL + "/metrics")
	require.NoError(t, err)
	defer resp.Body.Close()

	assert.Equal(t, http.StatusOK, resp.StatusCode)
	assert.Equal(t, "text/plain; version=0.0.4; charset=utf-8", resp.Header.Get("Content-Type"))
}

func TestRootEndpoint(t *testing.T) {
	resp, err := http.Get(baseURL + "/")
	require.NoError(t, err)
	defer resp.Body.Close()

	assert.Equal(t, http.StatusOK, resp.StatusCode)

	var root map[string]interface{}
	err = json.NewDecoder(resp.Body).Decode(&root)
	require.NoError(t, err)

	assert.Contains(t, root, "service")
	assert.Contains(t, root, "version")
	assert.Contains(t, root, "endpoints")
	assert.Equal(t, "Stock Prediction API", root["service"])
	assert.Equal(t, "v3.1.0", root["version"])
}

func TestHistoricalDataEndpoint(t *testing.T) {
	resp, err := http.Get(baseURL + "/api/v1/historical/AAPL?days=5")
	require.NoError(t, err)
	defer resp.Body.Close()

	// Should return 200 or 503 (if Yahoo API is down)
	assert.True(t, resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusServiceUnavailable)

	if resp.StatusCode == http.StatusOK {
		var historical map[string]interface{}
		err = json.NewDecoder(resp.Body).Decode(&historical)
		require.NoError(t, err)

		assert.Contains(t, historical, "symbol")
		assert.Contains(t, historical, "days")
		assert.Contains(t, historical, "data")
		assert.Contains(t, historical, "count")
		assert.Equal(t, "AAPL", historical["symbol"])
		assert.Equal(t, float64(5), historical["days"])
	}
}

func TestCacheClearEndpoint(t *testing.T) {
	req, err := http.NewRequest("POST", baseURL+"/api/v1/cache/clear", nil)
	require.NoError(t, err)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()

	assert.Equal(t, http.StatusOK, resp.StatusCode)

	var result map[string]interface{}
	err = json.NewDecoder(resp.Body).Decode(&result)
	require.NoError(t, err)

	assert.Contains(t, result, "message")
	assert.Contains(t, result, "time")
}

func TestInvalidSymbol(t *testing.T) {
	resp, err := http.Get(baseURL + "/api/v1/predict/INVALID123")
	require.NoError(t, err)
	defer resp.Body.Close()

	assert.Equal(t, http.StatusBadRequest, resp.StatusCode)

	var errorResp map[string]interface{}
	err = json.NewDecoder(resp.Body).Decode(&errorResp)
	require.NoError(t, err)

	assert.Contains(t, errorResp, "error")
}

func TestCORS(t *testing.T) {
	req, err := http.NewRequest("OPTIONS", baseURL+"/api/v1/health", nil)
	require.NoError(t, err)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()

	assert.Equal(t, http.StatusOK, resp.StatusCode)
	assert.Equal(t, "*", resp.Header.Get("Access-Control-Allow-Origin"))
	assert.Contains(t, resp.Header.Get("Access-Control-Allow-Methods"), "GET")
}
