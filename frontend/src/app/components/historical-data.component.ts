import { Component, OnInit, OnDestroy, ViewChild, ElementRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { StockPredictionService, HistoricalData } from '../services/stock-prediction.service';

// Import TradingView Lightweight Charts - using dynamic import for better compatibility
// import { createChart, CrosshairMode } from 'lightweight-charts';

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
export class HistoricalDataComponent implements OnInit, OnDestroy {
  @ViewChild('chartContainer', { static: false }) chartContainer!: ElementRef;
  
  // Chart properties
  private chart: any = null;
  private candlestickSeries: any = null;
  private volumeSeries: any = null;
  
  // View mode toggle
  viewMode: 'table' | 'chart' = 'chart'; // Default to chart view
  
  selectedSymbol = 'NVDA';
  selectedDays = 90;
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
    'AUR', 'PLTR', 'SMCI', 'TSM', 'MP', 'SMR', 'SPY',
    'NOC', 'RTX', 'LMT', 'COIN', 'BRK/B'
  ];
  
  // Template compatibility aliases
  get popularSymbols() { return this.symbols; }
  get loading() { return this.isLoading; }
  
  dayOptions = [30, 60, 90, 180, 365];

  // Make Math available in template
  Math = Math;

  constructor(private stockService: StockPredictionService) {}

  ngOnInit() {
    console.log('HistoricalDataComponent initialized with viewMode:', this.viewMode);
    this.loadHistoricalData();
  }

  ngOnDestroy() {
    if (this.chart) {
      this.chart.remove();
    }
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
          
          // Update chart if in chart view
          if (this.viewMode === 'chart') {
            setTimeout(async () => await this.initializeChart(), 100);
          }
        },
        error: (error: any) => {
          this.error = 'Failed to load historical data. Please try again.';
          this.isLoading = false;
          console.error('Error loading historical data:', error);
        }
      });
  }

  // Test function to verify lightweight-charts import
  async testLightweightChartsImport() {
    console.log('=== TESTING LIGHTWEIGHT-CHARTS IMPORT ===');
    try {
      const module = await import('lightweight-charts') as any;
      console.log('Import successful:', module);
      console.log('Module keys:', Object.keys(module));
      
      if (module.createChart) {
        console.log('Testing createChart function...');
        const testDiv = document.createElement('div');
        testDiv.style.width = '400px';
        testDiv.style.height = '300px';
        document.body.appendChild(testDiv);
        
        const testChart = module.createChart(testDiv, {
          width: 400,
          height: 300,
        }) as any;
        
        console.log('Test chart created successfully');
        console.log('Chart methods:', Object.getOwnPropertyNames(Object.getPrototypeOf(testChart)));
        
        // Test series constructors instead of strings
        console.log('=== TESTING SERIES CONSTRUCTORS ===');
        
        // Test 1: Try with CandlestickSeries constructor
        if (module.CandlestickSeries) {
          try {
            console.log('Test 1: Trying addSeries(CandlestickSeries, {})');
            const testSeries1 = testChart.addSeries(module.CandlestickSeries, {});
            console.log('SUCCESS: CandlestickSeries constructor worked:', testSeries1);
          } catch (error: any) {
            console.log('FAILED: CandlestickSeries constructor failed:', error?.message);
          }
        } else {
          console.log('CandlestickSeries constructor not found');
        }
        
        // Test 2: Try with HistogramSeries constructor
        if (module.HistogramSeries) {
          try {
            console.log('Test 2: Trying addSeries(HistogramSeries, {})');
            const testSeries2 = testChart.addSeries(module.HistogramSeries, {});
            console.log('SUCCESS: HistogramSeries constructor worked:', testSeries2);
          } catch (error: any) {
            console.log('FAILED: HistogramSeries constructor failed:', error?.message);
          }
        } else {
          console.log('HistogramSeries constructor not found');
        }
        
        // Test 3: Try with minimal options
        if (module.CandlestickSeries) {
          try {
            console.log('Test 3: Trying CandlestickSeries with minimal options');
            const testSeries3 = testChart.addSeries(module.CandlestickSeries, {
              upColor: '#00ff00',
              downColor: '#ff0000'
            });
            console.log('SUCCESS: CandlestickSeries with options worked:', testSeries3);
          } catch (error: any) {
            console.log('FAILED: CandlestickSeries with options failed:', error?.message);
          }
        }
        
        // Clean up
        testChart.remove();
        document.body.removeChild(testDiv);
        
        console.log('=== LIGHTWEIGHT-CHARTS TEST COMPLETE ===');
        return true;
      } else {
        console.error('createChart function not found');
        return false;
      }
    } catch (error) {
      console.error('=== LIGHTWEIGHT-CHARTS TEST FAILED ===');
      console.error('Error:', error);
      return false;
    }
  }

  private async initializeChart() {
    console.log('=== ENHANCED CHART INITIALIZATION STARTING ===');
    console.log('Chart container available:', !!this.chartContainer);
    console.log('Historical data length:', this.historicalData.length);
    
    // First, test the import
    const importTest = await this.testLightweightChartsImport();
    if (!importTest) {
      this.error = 'Lightweight-charts library test failed. Please check console for details.';
      return;
    }
    
    if (!this.chartContainer || this.historicalData.length === 0) {
      console.log('Chart initialization skipped: container or data not available');
      return;
    }

    try {
      // Remove existing chart
      if (this.chart) {
        console.log('Removing existing chart');
        this.chart.remove();
        this.chart = null;
        this.candlestickSeries = null;
        this.volumeSeries = null;
      }

      console.log('=== STARTING DYNAMIC IMPORT ===');
      console.log('Initializing chart with', this.historicalData.length, 'data points');
      console.log('Chart container element:', this.chartContainer.nativeElement);

      // Dynamic import with proper type handling
      console.log('About to import lightweight-charts...');
      const lightweightChartsModule = await import('lightweight-charts') as any;
      console.log('=== IMPORT SUCCESSFUL ===');
      console.log('Lightweight charts module:', lightweightChartsModule);
      console.log('Module keys:', Object.keys(lightweightChartsModule));

      // Get the required functions and series constructors
      const createChart = lightweightChartsModule.createChart;
      const CrosshairMode = lightweightChartsModule.CrosshairMode;
      const CandlestickSeries = lightweightChartsModule.CandlestickSeries;
      const HistogramSeries = lightweightChartsModule.HistogramSeries;

      console.log('=== SERIES CONSTRUCTORS ===');
      console.log('CandlestickSeries:', CandlestickSeries);
      console.log('HistogramSeries:', HistogramSeries);

      if (!createChart || typeof createChart !== 'function') {
        throw new Error('createChart is not a function');
      }

      console.log('=== CREATING CHART ===');
      // Get container dimensions for full width
      const containerWidth = this.chartContainer.nativeElement.clientWidth || this.chartContainer.nativeElement.offsetWidth;
      const chartWidth = Math.max(containerWidth, 800); // Minimum 800px width
      
      console.log('Container width:', containerWidth, 'Chart width:', chartWidth);
      
      // Create new chart with full width
      this.chart = createChart(this.chartContainer.nativeElement, {
        width: chartWidth,
        height: 500,
        layout: {
          background: { color: '#ffffff' },
          textColor: '#333',
        },
        grid: {
          vertLines: { color: '#e1e1e1' },
          horzLines: { color: '#e1e1e1' },
        },
        crosshair: {
          mode: CrosshairMode?.Normal || 0,
        },
        rightPriceScale: {
          borderColor: '#cccccc',
        },
        timeScale: {
          borderColor: '#cccccc',
          timeVisible: true,
          secondsVisible: false,
        },
        // Add responsive options
        handleScroll: {
          mouseWheel: true,
          pressedMouseMove: true,
        },
        handleScale: {
          axisPressedMouseMove: true,
          mouseWheel: true,
          pinch: true,
        },
      });

      console.log('=== CHART CREATED SUCCESSFULLY ===');
      console.log('Chart object:', this.chart);

      // Try using the series constructors instead of strings
      console.log('=== ATTEMPTING SERIES CREATION WITH CONSTRUCTORS ===');
      
      try {
        console.log('Trying with CandlestickSeries constructor...');
        this.candlestickSeries = this.chart.addSeries(CandlestickSeries, {
          upColor: '#26a69a',
          downColor: '#ef5350',
          borderVisible: false,
          wickUpColor: '#26a69a',
          wickDownColor: '#ef5350',
        });
        console.log('SUCCESS: Candlestick series created with constructor:', this.candlestickSeries);
      } catch (constructorError: any) {
        console.error('Constructor approach failed:', constructorError?.message);
        
        // Fallback: try with minimal options
        try {
          console.log('Trying with minimal options...');
          this.candlestickSeries = this.chart.addSeries(CandlestickSeries, {
            upColor: '#00ff00',
            downColor: '#ff0000'
          });
          console.log('SUCCESS: Minimal candlestick series created:', this.candlestickSeries);
        } catch (minimalError: any) {
          console.error('Even minimal constructor failed:', minimalError?.message);
          throw constructorError;
        }
      }

      // Try volume series with constructor
      try {
        console.log('Trying with HistogramSeries constructor...');
        this.volumeSeries = this.chart.addSeries(HistogramSeries, {
          color: '#26a69a',
          priceFormat: {
            type: 'volume',
          },
          priceScaleId: '',
          scaleMargins: {
            top: 0.8,
            bottom: 0,
          },
        });
        console.log('SUCCESS: Volume series created with constructor:', this.volumeSeries);
      } catch (volumeError: any) {
        console.error('Volume series creation failed:', volumeError?.message);
        console.log('Continuing without volume series...');
        this.volumeSeries = null;
      }

      console.log('=== UPDATING CHART DATA ===');
      this.updateChart();

      // Handle window resize with improved full-width handling
      const resizeObserver = new ResizeObserver(() => {
        if (this.chart && typeof this.chart.applyOptions === 'function') {
          const newWidth = this.chartContainer.nativeElement.clientWidth || this.chartContainer.nativeElement.offsetWidth;
          const fullWidth = Math.max(newWidth, 800); // Ensure minimum width
          console.log('Resizing chart to width:', fullWidth);
          this.chart.applyOptions({
            width: fullWidth,
          });
        }
      });
      resizeObserver.observe(this.chartContainer.nativeElement);

      // Also handle window resize events
      const handleResize = () => {
        if (this.chart && typeof this.chart.applyOptions === 'function') {
          const newWidth = this.chartContainer.nativeElement.clientWidth || this.chartContainer.nativeElement.offsetWidth;
          const fullWidth = Math.max(newWidth, 800);
          this.chart.applyOptions({
            width: fullWidth,
          });
        }
      };
      window.addEventListener('resize', handleResize);

      console.log('=== CHART INITIALIZATION COMPLETE ===');
    } catch (error: any) {
      console.error('=== CHART INITIALIZATION ERROR ===');
      console.error('Error initializing chart:', error);
      console.error('Error message:', error?.message);
      console.error('Error stack:', error?.stack);
      this.error = 'Failed to initialize chart. Please try refreshing the page.';
    }
  }

  private updateChart() {
    if (!this.candlestickSeries || !this.historicalData.length) {
      console.log('Chart update skipped: series or data not available');
      return;
    }

    try {
      console.log('Updating chart with', this.historicalData.length, 'data points');

      // Prepare candlestick data
      const candlestickData = this.historicalData
        .map(item => {
          // Convert timestamp to YYYY-MM-DD format
          const dateStr = item.timestamp.includes('T') 
            ? item.timestamp.split('T')[0] 
            : item.timestamp.split(' ')[0];
          
          return {
            time: dateStr,
            open: Number(item.open),
            high: Number(item.high),
            low: Number(item.low),
            close: Number(item.close),
          };
        })
        .filter(item => !isNaN(item.open) && !isNaN(item.high) && !isNaN(item.low) && !isNaN(item.close))
        .sort((a, b) => a.time.localeCompare(b.time)); // Sort by date ascending

      // Prepare volume data
      const volumeData = this.historicalData
        .map(item => {
          const dateStr = item.timestamp.includes('T') 
            ? item.timestamp.split('T')[0] 
            : item.timestamp.split(' ')[0];
          
          return {
            time: dateStr,
            value: Number(item.volume),
            color: item.close >= item.open ? '#26a69a' : '#ef5350',
          };
        })
        .filter(item => !isNaN(item.value))
        .sort((a, b) => a.time.localeCompare(b.time));

      console.log('Prepared', candlestickData.length, 'candlestick points and', volumeData.length, 'volume points');

      if (candlestickData.length > 0) {
        this.candlestickSeries.setData(candlestickData);
        console.log('Candlestick data set successfully');
      }

      if (volumeData.length > 0) {
        this.volumeSeries.setData(volumeData);
        console.log('Volume data set successfully');
      }

    } catch (error) {
      console.error('Error updating chart:', error);
      this.error = 'Failed to update chart data. Please try again.';
    }
  }

  // View mode toggle methods
  switchToChart() {
    console.log('Switching to chart view');
    this.viewMode = 'chart';
    this.error = ''; // Clear any previous errors
    setTimeout(async () => {
      console.log('Initializing chart after timeout');
      await this.initializeChart();
    }, 100);
  }

  switchToTable() {
    console.log('Switching to table view');
    this.viewMode = 'table';
    if (this.chart) {
      this.chart.remove();
      this.chart = null;
    }
  }

  toggleView() {
    if (this.viewMode === 'chart') {
      this.switchToTable();
    } else {
      this.switchToChart();
    }
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
