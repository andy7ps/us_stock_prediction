import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { StockPredictionService, HistoricalDataItem } from '../services/stock-prediction.service';

@Component({
  selector: 'app-historical-data',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './historical-data.component.html',
  styleUrls: ['./historical-data.component.css']
})
export class HistoricalDataComponent implements OnInit {
  // Make Math available in template
  Math = Math;
  
  // Component state
  selectedSymbol: string = 'NVDA';
  selectedDays: number = 60;
  historicalData: HistoricalDataItem[] = [];
  loading: boolean = false;
  error: string = '';
  
  // Popular stock symbols
  popularSymbols: string[] = [
    'NVDA', 'TSLA', 'AAPL', 'MSFT', 'GOOGL', 'AMZN', 
    'AUR', 'PLTR', 'SMCI', 'TSM', 'MP', 'SMR', 'SPY'
  ];
  
  // Day options
  dayOptions: number[] = [30, 60, 90, 180, 365];
  
  // Pagination
  currentPage: number = 1;
  itemsPerPage: number = 20;
  
  // Sorting
  sortColumn: string = 'date';
  sortDirection: 'asc' | 'desc' = 'desc';
  
  // Statistics
  statistics = {
    avgPrice: 0,
    highestPrice: 0,
    lowestPrice: 0,
    totalVolume: 0,
    priceChange: 0,
    priceChangePercent: 0
  };

  constructor(private stockService: StockPredictionService) {}

  ngOnInit(): void {
    this.loadHistoricalData();
  }

  /**
   * Load historical data for selected symbol
   */
  loadHistoricalData(): void {
    if (!this.selectedSymbol) {
      this.error = 'Please select a stock symbol';
      return;
    }

    this.loading = true;
    this.error = '';

    this.stockService.getHistoricalData(this.selectedSymbol, this.selectedDays)
      .subscribe({
        next: (data) => {
          this.historicalData = this.processHistoricalData(data);
          this.calculateStatistics();
          this.loading = false;
        },
        error: (error) => {
          this.error = error.message || 'Failed to load historical data';
          this.loading = false;
          console.error('Historical data error:', error);
        }
      });
  }

  /**
   * Process and enhance historical data
   */
  private processHistoricalData(data: HistoricalDataItem[]): HistoricalDataItem[] {
    return data.map((item, index) => {
      // Convert timestamp to Date object
      item.date = new Date(item.timestamp);
      
      // Calculate daily change
      if (index < data.length - 1) {
        const previousClose = data[index + 1].close;
        item.change = ((item.close - previousClose) / previousClose) * 100;
      } else {
        item.change = 0;
      }
      
      return item;
    }).sort((a, b) => {
      // Sort by date descending by default
      return new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime();
    });
  }

  /**
   * Calculate statistics for the historical data
   */
  private calculateStatistics(): void {
    if (this.historicalData.length === 0) {
      return;
    }

    const prices = this.historicalData.map(item => item.close);
    const volumes = this.historicalData.map(item => item.volume);
    
    this.statistics.avgPrice = prices.reduce((sum, price) => sum + price, 0) / prices.length;
    this.statistics.highestPrice = Math.max(...prices);
    this.statistics.lowestPrice = Math.min(...prices);
    this.statistics.totalVolume = volumes.reduce((sum, volume) => sum + volume, 0);
    
    // Calculate price change from first to last
    if (this.historicalData.length >= 2) {
      const firstPrice = this.historicalData[this.historicalData.length - 1].close;
      const lastPrice = this.historicalData[0].close;
      this.statistics.priceChange = lastPrice - firstPrice;
      this.statistics.priceChangePercent = (this.statistics.priceChange / firstPrice) * 100;
    }
  }

  /**
   * Handle symbol selection
   */
  onSymbolChange(): void {
    this.currentPage = 1;
    this.loadHistoricalData();
  }

  /**
   * Handle days selection
   */
  onDaysChange(): void {
    this.currentPage = 1;
    this.loadHistoricalData();
  }

