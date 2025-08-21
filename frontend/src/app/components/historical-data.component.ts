import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { StockPredictionService, HistoricalData } from '../services/stock-prediction.service';

interface HistoricalDataItem {
  symbol: string;
  timestamp: string;
  date?: Date; // For template compatibility
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
  // Computed fields for display
  change?: number;
  changePercent?: number;
  changeClass?: string;
  changeIcon?: string;
}

interface Statistics {
  average: number;
  highest: number;
  lowest: number;
  totalChange: number;
  totalChangePercent: number;
  // Additional properties for template compatibility
  avgPrice: number;
  highestPrice: number;
  lowestPrice: number;
  priceChange: number;
  priceChangePercent: number;
}

@Component({
  selector: 'app-historical-data',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './historical-data.component.html',
  styleUrls: ['./historical-data.component.css']
})
export class HistoricalDataComponent implements OnInit {
  selectedSymbol = 'NVDA';
  selectedDays = 30;
  historicalData: HistoricalDataItem[] = [];
  statistics: Statistics = { 
    average: 0, 
    highest: 0, 
    lowest: 0, 
    totalChange: 0, 
    totalChangePercent: 0,
    avgPrice: 0,
    highestPrice: 0,
    lowestPrice: 0,
    priceChange: 0,
    priceChangePercent: 0
  };
  isLoading = false;
  error = '';
  
  // Pagination
  currentPage = 1;
  itemsPerPage = 20;
  totalItems = 0;
  
  // Sorting
  sortColumn = 'timestamp';
  sortDirection: 'asc' | 'desc' = 'desc';

  symbols = [
    'NVDA', 'TSLA', 'AAPL', 'MSFT', 'GOOGL', 'AMZN', 
    'AUR', 'PLTR', 'SMCI', 'TSM', 'MP', 'SMR', 'SPY'
  ];
  
  // Template compatibility aliases
  get popularSymbols() { return this.symbols; }
  get loading() { return this.isLoading; }
  
  dayOptions = [30, 60, 90, 180, 365];

  // Make Math available in template
  Math = Math;

  constructor(private stockService: StockPredictionService) {}

  ngOnInit() {
    this.loadHistoricalData();
  }

  loadHistoricalData() {
    this.isLoading = true;
    this.error = '';
    
    this.stockService.getHistoricalData(this.selectedSymbol, this.selectedDays)
      .subscribe({
        next: (data: HistoricalDataItem[]) => {
          this.historicalData = this.processHistoricalData(data);
          this.calculateStatistics();
          this.totalItems = this.historicalData.length;
          this.isLoading = false;
        },
        error: (error: any) => {
          this.error = 'Failed to load historical data. Please try again.';
          this.isLoading = false;
          console.error('Error loading historical data:', error);
        }
      });
  }

  processHistoricalData(data: HistoricalDataItem[]): HistoricalDataItem[] {
    return data.map((item, index, array) => {
      const processed: HistoricalDataItem = { ...item };
      
      // Add date property for template compatibility
      processed.date = new Date(item.timestamp);
      
      // Calculate change from previous day
      if (index < array.length - 1) {
        const previousClose = array[index + 1].close;
        processed.change = item.close - previousClose;
        processed.changePercent = (processed.change / previousClose) * 100;
        processed.changeClass = processed.change >= 0 ? 'text-success' : 'text-danger';
        processed.changeIcon = processed.change >= 0 ? 'fa-arrow-up' : 'fa-arrow-down';
      }
      
      return processed;
    });
  }

  calculateStatistics() {
    if (this.historicalData.length === 0) return;
    
    const prices = this.historicalData.map(item => item.close);
    this.statistics.average = prices.reduce((sum, price) => sum + price, 0) / prices.length;
    this.statistics.highest = Math.max(...prices);
    this.statistics.lowest = Math.min(...prices);
    
    // Template compatibility aliases
    this.statistics.avgPrice = this.statistics.average;
    this.statistics.highestPrice = this.statistics.highest;
    this.statistics.lowestPrice = this.statistics.lowest;
    
    if (this.historicalData.length > 1) {
      const firstPrice = this.historicalData[this.historicalData.length - 1].close;
      const lastPrice = this.historicalData[0].close;
      this.statistics.totalChange = lastPrice - firstPrice;
      this.statistics.totalChangePercent = (this.statistics.totalChange / firstPrice) * 100;
      
      // Template compatibility aliases
      this.statistics.priceChange = this.statistics.totalChange;
      this.statistics.priceChangePercent = this.statistics.totalChangePercent;
    }
  }

