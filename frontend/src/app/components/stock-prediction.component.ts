import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { StockPredictionService, PredictionResponse, HistoricalData, ServiceStats } from '../services/stock-prediction.service';

@Component({
  selector: 'app-stock-prediction',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './stock-prediction.component.html',
  styleUrls: ['./stock-prediction.component.css']
})
export class StockPredictionComponent implements OnInit {
  stockSymbol: string = 'NVDA';
  prediction: PredictionResponse | null = null;
  historicalData: HistoricalData | null = null;
  serviceStats: ServiceStats | null = null;
  errorMessage: string = '';
  isLoading: boolean = false;
  isLoadingHistorical: boolean = false;
  isClearingCache: boolean = false;
  isRefreshingStats: boolean = false;
  isServiceOnline: boolean = false;
  showHistorical: boolean = false;

  popularStocks: string[] = ['NVDA', 'TSLA', 'AAPL', 'MSFT', 'GOOGL', 'AMZN', 'META', 'NFLX'];

  constructor(private stockService: StockPredictionService) {}

  ngOnInit() {
    this.checkServiceHealth();
    this.loadServiceStats();
  }

  // Track by functions for performance
  trackBySymbol(index: number, symbol: string): string {
    return symbol;
  }

  trackByDate(index: number, item: any): string {
    return item.date;
  }

  checkServiceHealth() {
    this.stockService.getHealth().subscribe({
      next: (health) => {
        this.isServiceOnline = health.status === 'healthy';
      },
      error: (error) => {
        this.isServiceOnline = false;
        console.error('Health check failed:', error);
      }
    });
  }

  loadServiceStats() {
    this.stockService.getStats().subscribe({
      next: (stats) => {
        this.serviceStats = stats;
      },
      error: (error) => {
        console.error('Failed to load service stats:', error);
      }
    });
  }

  selectStock(symbol: string) {
    this.stockSymbol = symbol;
    this.getPrediction();
  }

  getPrediction() {
    if (!this.stockSymbol.trim()) return;

    this.isLoading = true;
    this.errorMessage = '';
    this.prediction = null;
    this.historicalData = null;
    this.showHistorical = false;

    this.stockService.getPrediction(this.stockSymbol).subscribe({
      next: (prediction) => {
        this.prediction = prediction;
        this.isLoading = false;
      },
      error: (error) => {
        this.errorMessage = error.message;
        this.isLoading = false;
      }
    });
  }

  toggleHistoricalData() {
    if (!this.showHistorical && !this.historicalData) {
      this.isLoadingHistorical = true;
      this.stockService.getHistoricalData(this.stockSymbol, 30).subscribe({
        next: (data) => {
          this.historicalData = data;
          this.showHistorical = true;
          this.isLoadingHistorical = false;
        },
        error: (error) => {
          this.errorMessage = `Failed to load historical data: ${error.message}`;
          this.isLoadingHistorical = false;
        }
      });
    } else {
      this.showHistorical = !this.showHistorical;
    }
  }

  clearCache() {
    this.isClearingCache = true;
    this.stockService.clearCache().subscribe({
      next: () => {
        this.isClearingCache = false;
        // Use Bootstrap toast instead of alert
        this.showToast('Cache cleared successfully!', 'success');
      },
      error: (error) => {
        this.isClearingCache = false;
        this.errorMessage = `Failed to clear cache: ${error.message}`;
      }
    });
  }

  refreshStats() {
    this.isRefreshingStats = true;
    this.loadServiceStats();
    this.checkServiceHealth();
    setTimeout(() => {
      this.isRefreshingStats = false;
    }, 1000);
  }

  clearError() {
    this.errorMessage = '';
  }

  getPriceChangeClass(change: number): string {
    return change > 0 ? 'price-positive' : change < 0 ? 'price-negative' : 'price-neutral';
  }

  getRecommendationClass(recommendation: string): string {
    switch (recommendation.toLowerCase()) {
      case 'buy': return 'badge bg-success recommendation-buy';
      case 'sell': return 'badge bg-danger recommendation-sell';
      default: return 'badge bg-warning recommendation-hold';
    }
  }

  getPriceChangeAriaLabel(change: number, changePercent: number): string {
    const direction = change > 0 ? 'increase' : change < 0 ? 'decrease' : 'no change';
    return `Price ${direction} of ${Math.abs(change).toFixed(2)} dollars or ${Math.abs(changePercent).toFixed(2)} percent`;
  }

  formatTimestamp(timestamp: string): string {
    return new Date(timestamp).toLocaleString();
  }

  formatDate(dateStr: string): string {
    return new Date(dateStr).toLocaleDateString();
  }

  formatVolume(volume: number): string {
    if (volume >= 1000000) {
      return (volume / 1000000).toFixed(1) + 'M';
    } else if (volume >= 1000) {
      return (volume / 1000).toFixed(1) + 'K';
    }
    return volume.toString();
  }

  private showToast(message: string, type: 'success' | 'error' | 'info' = 'info') {
    // Simple toast implementation - could be enhanced with Bootstrap Toast component
    console.log(`${type.toUpperCase()}: ${message}`);
  }
}
