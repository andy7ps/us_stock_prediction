import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface CandlestickData {
  time: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume?: number;
}

export interface ChartDataResponse {
  symbol: string;
  data: CandlestickData[];
  count: number;
  time_range: string;
  current_price?: number;
  change?: number;
  change_percent?: number;
}

@Injectable({
  providedIn: 'root'
})
export class ChartDataService {
  private apiUrl = environment.apiUrl || 'http://localhost:8081';

  constructor(private http: HttpClient) {}

  getChartData(symbol: string, timeRange: string = '1M'): Observable<ChartDataResponse> {
    const params = new HttpParams()
      .set('range', timeRange)
      .set('format', 'candlestick');

    return this.http.get<ChartDataResponse>(`${this.apiUrl}/api/v1/chart/${symbol}`, { params });
  }

  getIntradayData(symbol: string, interval: string = '5min'): Observable<ChartDataResponse> {
    const params = new HttpParams()
      .set('interval', interval)
      .set('format', 'candlestick');

    return this.http.get<ChartDataResponse>(`${this.apiUrl}/api/v1/chart/${symbol}/intraday`, { params });
  }

  getCurrentPrice(symbol: string): Observable<any> {
    return this.http.get(`${this.apiUrl}/api/v1/quote/${symbol}`);
  }
}
