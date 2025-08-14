import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface PredictionAccuracySummary {
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

export interface PredictionPerformanceMetrics {
  total_symbols: number;
  total_predictions: number;
  predictions_with_actual: number;
  overall_accuracy_mape: number;
  overall_direction_accuracy: number;
  symbol_summaries: PredictionAccuracySummary[];
  last_execution_date?: string;
  last_execution_status: string;
}

export interface DailyPredictionStatus {
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

export interface PredictionTracking {
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
  created_at: string;
  updated_at: string;
}

export interface DailyExecutionLog {
  id: number;
  execution_date: string;
  execution_type: string;
  symbols_processed?: string;
  symbols_succeeded?: string;
  symbols_failed?: string;
  total_symbols: number;
  successful_predictions: number;
  failed_predictions: number;
  execution_duration_ms?: number;
  error_message?: string;
  status: string;
  created_at: string;
  completed_at?: string;
}

export interface DailyPredictionRequest {
  symbols?: string[];
  date?: string;
  force_execute?: boolean;
  execution_type?: string;
}

export interface UpdateActualPriceRequest {
  symbol: string;
  date: string;
  actual_close: number;
}

@Injectable({
  providedIn: 'root'
})
export class PredictionTrackingService {
  private baseUrl: string;

  constructor(private http: HttpClient) {
    // Get the current hostname and port for dynamic API URL
    const hostname = window.location.hostname;
    const port = hostname === 'localhost' ? '8081' : '8081'; // Adjust port as needed
    this.baseUrl = `http://${hostname}:${port}/api/v1`;
  }

  // Daily prediction endpoints
  executeDailyPredictions(request?: DailyPredictionRequest): Observable<DailyExecutionLog> {
    const payload = request || { execution_type: 'manual' };
    return this.http.post<DailyExecutionLog>(`${this.baseUrl}/predictions/daily-run`, payload);
  }

  getDailyStatus(): Observable<DailyPredictionStatus> {
    return this.http.get<DailyPredictionStatus>(`${this.baseUrl}/predictions/daily-status`);
  }

  // Accuracy tracking endpoints
  getAccuracySummary(symbol: string): Observable<PredictionAccuracySummary> {
    return this.http.get<PredictionAccuracySummary>(`${this.baseUrl}/predictions/accuracy/${symbol}`);
  }

  getOverallPerformance(): Observable<PredictionPerformanceMetrics> {
    return this.http.get<PredictionPerformanceMetrics>(`${this.baseUrl}/predictions/accuracy/summary`);
  }

  getAccuracyRange(startDate: string, endDate: string, symbols?: string[]): Observable<PredictionTracking[]> {
    let params = new HttpParams()
      .set('start_date', startDate)
      .set('end_date', endDate);

    if (symbols && symbols.length > 0) {
      params = params.set('symbols', JSON.stringify(symbols));
    }

    return this.http.get<PredictionTracking[]>(`${this.baseUrl}/predictions/accuracy/range`, { params });
  }

  // Historical data endpoints
  getPredictionHistory(
    symbol: string,
    startDate?: string,
    endDate?: string,
    limit?: number,
    offset?: number
  ): Observable<PredictionTracking[]> {
    let params = new HttpParams();

    if (startDate) params = params.set('start_date', startDate);
    if (endDate) params = params.set('end_date', endDate);
    if (limit) params = params.set('limit', limit.toString());
    if (offset) params = params.set('offset', offset.toString());

    return this.http.get<PredictionTracking[]>(`${this.baseUrl}/predictions/history/${symbol}`, { params });
  }

  getAllPredictionHistory(
    startDate?: string,
    endDate?: string,
    limit?: number,
    offset?: number
  ): Observable<PredictionTracking[]> {
    let params = new HttpParams();

    if (startDate) params = params.set('start_date', startDate);
    if (endDate) params = params.set('end_date', endDate);
    if (limit) params = params.set('limit', limit.toString());
    if (offset) params = params.set('offset', offset.toString());

    return this.http.get<PredictionTracking[]>(`${this.baseUrl}/predictions/history`, { params });
  }

  updateActualPrice(request: UpdateActualPriceRequest): Observable<{ status: string }> {
    return this.http.post<{ status: string }>(`${this.baseUrl}/predictions/update-actual`, request);
  }

  getPerformanceMetrics(): Observable<PredictionPerformanceMetrics> {
    return this.http.get<PredictionPerformanceMetrics>(`${this.baseUrl}/predictions/performance`);
  }

  // Trends and analytics
  getAccuracyTrends(symbol: string, days?: number): Observable<any> {
    let params = new HttpParams();
    if (days) params = params.set('days', days.toString());

    return this.http.get<any>(`${this.baseUrl}/predictions/trends/${symbol}`, { params });
  }

  getTopPerformers(limit?: number): Observable<PredictionAccuracySummary[]> {
    let params = new HttpParams();
    if (limit) params = params.set('limit', limit.toString());

    return this.http.get<PredictionAccuracySummary[]>(`${this.baseUrl}/predictions/top-performers`, { params });
  }

  // Utility methods
  formatAccuracy(accuracy?: number): string {
    if (accuracy === undefined || accuracy === null) return 'N/A';
    return `${accuracy.toFixed(2)}%`;
  }

  formatPercentage(value?: number): string {
    if (value === undefined || value === null) return 'N/A';
    return `${(value * 100).toFixed(1)}%`;
  }

  formatCurrency(value?: number): string {
    if (value === undefined || value === null) return 'N/A';
    return `$${value.toFixed(2)}`;
  }

  formatDate(dateString?: string): string {
    if (!dateString) return 'N/A';
    return new Date(dateString).toLocaleDateString();
  }

  formatDateTime(dateString?: string): string {
    if (!dateString) return 'N/A';
    return new Date(dateString).toLocaleString();
  }

  getAccuracyColor(accuracy: number): string {
    if (accuracy <= 2) return 'success';
    if (accuracy <= 5) return 'warning';
    return 'danger';
  }

  getDirectionAccuracyColor(accuracy: number): string {
    if (accuracy >= 70) return 'success';
    if (accuracy >= 50) return 'warning';
    return 'danger';
  }

  getStatusColor(status: string): string {
    switch (status.toLowerCase()) {
      case 'completed': return 'success';
      case 'running': return 'info';
      case 'failed': return 'danger';
      case 'pending': return 'warning';
      default: return 'secondary';
    }
  }

  getDirectionIcon(direction?: string): string {
    switch (direction) {
      case 'up': return '↗️';
      case 'down': return '↘️';
      case 'hold': return '➡️';
      default: return '❓';
    }
  }
}
