import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface SearchHistoryItem {
  id: number;
  symbol: string;
  search_count: number;
  last_searched_at: string;
}

export interface SearchHistoryResponse {
  history: SearchHistoryItem[];
  popular: SearchHistoryItem[];
  recent: SearchHistoryItem[];
}

@Injectable({
  providedIn: 'root'
})
export class SearchHistoryService {
  private apiUrl = environment.apiUrl || 'http://localhost:8081';

  constructor(private http: HttpClient) {}

  getSearchHistory(): Observable<SearchHistoryResponse> {
    return this.http.get<SearchHistoryResponse>(`${this.apiUrl}/api/v1/search-history`);
  }

  recordSearch(symbol: string): Observable<any> {
    return this.http.post(`${this.apiUrl}/api/v1/search-history`, { symbol });
  }

  getPopularStocks(limit: number = 10): Observable<SearchHistoryItem[]> {
    return this.http.get<SearchHistoryItem[]>(`${this.apiUrl}/api/v1/search-history/popular?limit=${limit}`);
  }

  getRecentSearches(limit: number = 5): Observable<SearchHistoryItem[]> {
    return this.http.get<SearchHistoryItem[]>(`${this.apiUrl}/api/v1/search-history/recent?limit=${limit}`);
  }

  clearSearchHistory(): Observable<any> {
    return this.http.delete(`${this.apiUrl}/api/v1/search-history`);
  }
}
