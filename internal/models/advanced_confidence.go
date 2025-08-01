package models

import (
	"math"
)

// CalculateAdvancedConfidence calculates prediction confidence using multiple factors
// including historical volatility and trend analysis
func CalculateAdvancedConfidence(currentPrice, predictedPrice float64, historicalPrices []float64) float64 {
	if len(historicalPrices) < 3 {
		// Fallback to enhanced simple calculation if insufficient data
		return CalculateConfidence(currentPrice, predictedPrice)
	}
	
	// Factor 1: Price change magnitude (25% weight)
	priceChangeFactor := calculatePriceChangeFactor(currentPrice, predictedPrice)
	
	// Factor 2: Historical volatility (35% weight)
	volatilityFactor := calculateVolatilityFactor(historicalPrices)
	
	// Factor 3: Trend alignment (25% weight)
	trendFactor := calculateTrendAlignmentFactor(historicalPrices, currentPrice, predictedPrice)
	
	// Factor 4: Price momentum (15% weight)
	momentumFactor := calculateMomentumFactor(historicalPrices, currentPrice, predictedPrice)
	
	// Weighted combination
	confidence := priceChangeFactor*0.25 + volatilityFactor*0.35 + trendFactor*0.25 + momentumFactor*0.15
	
	// Ensure confidence is in reasonable range
	return math.Max(0.15, math.Min(0.95, confidence))
}

// calculatePriceChangeFactor evaluates confidence based on predicted price change magnitude
func calculatePriceChangeFactor(currentPrice, predictedPrice float64) float64 {
	priceChange := math.Abs(predictedPrice-currentPrice) / currentPrice
	
	// Exponential decay with market-aware adjustments
	factor := math.Exp(-priceChange * 6)
	
	// Boost confidence for moderate changes (0.5% - 4%)
	if priceChange >= 0.005 && priceChange <= 0.04 {
		factor *= 1.15
	}
	
	// Penalize very small changes (might be noise)
	if priceChange < 0.002 {
		factor *= 0.75
	}
	
	// Heavily penalize extreme changes (> 8%)
	if priceChange > 0.08 {
		factor *= 0.5
	}
	
	return math.Max(0.1, math.Min(0.95, factor))
}

// calculateVolatilityFactor evaluates confidence based on historical price volatility
func calculateVolatilityFactor(prices []float64) float64 {
	if len(prices) < 2 {
		return 0.5
	}
	
	// Use recent data (last 10 points or all if less)
	recentPrices := prices
	if len(prices) > 10 {
		recentPrices = prices[len(prices)-10:]
	}
	
	// Calculate daily returns
	returns := make([]float64, len(recentPrices)-1)
	for i := 1; i < len(recentPrices); i++ {
		returns[i-1] = (recentPrices[i] - recentPrices[i-1]) / recentPrices[i-1]
	}
	
	// Calculate volatility (standard deviation of returns)
	volatility := calculateStandardDeviation(returns)
	
	// Convert volatility to confidence factor
	// Lower volatility = higher confidence
	// Typical daily volatility ranges: 0.01-0.05 (1%-5%)
	factor := math.Exp(-volatility * 12)
	
	// Adjust for very low or very high volatility
	if volatility < 0.005 { // Very low volatility (< 0.5%)
		factor *= 0.9 // Slightly reduce confidence (might indicate stale data)
	} else if volatility > 0.08 { // Very high volatility (> 8%)
		factor *= 0.6 // Significantly reduce confidence
	}
	
	return math.Max(0.1, math.Min(0.95, factor))
}

// calculateTrendAlignmentFactor evaluates how well the prediction aligns with recent trends
func calculateTrendAlignmentFactor(prices []float64, currentPrice, predictedPrice float64) float64 {
	if len(prices) < 3 {
		return 0.5
	}
	
	// Analyze short-term trend (last 3-5 points)
	shortTermTrend := analyzeShortTermTrend(prices)
	
	// Analyze medium-term trend (last 5-10 points)
	mediumTermTrend := analyzeMediumTermTrend(prices)
	
	// Determine prediction direction
	predictionDirection := getPredictionDirection(currentPrice, predictedPrice)
	
	// Calculate alignment scores
	shortTermAlignment := calculateDirectionAlignment(shortTermTrend, predictionDirection)
	mediumTermAlignment := calculateDirectionAlignment(mediumTermTrend, predictionDirection)
	
	// Weight short-term trend more heavily (60% vs 40%)
	alignmentScore := shortTermAlignment*0.6 + mediumTermAlignment*0.4
	
	// Boost confidence if both trends agree
	if shortTermTrend == mediumTermTrend && shortTermTrend != "neutral" {
		alignmentScore *= 1.1
	}
	
	return math.Max(0.2, math.Min(0.9, alignmentScore))
}

