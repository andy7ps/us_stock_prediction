import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError, retry } from 'rxjs/operators';
import { environment } from '../../environments/environment';

export interface PredictionResponse {
  symbol: string;
  current_price: number;
  predicted_price: number;
  prediction_change: number;
  prediction_change_percent: number;
  confidence: number;
  recommendation: string;
  timestamp: string;
  data_source: string;
  model_version: string;
}

export interface HistoricalData {
  symbol: string;
  data: Array<{
    date: string;
    open: number;
    high: number;
    low: number;
    close: number;
    volume: number;
  }>;
  days: number;
  timestamp: string;
}

export interface ServiceStats {
  uptime: string;
  total_requests: number;
  cache_hit_rate: number;
  average_response_time: string;
  active_symbols: string[];
  last_prediction_time: string;
}

export interface HealthStatus {
  status: string;
  timestamp: string;
  version: string;
  uptime: string;
}

@Injectable({
  providedIn: 'root'
})
export class StockPredictionService {
  // Use environment-specific API URL
  private readonly baseUrl = environment.apiUrl;

  constructor(private http: HttpClient) {
    console.log('StockPredictionService initialized with baseUrl:', this.baseUrl);
  }

  /**
   * Get stock price prediction for a symbol
   */
  getPrediction(symbol: string): Observable<PredictionResponse> {
    return this.http.get<PredictionResponse>(`${this.baseUrl}/predict/${symbol.toUpperCase()}`)
      .pipe(
        retry(2),
        catchError(this.handleError)
      );
  }

  /**
   * Get historical stock data
   */
  getHistoricalData(symbol: string, days: number = 30): Observable<HistoricalData> {
    return this.http.get<HistoricalData>(`${this.baseUrl}/historical/${symbol.toUpperCase()}?days=${days}`)
      .pipe(
        retry(2),
        catchError(this.handleError)
      );
  }

  /**
   * Get service health status
   */
  getHealth(): Observable<HealthStatus> {
    return this.http.get<HealthStatus>(`${this.baseUrl}/health`)
      .pipe(
        catchError(this.handleError)
      );
  }

  /**
   * Get service statistics
   */
  getStats(): Observable<ServiceStats> {
    return this.http.get<ServiceStats>(`${this.baseUrl}/stats`)
      .pipe(
        catchError(this.handleError)
      );
  }

  /**
   * Clear prediction cache
   */
  clearCache(): Observable<any> {
    return this.http.post(`${this.baseUrl}/cache/clear`, {})
      .pipe(
        catchError(this.handleError)
      );
  }

  /**
   * Handle HTTP errors
   */
  private handleError(error: HttpErrorResponse) {
    let errorMessage = 'An unknown error occurred';
    
    if (error.error instanceof ErrorEvent) {
      // Client-side error
      errorMessage = `Client Error: ${error.error.message}`;
    } else {
      // Server-side error
      errorMessage = `Server Error: ${error.status} - ${error.message}`;
      if (error.error && error.error.message) {
        errorMessage += ` - ${error.error.message}`;
      }
    }
    
    console.error('StockPredictionService Error:', errorMessage);
    return throwError(() => new Error(errorMessage));
  }
}
