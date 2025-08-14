import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { StockPredictionService, PredictionResponse, HistoricalDataItem, ServiceStats } from '../services/stock-prediction.service';

@Component({
  selector: 'app-stock-prediction',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './stock-prediction.component.html',
  styleUrls: ['./stock-prediction.component.css']
})
export class StockPredictionComponent implements OnInit {
  stockSymbol: string = 'NVDA';
  predictionResult: PredictionResponse | null = null;
  historicalData: HistoricalDataItem[] = [];
  serviceStats: ServiceStats | null = null;
  errorMessage: string = '';
  isLoading: boolean = false;
  isLoadingHistorical: boolean = false;
  isServiceOnline: boolean = false;

  // Popular stock symbols for quick selection
  popularSymbols: string[] = [
    'NVDA', 'TSLA', 'AAPL', 'MSFT', 'GOOGL', 'AMZN', 
    'AUR', 'PLTR', 'SMCI', 'TSM', 'MP', 'SMR', 'SPY', 
    'AMD', 'META', 'NOC', 'RTX', 'LMT'
  ];

  constructor(private stockService: StockPredictionService) {}

  ngOnInit() {
    this.checkServiceHealth();
    this.loadServiceStats();
  }

  /**
   * Check service health status
   */
  checkServiceHealth() {
    this.stockService.getHealth().subscribe({
      next: (health) => {
        this.isServiceOnline = health.status === 'healthy';
      },
      error: (error) => {
        this.isServiceOnline = false;
        console.error('Service health check failed:', error);
      }
    });
  }

  /**
   * Load service statistics
   */
  loadServiceStats() {
    this.stockService.getStats().subscribe({
      next: (stats) => {
        this.serviceStats = {
          ...stats,
          response_time: stats.average_response_time // Add alias
        };
      },
      error: (error) => {
        console.error('Failed to load service stats:', error);
      }
    });
  }

