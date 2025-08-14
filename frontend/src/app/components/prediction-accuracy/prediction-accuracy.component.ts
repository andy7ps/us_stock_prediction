import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { PredictionTrackingService } from '../../services/prediction-tracking.service';

interface PredictionAccuracySummary {
  symbol: string;
  total_predictions: number;
  predictions_with_actual: number;
  average_accuracy_mape: number;
  direction_accuracy: number;
  average_confidence: number;
  best_accuracy: number;
  worst_accuracy: number;
  last_prediction_date?: string;
}

interface DailyPredictionStatus {
  last_execution_date?: string;
  last_execution_status: string;
  next_scheduled_run?: string;
  is_enabled: boolean;
  total_symbols: number;
  successful_symbols: number;
  failed_symbols: number;
  execution_duration?: number;
  error_message?: string;
}

interface PredictionTracking {
  id: number;
  symbol: string;
  prediction_date: string;
  predicted_price?: number;
  predicted_direction?: string;
  confidence?: number;
  actual_close?: number;
  accuracy_mape?: number;
  direction_correct?: boolean;
  market_was_open: boolean;
  prediction_timestamp: string;
  actual_price_timestamp?: string;
}

@Component({
  selector: 'app-prediction-accuracy',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './prediction-accuracy.component.html',
  styleUrls: ['./prediction-accuracy.component.css']
})
export class PredictionAccuracyComponent implements OnInit {
  accuracySummaries: PredictionAccuracySummary[] = [];
  dailyStatus: DailyPredictionStatus | null = null;
  predictionHistory: PredictionTracking[] = [];
  
  selectedSymbol: string = '';
  startDate: string = '';
  endDate: string = '';
  
  loading = false;
  error: string | null = null;
  
  // Available symbols
  symbols = ['NVDA', 'TSLA', 'AAPL', 'MSFT', 'GOOGL', 'AMZN', 'AUR', 'PLTR', 'SMCI', 'TSM', 'MP', 'SMR', 'SPY'];

  constructor(private predictionTrackingService: PredictionTrackingService) {
    // Set default date range (last 30 days)
    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(endDate.getDate() - 30);
    
    this.endDate = endDate.toISOString().split('T')[0];
    this.startDate = startDate.toISOString().split('T')[0];
  }

  ngOnInit(): void {
    this.loadOverallPerformance();
    this.loadDailyStatus();
  }

  loadOverallPerformance(): void {
    this.loading = true;
    this.error = null;
    
    this.predictionTrackingService.getOverallPerformance().subscribe({
      next: (data) => {
        this.accuracySummaries = data.symbol_summaries || [];
        this.loading = false;
      },
      error: (error) => {
        this.error = 'Failed to load performance data: ' + error.message;
        this.loading = false;
      }
    });
  }

  loadDailyStatus(): void {
    this.predictionTrackingService.getDailyStatus().subscribe({
      next: (status) => {
        this.dailyStatus = status;
      },
      error: (error) => {
        console.error('Failed to load daily status:', error);
      }
    });
  }

  loadPredictionHistory(): void {
    if (!this.selectedSymbol || !this.startDate || !this.endDate) {
      this.error = 'Please select a symbol and date range';
      return;
    }

    this.loading = true;
    this.error = null;

    this.predictionTrackingService.getPredictionHistory(
      this.selectedSymbol,
      this.startDate,
      this.endDate
    ).subscribe({
      next: (history) => {
        this.predictionHistory = history;
        this.loading = false;
      },
      error: (error) => {
        this.error = 'Failed to load prediction history: ' + error.message;
        this.loading = false;
      }
    });
  }

  executeDailyPredictions(): void {
    this.loading = true;
    this.error = null;

    this.predictionTrackingService.executeDailyPredictions().subscribe({
      next: (result) => {
        this.loading = false;
        alert(`Daily predictions executed successfully!\nSuccessful: ${result.successful_predictions}\nFailed: ${result.failed_predictions}`);
        this.loadDailyStatus();
        this.loadOverallPerformance();
      },
      error: (error) => {
        this.error = 'Failed to execute daily predictions: ' + error.message;
        this.loading = false;
      }
    });
  }

  getAccuracyColor(accuracy: number): string {
    if (accuracy <= 2) return 'text-success';
    if (accuracy <= 5) return 'text-warning';
    return 'text-danger';
  }

  getDirectionAccuracyColor(accuracy: number): string {
    if (accuracy >= 70) return 'text-success';
    if (accuracy >= 50) return 'text-warning';
    return 'text-danger';
  }

  formatDate(dateString?: string): string {
    if (!dateString) return 'N/A';
    return new Date(dateString).toLocaleDateString();
  }

  formatDateTime(dateString?: string): string {
    if (!dateString) return 'N/A';
    return new Date(dateString).toLocaleString();
  }

  formatNumber(num?: number, decimals: number = 2): string {
    if (num === undefined || num === null) return 'N/A';
    return num.toFixed(decimals);
  }

  formatPercentage(num?: number): string {
    if (num === undefined || num === null) return 'N/A';
    return num.toFixed(1) + '%';
  }

  getDirectionIcon(direction?: string): string {
    switch (direction) {
      case 'up': return '↗️';
      case 'down': return '↘️';
      case 'hold': return '➡️';
      default: return '❓';
    }
  }

  getDirectionClass(correct?: boolean): string {
    if (correct === undefined || correct === null) return '';
    return correct ? 'text-success' : 'text-danger';
  }
}
