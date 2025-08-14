import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError, retry, map } from 'rxjs/operators';

export interface PredictionResponse {
  symbol: string;
  current_price: number;
  predicted_price: number;
  trading_signal: string; // Backend uses 'trading_signal'
  confidence: number;
  prediction_time: string; // Backend uses 'prediction_time'
  model_version: string;
  // Extended properties for UI
  signal?: string; // Alias for trading_signal
  timestamp?: Date; // Converted from prediction_time
}

export interface HistoricalDataItem {
  symbol: string;
  timestamp: string; // Backend uses 'timestamp'
  date?: Date; // Converted from timestamp
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
  change?: number; // Calculated field
}

export interface HistoricalData {
  symbol: string;
  count: number; // Backend includes count
  days: number;  // Backend includes days
  data: HistoricalDataItem[];
}

export interface ServiceStats {
  uptime: string;
  total_requests: number;
  cache_hit_rate: number;
  average_response_time: string;
  active_symbols: string[];
  last_prediction_time: string;
  response_time?: string; // Alias for average_response_time
}

export interface HealthStatus {
  status: string;
  timestamp: string;
  version: string;
  services: {
    prediction_service: string;
    yahoo_api: string;
  };
}

@Injectable({
  providedIn: 'root'
})
export class StockPredictionService {
  private apiUrl = this.getApiUrl();

  constructor(private http: HttpClient) {}

  private getApiUrl(): string {
    // Dynamic hostname detection for Docker deployments
    const hostname = window.location.hostname;
    const port = '8081'; // Backend API port
    return `http://${hostname}:${port}`;
  }

  /**
   * Get stock prediction
   */
  getPrediction(symbol: string): Observable<PredictionResponse> {
    return this.http.get<PredictionResponse>(`${this.apiUrl}/api/v1/predict/${symbol}`)
      .pipe(
        retry(2),
        catchError(this.handleError)
      );
  }

  /**
   * Get historical stock data
   */
  getHistoricalData(symbol: string, days: number = 60): Observable<HistoricalDataItem[]> {
    return this.http.get<HistoricalData>(`${this.apiUrl}/api/v1/historical/${symbol}?days=${days}`)
      .pipe(
        retry(2),
        catchError(this.handleError),
        // Transform the response to return just the data array
        map((response: HistoricalData) => response.data || [])
      );
  }

  /**
   * Get service health status
   */
  getHealth(): Observable<HealthStatus> {
    return this.http.get<HealthStatus>(`${this.apiUrl}/api/v1/health`)
      .pipe(
        retry(2),
        catchError(this.handleError)
      );
  }

  /**
   * Get service statistics
   */
  getStats(): Observable<ServiceStats> {
    return this.http.get<ServiceStats>(`${this.apiUrl}/api/v1/stats`)
      .pipe(
        retry(2),
        catchError(this.handleError)
      );
  }

  /**
   * Clear prediction cache
   */
  clearCache(): Observable<any> {
    return this.http.post(`${this.apiUrl}/api/v1/cache/clear`, {})
      .pipe(
        retry(1),
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
      errorMessage = `Error: ${error.error.message}`;
    } else {
      // Server-side error
      errorMessage = `Error Code: ${error.status}\nMessage: ${error.message}`;
      
      // Provide more specific error messages
      switch (error.status) {
        case 0:
          errorMessage = 'Unable to connect to the prediction service. Please check if the service is running.';
          break;
        case 404:
          errorMessage = 'Stock symbol not found or prediction service unavailable.';
          break;
        case 429:
          errorMessage = 'Too many requests. Please wait a moment before trying again.';
          break;
        case 500:
          errorMessage = 'Internal server error. The prediction service is experiencing issues.';
          break;
        case 503:
          errorMessage = 'Prediction service is temporarily unavailable. Please try again later.';
          break;
      }
    }

    console.error('StockPredictionService Error:', error);
    return throwError(() => new Error(errorMessage));
  }
}