  /**
   * Sort data by column
   */
  sortBy(column: string): void {
    if (this.sortColumn === column) {
      this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
    } else {
      this.sortColumn = column;
      this.sortDirection = 'asc';
    }

    this.historicalData.sort((a, b) => {
      let aValue: any;
      let bValue: any;

      switch (column) {
        case 'date':
          aValue = new Date(a.timestamp).getTime();
          bValue = new Date(b.timestamp).getTime();
          break;
        case 'open':
          aValue = a.open;
          bValue = b.open;
          break;
        case 'high':
          aValue = a.high;
          bValue = b.high;
          break;
        case 'low':
          aValue = a.low;
          bValue = b.low;
          break;
        case 'close':
          aValue = a.close;
          bValue = b.close;
          break;
        case 'volume':
          aValue = a.volume;
          bValue = b.volume;
          break;
        case 'change':
          aValue = a.change || 0;
          bValue = b.change || 0;
          break;
        default:
          return 0;
      }

      if (this.sortDirection === 'asc') {
        return aValue > bValue ? 1 : -1;
      } else {
        return aValue < bValue ? 1 : -1;
      }
    });
  }

  /**
   * Get paginated data
   */
  getPaginatedData(): HistoricalDataItem[] {
    const startIndex = (this.currentPage - 1) * this.itemsPerPage;
    const endIndex = startIndex + this.itemsPerPage;
    return this.historicalData.slice(startIndex, endIndex);
  }

  /**
   * Get total pages
   */
  getTotalPages(): number {
    return Math.ceil(this.historicalData.length / this.itemsPerPage);
  }

  /**
   * Go to specific page
   */
  goToPage(page: number): void {
    if (page >= 1 && page <= this.getTotalPages()) {
      this.currentPage = page;
    }
  }

  /**
   * Get page numbers for pagination
   */
  getPageNumbers(): number[] {
    const totalPages = this.getTotalPages();
    const pages: number[] = [];
    const maxVisiblePages = 5;
    
    let startPage = Math.max(1, this.currentPage - Math.floor(maxVisiblePages / 2));
    let endPage = Math.min(totalPages, startPage + maxVisiblePages - 1);
    
    if (endPage - startPage < maxVisiblePages - 1) {
      startPage = Math.max(1, endPage - maxVisiblePages + 1);
    }
    
    for (let i = startPage; i <= endPage; i++) {
      pages.push(i);
    }
    
    return pages;
  }

  /**
   * Format currency
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
   * Format number with commas
   */
  formatNumber(value: number): string {
    return new Intl.NumberFormat('en-US').format(value);
  }

  /**
   * Format percentage
   */
  formatPercentage(value: number): string {
    return `${value >= 0 ? '+' : ''}${value.toFixed(2)}%`;
  }

  /**
   * Get change color class
   */
  getChangeColorClass(change: number): string {
    if (change > 0) return 'text-success';
    if (change < 0) return 'text-danger';
    return 'text-muted';
  }

  /**
   * Export data to CSV
   */
  exportToCSV(): void {
    if (this.historicalData.length === 0) {
      return;
    }

    const headers = ['Date', 'Open', 'High', 'Low', 'Close', 'Volume', 'Change %'];
    const csvContent = [
      headers.join(','),
      ...this.historicalData.map(item => [
        item.date?.toLocaleDateString() || item.timestamp,
        item.open.toFixed(2),
        item.high.toFixed(2),
        item.low.toFixed(2),
        item.close.toFixed(2),
        item.volume,
        (item.change || 0).toFixed(2)
      ].join(','))
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `${this.selectedSymbol}_historical_data_${this.selectedDays}days.csv`;
    link.click();
    window.URL.revokeObjectURL(url);
  }

  /**
   * Refresh data
   */
  refreshData(): void {
    this.loadHistoricalData();
  }

  /**
   * Track by function for ngFor performance
   */
  trackByDate(index: number, item: HistoricalDataItem): string {
    return item.timestamp;
  }
}
