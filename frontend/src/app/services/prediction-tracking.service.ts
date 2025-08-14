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
  private readonly baseUrl: string;

  constructor(private http: HttpClient) {
    // Dynamic API URL resolution based on current hostname (same as StockPredictionService)
    this.baseUrl = this.getApiUrl();
    console.log('PredictionTrackingService initialized with baseUrl:', this.baseUrl);
  }

  /**
   * Get dynamic API URL based on current hostname
   */
  private getApiUrl(): string {
    if (environment.apiUrl === 'dynamic') {
      // Use current hostname with backend port
      const hostname = window.location.hostname;
      const protocol = window.location.protocol;
      return `${protocol}//${hostname}:8081/api/v1`;
    }
    return environment.apiUrl;
  }

  // Accuracy tracking endpoints
  getAccuracySummary(symbol?: string): Observable<PredictionAccuracySummary> {
    const url = symbol 
      ? `${this.baseUrl}/predictions/accuracy/${symbol}`
      : `${this.baseUrl}/predictions/accuracy/summary`;
    return this.http.get<PredictionAccuracySummary>(url);
  }

  getPerformanceMetrics(): Observable<PredictionPerformanceMetrics> {
    return this.http.get<PredictionPerformanceMetrics>(`${this.baseUrl}/predictions/performance`);
  }

  getPredictionHistory(symbol: string, startDate?: string, endDate?: string): Observable<PredictionTracking[]> {
    let params = new HttpParams();
    if (startDate) params = params.set('start_date', startDate);
    if (endDate) params = params.set('end_date', endDate);
    
    return this.http.get<PredictionTracking[]>(`${this.baseUrl}/predictions/history/${symbol}`, { params });
  }

  // Daily prediction endpoints
  executeDailyPredictions(request?: DailyPredictionRequest): Observable<DailyExecutionLog> {
    const payload = request || { execution_type: 'manual' };
    return this.http.post<DailyExecutionLog>(`${this.baseUrl}/predictions/daily-run`, payload);
  }

  getDailyStatus(): Observable<DailyPredictionStatus> {
    return this.http.get<DailyPredictionStatus>(`${this.baseUrl}/predictions/daily-status`);
  }

  // Data management endpoints
  updateActualPrice(request: UpdateActualPriceRequest): Observable<any> {
    return this.http.post(`${this.baseUrl}/predictions/update-actual`, request);
  }

  // Utility methods for date range queries
  getAccuracyRange(startDate: string, endDate: string, symbol?: string): Observable<PredictionAccuracySummary[]> {
    let params = new HttpParams()
      .set('start_date', startDate)
      .set('end_date', endDate);
    
    if (symbol) params = params.set('symbol', symbol);
    
    return this.http.get<PredictionAccuracySummary[]>(`${this.baseUrl}/predictions/accuracy/range`, { params });
  }

  getTrendAnalysis(symbol: string, days: number = 30): Observable<any> {
    const params = new HttpParams().set('days', days.toString());
    return this.http.get(`${this.baseUrl}/predictions/trends/${symbol}`, { params });
  }

  getTopPerformers(limit: number = 10): Observable<PredictionAccuracySummary[]> {
    const params = new HttpParams().set('limit', limit.toString());
    return this.http.get<PredictionAccuracySummary[]>(`${this.baseUrl}/predictions/top-performers`, { params });
  }
}