// calculateMomentumFactor evaluates price momentum and acceleration
func calculateMomentumFactor(prices []float64, currentPrice, predictedPrice float64) float64 {
	if len(prices) < 4 {
		return 0.5
	}
	
	// Calculate recent price momentum
	recentPrices := prices
	if len(prices) > 6 {
		recentPrices = prices[len(prices)-6:]
	}
	
	// Calculate momentum (rate of change acceleration)
	momentum := calculatePriceMomentum(recentPrices)
	predictionDirection := getPredictionDirection(currentPrice, predictedPrice)
	
	// Higher confidence when prediction aligns with momentum
	if (momentum > 0.001 && predictionDirection == "up") ||
		(momentum < -0.001 && predictionDirection == "down") {
		return 0.8 // High confidence - momentum alignment
	} else if math.Abs(momentum) < 0.001 {
		return 0.5 // Neutral momentum
	} else {
		return 0.3 // Low confidence - against momentum
	}
}

// Helper functions

func analyzeShortTermTrend(prices []float64) string {
	if len(prices) < 3 {
		return "neutral"
	}
	
	// Use last 3-4 points
	recent := prices
	if len(prices) > 4 {
		recent = prices[len(prices)-4:]
	}
	
	upMoves := 0
	downMoves := 0
	
	for i := 1; i < len(recent); i++ {
		if recent[i] > recent[i-1]*1.001 { // > 0.1% increase
			upMoves++
		} else if recent[i] < recent[i-1]*0.999 { // > 0.1% decrease
			downMoves++
		}
	}
	
	if upMoves > downMoves {
		return "up"
	} else if downMoves > upMoves {
		return "down"
	}
	return "neutral"
}

func analyzeMediumTermTrend(prices []float64) string {
	if len(prices) < 5 {
		return "neutral"
	}
	
	// Use last 5-8 points
	recent := prices
	if len(prices) > 8 {
		recent = prices[len(prices)-8:]
	}
	
	// Calculate linear regression slope
	n := len(recent)
	sumX, sumY, sumXY, sumX2 := 0.0, 0.0, 0.0, 0.0
	
	for i, price := range recent {
		x := float64(i)
		sumX += x
		sumY += price
		sumXY += x * price
		sumX2 += x * x
	}
	
	slope := (float64(n)*sumXY - sumX*sumY) / (float64(n)*sumX2 - sumX*sumX)
	
	// Normalize slope by average price
	avgPrice := sumY / float64(n)
	normalizedSlope := slope / avgPrice
	
	if normalizedSlope > 0.002 { // > 0.2% per period
		return "up"
	} else if normalizedSlope < -0.002 { // < -0.2% per period
		return "down"
	}
	return "neutral"
}

func getPredictionDirection(currentPrice, predictedPrice float64) string {
	changeThreshold := 0.003 // 0.3%
	change := (predictedPrice - currentPrice) / currentPrice
	
	if change > changeThreshold {
		return "up"
	} else if change < -changeThreshold {
		return "down"
	}
	return "neutral"
}

func calculateDirectionAlignment(trendDirection, predictionDirection string) float64 {
	if trendDirection == predictionDirection && trendDirection != "neutral" {
		return 0.85 // High alignment
	} else if trendDirection == "neutral" || predictionDirection == "neutral" {
		return 0.5 // Neutral
	} else {
		return 0.25 // Opposing directions
	}
}

func calculatePriceMomentum(prices []float64) float64 {
	if len(prices) < 3 {
		return 0
	}
	
	// Calculate acceleration (second derivative)
	changes := make([]float64, len(prices)-1)
	for i := 1; i < len(prices); i++ {
		changes[i-1] = (prices[i] - prices[i-1]) / prices[i-1]
	}
	
	if len(changes) < 2 {
		return 0
	}
	
	// Calculate change in changes (acceleration)
	accelerations := make([]float64, len(changes)-1)
	for i := 1; i < len(changes); i++ {
		accelerations[i-1] = changes[i] - changes[i-1]
	}
	
	// Return average acceleration
	sum := 0.0
	for _, acc := range accelerations {
		sum += acc
	}
	
	return sum / float64(len(accelerations))
}

func calculateStandardDeviation(values []float64) float64 {
	if len(values) <= 1 {
		return 0
	}
	
	// Calculate mean
	mean := 0.0
	for _, v := range values {
		mean += v
	}
	mean /= float64(len(values))
	
	// Calculate variance
	variance := 0.0
	for _, v := range values {
		variance += math.Pow(v-mean, 2)
	}
	variance /= float64(len(values) - 1)
	
	return math.Sqrt(variance)
}