  /**
   * Get stock prediction
   */
  getPrediction() {
    if (!this.stockSymbol || this.isLoading) {
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';
    this.predictionResult = null;

    this.stockService.getPrediction(this.stockSymbol.toUpperCase()).subscribe({
      next: (prediction) => {
        this.predictionResult = {
          ...prediction,
          signal: prediction.trading_signal, // Add alias
          timestamp: new Date(prediction.prediction_time) // Convert to Date
        };
        this.isLoading = false;
      },
      error: (error) => {
        this.errorMessage = error.message || 'Failed to get prediction. Please try again.';
        this.isLoading = false;
        console.error('Prediction error:', error);
      }
    });
  }

  /**
   * Select a popular symbol
   */
  selectSymbol(symbol: string) {
    this.stockSymbol = symbol;
    this.getPrediction();
  }

  /**
   * Get historical data
   */
  getHistoricalData() {
    if (!this.stockSymbol || this.isLoadingHistorical) {
      return;
    }

    this.isLoadingHistorical = true;
    this.historicalData = [];

    this.stockService.getHistoricalData(this.stockSymbol.toUpperCase()).subscribe({
      next: (data) => {
        // Transform the data to include calculated fields
        this.historicalData = data.map((item: HistoricalDataItem, index: number) => ({
          ...item,
          date: new Date(item.timestamp),
          change: index > 0 ? ((item.close - data[index - 1].close) / data[index - 1].close) * 100 : 0
        }));
        this.isLoadingHistorical = false;
      },
      error: (error) => {
        this.errorMessage = error.message || 'Failed to get historical data. Please try again.';
        this.isLoadingHistorical = false;
        console.error('Historical data error:', error);
      }
    });
  }

  /**
   * Refresh prediction
   */
  refreshPrediction() {
    this.getPrediction();
  }

  /**
   * Export data to CSV
   */
  exportData() {
    if (!this.predictionResult) {
      return;
    }

    const data = {
      symbol: this.predictionResult.symbol,
      current_price: this.predictionResult.current_price,
      predicted_price: this.predictionResult.predicted_price,
      signal: this.predictionResult.signal || this.predictionResult.trading_signal,
      confidence: this.predictionResult.confidence,
      timestamp: new Date().toISOString()
    };

    const csvContent = "data:text/csv;charset=utf-8," 
      + Object.keys(data).join(",") + "\n"
      + Object.values(data).join(",");

    const encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", `${this.stockSymbol}_prediction.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  /**
   * Clear all results
   */
  clearResults() {
    this.predictionResult = null;
    this.historicalData = [];
    this.errorMessage = '';
    this.stockSymbol = '';
  }

  /**
   * Calculate price change percentage
   */
  getPriceChange(): number {
    if (!this.predictionResult) {
      return 0;
    }
    return ((this.predictionResult.predicted_price - this.predictionResult.current_price) / this.predictionResult.current_price) * 100;
  }

  /**
   * Get recommendation title based on signal
   */
  getRecommendationTitle(): string {
    if (!this.predictionResult) {
      return '';
    }

    const signal = this.predictionResult.signal || this.predictionResult.trading_signal;
    switch (signal) {
      case 'BUY':
        return 'Strong Buy Recommendation';
      case 'SELL':
        return 'Sell Recommendation';
      case 'HOLD':
        return 'Hold Position';
      default:
        return 'No Clear Signal';
    }
  }

  /**
   * Get recommendation text based on signal and confidence
   */
  getRecommendationText(): string {
    if (!this.predictionResult) {
      return '';
    }

    const confidence = Math.round(this.predictionResult.confidence * 100);
    const priceChange = this.getPriceChange();
    const signal = this.predictionResult.signal || this.predictionResult.trading_signal;

    switch (signal) {
      case 'BUY':
        return `Our ML model predicts a ${Math.abs(priceChange).toFixed(2)}% price increase with ${confidence}% confidence. Consider buying if this aligns with your investment strategy.`;
      case 'SELL':
        return `Our ML model predicts a ${Math.abs(priceChange).toFixed(2)}% price decrease with ${confidence}% confidence. Consider selling to minimize potential losses.`;
      case 'HOLD':
        return `Our ML model suggests minimal price movement (${Math.abs(priceChange).toFixed(2)}%) with ${confidence}% confidence. Consider holding your current position.`;
      default:
        return 'Unable to generate a clear recommendation based on current market data.';
    }
  }

  /**
   * Get risk level based on confidence and volatility
   */
  getRiskLevel(): string {
    if (!this.predictionResult) {
      return 'Unknown';
    }

    const confidence = this.predictionResult.confidence;
    const priceChange = Math.abs(this.getPriceChange());

    if (confidence >= 0.7 && priceChange <= 5) {
      return 'Low';
    } else if (confidence >= 0.5 && priceChange <= 10) {
      return 'Medium';
    } else {
      return 'High';
    }
  }

  /**
   * Get risk percentage for progress bar
   */
  getRiskPercentage(): number {
    const riskLevel = this.getRiskLevel();
    switch (riskLevel) {
      case 'Low':
        return 30;
      case 'Medium':
        return 65;
      case 'High':
        return 90;
      default:
        return 50;
    }
  }

  /**
   * Format currency values
   */
  formatCurrency(value: number): string {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(value);
  }

  /**
   * Format percentage values
   */
  formatPercentage(value: number): string {
    return new Intl.NumberFormat('en-US', {
      style: 'percent',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(value / 100);
  }

  /**
   * Get signal color class
   */
  getSignalColorClass(): string {
    if (!this.predictionResult) {
      return 'text-muted';
    }

    const signal = this.predictionResult.signal || this.predictionResult.trading_signal;
    switch (signal) {
      case 'BUY':
        return 'text-success';
      case 'SELL':
        return 'text-danger';
      case 'HOLD':
        return 'text-warning';
      default:
        return 'text-muted';
    }
  }

  /**
   * Get confidence color class
   */
  getConfidenceColorClass(): string {
    if (!this.predictionResult) {
      return 'bg-secondary';
    }

    const confidence = this.predictionResult.confidence;
    if (confidence >= 0.7) {
      return 'bg-success';
    } else if (confidence >= 0.5) {
      return 'bg-warning';
    } else {
      return 'bg-danger';
    }
  }

  /**
   * Track by functions for performance optimization
   */
  trackBySymbol(index: number, symbol: string): string {
    return symbol;
  }

  trackByDate(index: number, item: HistoricalDataItem): string {
    return item.timestamp;
  }
}