  onSymbolChange() {
    this.currentPage = 1;
    this.loadHistoricalData();
  }

  onDaysChange() {
    this.currentPage = 1;
    this.loadHistoricalData();
  }

  sort(column: string) {
    if (this.sortColumn === column) {
      this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
    } else {
      this.sortColumn = column;
      this.sortDirection = 'asc';
    }
    
    this.historicalData.sort((a, b) => {
      let aValue = (a as any)[column];
      let bValue = (b as any)[column];
      
      if (column === 'timestamp') {
        aValue = new Date(aValue).getTime();
        bValue = new Date(bValue).getTime();
      }
      
      if (this.sortDirection === 'asc') {
        return aValue > bValue ? 1 : -1;
      } else {
        return aValue < bValue ? 1 : -1;
      }
    });
  }

  getSortIcon(column: string): string {
    if (this.sortColumn !== column) return 'fas fa-sort';
    return this.sortDirection === 'asc' ? 'fas fa-sort-up' : 'fas fa-sort-down';
  }

  get paginatedData(): HistoricalDataItem[] {
    const startIndex = (this.currentPage - 1) * this.itemsPerPage;
    const endIndex = startIndex + this.itemsPerPage;
    return this.historicalData.slice(startIndex, endIndex);
  }

  get totalPages(): number {
    return Math.ceil(this.totalItems / this.itemsPerPage);
  }

  get pages(): number[] {
    const pages = [];
    const maxPages = Math.min(5, this.totalPages);
    let startPage = Math.max(1, this.currentPage - Math.floor(maxPages / 2));
    let endPage = Math.min(this.totalPages, startPage + maxPages - 1);
    
    if (endPage - startPage + 1 < maxPages) {
      startPage = Math.max(1, endPage - maxPages + 1);
    }
    
    for (let i = startPage; i <= endPage; i++) {
      pages.push(i);
    }
    return pages;
  }

  goToPage(page: number) {
    if (page >= 1 && page <= this.totalPages) {
      this.currentPage = page;
    }
  }

  exportToCsv() {
    const headers = ['Date', 'Symbol', 'Open', 'High', 'Low', 'Close', 'Volume', 'Change', 'Change %'];
    const csvContent = [
      headers.join(','),
      ...this.historicalData.map(item => [
        new Date(item.timestamp).toLocaleDateString(),
        item.symbol,
        item.open.toFixed(2),
        item.high.toFixed(2),
        item.low.toFixed(2),
        item.close.toFixed(2),
        item.volume,
        item.change?.toFixed(2) || '0.00',
        item.changePercent?.toFixed(2) || '0.00'
      ].join(','))
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `${this.selectedSymbol}_historical_${this.selectedDays}days.csv`;
    link.click();
    window.URL.revokeObjectURL(url);
  }

  trackByTimestamp(index: number, item: HistoricalDataItem): string {
    return item.timestamp;
  }

  // Additional methods for template compatibility
  refreshData() {
    this.loadHistoricalData();
  }

  sortBy(column: string) {
    this.sort(column);
  }

  getPaginatedData(): HistoricalDataItem[] {
    return this.paginatedData;
  }

  getTotalPages(): number {
    return this.totalPages;
  }

  getPageNumbers(): number[] {
    return this.pages;
  }

  trackByDate(index: number, item: HistoricalDataItem): string {
    return item.timestamp;
  }

  exportToCSV() {
    this.exportToCsv();
  }

  formatCurrency(value: number): string {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(value);
  }

  formatNumber(value: number): string {
    return new Intl.NumberFormat('en-US').format(value);
  }

  formatPercentage(value: number): string {
    return new Intl.NumberFormat('en-US', {
      style: 'percent',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(value / 100);
  }

  getChangeColorClass(value: number): string {
    if (value > 0) return 'text-success';
    if (value < 0) return 'text-danger';
    return 'text-muted';
  }
}
