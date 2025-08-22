import { Component, OnInit, OnDestroy, ViewChild, ElementRef, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ChartDataService } from '../../services/chart-data.service';
import { SearchHistoryService } from '../../services/search-history.service';

// TradingView Lightweight Charts types (install: npm install lightweight-charts)
declare var LightweightCharts: any;

interface CandlestickData {
  time: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume?: number;
}

interface SearchHistoryItem {
  id: number;
  symbol: string;
  search_count: number;
  last_searched_at: string;
}

@Component({
  selector: 'app-candlestick-chart',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './candlestick-chart.component.html',
  styleUrls: ['./candlestick-chart.component.css']
})
export class CandlestickChartComponent implements OnInit, OnDestroy {
  @ViewChild('chartContainer', { static: true }) chartContainer!: ElementRef;
  
  // Chart properties
  private chart: any;
  private candlestickSeries: any;
  private volumeSeries: any;
  
  // Component state
  selectedSymbol = 'NVDA';
  selectedTimeRange = '1M';
  isLoading = false;
  error = '';
  
  // Chart data
  chartData: CandlestickData[] = [];
  currentPrice = 0;
  priceChange = 0;
  priceChangePercent = 0;
  volume = 0;
  marketCap = '';
  
  // Search functionality
  searchQuery = '';
  searchHistory: SearchHistoryItem[] = [];
  popularStocks: SearchHistoryItem[] = [];
  recentSearches: SearchHistoryItem[] = [];
  showSearchDropdown = false;
  filteredSearchResults: SearchHistoryItem[] = [];
  
  // Time range options
  timeRanges = [
    { label: '1D', value: '1D' },
    { label: '5D', value: '5D' },
    { label: '1M', value: '1M' },
    { label: '3M', value: '3M' },
    { label: '6M', value: '6M' },
    { label: '1Y', value: '1Y' },
    { label: '5Y', value: '5Y' },
    { label: 'MAX', value: 'MAX' }
  ];
  
  // Popular stocks
  popularSymbols = [
    'NVDA', 'TSLA', 'AAPL', 'MSFT', 'GOOGL', 'AMZN', 
    'SPY', 'QQQ', 'META', 'NFLX', 'AMD', 'INTC'
  ];

  constructor(
    private chartDataService: ChartDataService,
    private searchHistoryService: SearchHistoryService
  ) {}

  ngOnInit() {
    this.initializeChart();
    this.loadSearchHistory();
    this.loadChartData();
  }

  ngOnDestroy() {
    if (this.chart) {
      this.chart.remove();
    }
  }

  private initializeChart() {
    // Initialize TradingView Lightweight Charts
    this.chart = LightweightCharts.createChart(this.chartContainer.nativeElement, {
      width: this.chartContainer.nativeElement.clientWidth,
      height: 500,
      layout: {
        backgroundColor: '#ffffff',
        textColor: '#333',
      },
      grid: {
        vertLines: {
          color: '#e1e1e1',
        },
        horzLines: {
          color: '#e1e1e1',
        },
      },
      crosshair: {
        mode: LightweightCharts.CrosshairMode.Normal,
      },
      rightPriceScale: {
        borderColor: '#cccccc',
      },
      timeScale: {
        borderColor: '#cccccc',
        timeVisible: true,
        secondsVisible: false,
      },
    });

    // Add candlestick series
    this.candlestickSeries = this.chart.addCandlestickSeries({
      upColor: '#26a69a',
      downColor: '#ef5350',
      borderVisible: false,
      wickUpColor: '#26a69a',
      wickDownColor: '#ef5350',
    });

    // Add volume series
    this.volumeSeries = this.chart.addHistogramSeries({
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

    // Handle window resize
    window.addEventListener('resize', this.handleResize.bind(this));
  }

  private handleResize() {
    if (this.chart) {
      this.chart.applyOptions({
        width: this.chartContainer.nativeElement.clientWidth,
      });
    }
  }

  loadChartData() {
    this.isLoading = true;
    this.error = '';

    this.chartDataService.getChartData(this.selectedSymbol, this.selectedTimeRange)
      .subscribe({
        next: (response) => {
          this.chartData = response.data;
          this.currentPrice = response.current_price || 0;
          this.priceChange = response.change || 0;
          this.priceChangePercent = response.change_percent || 0;
          
          this.updateChart();
          this.isLoading = false;
        },
        error: (error) => {
          this.error = 'Failed to load chart data. Please try again.';
          this.isLoading = false;
          console.error('Chart data error:', error);
        }
      });
  }

  private updateChart() {
    if (!this.candlestickSeries || !this.chartData.length) return;

    // Prepare candlestick data
    const candlestickData = this.chartData.map(item => ({
      time: item.time,
      open: item.open,
      high: item.high,
      low: item.low,
      close: item.close,
    }));

    // Prepare volume data
    const volumeData = this.chartData.map(item => ({
      time: item.time,
      value: item.volume || 0,
      color: item.close >= item.open ? '#26a69a' : '#ef5350',
    }));

    this.candlestickSeries.setData(candlestickData);
    this.volumeSeries.setData(volumeData);
  }

  loadSearchHistory() {
    this.searchHistoryService.getSearchHistory()
      .subscribe({
        next: (response) => {
          this.searchHistory = response.history;
          this.popularStocks = response.popular;
          this.recentSearches = response.recent;
        },
        error: (error) => {
          console.error('Search history error:', error);
        }
      });
  }

  onSymbolChange(symbol: string) {
    this.selectedSymbol = symbol.toUpperCase();
    this.searchQuery = this.selectedSymbol;
    this.showSearchDropdown = false;
    
    // Record search
    this.searchHistoryService.recordSearch(this.selectedSymbol).subscribe();
    
    this.loadChartData();
  }

  onTimeRangeChange(timeRange: string) {
    this.selectedTimeRange = timeRange;
    this.loadChartData();
  }

  onSearchInput() {
    if (this.searchQuery.length > 0) {
      this.filteredSearchResults = [
        ...this.popularStocks,
        ...this.recentSearches,
        ...this.searchHistory
      ].filter(item => 
        item.symbol.toLowerCase().includes(this.searchQuery.toLowerCase())
      ).slice(0, 10);
      
      this.showSearchDropdown = true;
    } else {
      this.showSearchDropdown = false;
    }
  }

  onSearchSubmit() {
    if (this.searchQuery.trim()) {
      this.onSymbolChange(this.searchQuery.trim());
    }
  }

  selectFromDropdown(symbol: string) {
    this.onSymbolChange(symbol);
  }

  selectPopularStock(symbol: string) {
    this.onSymbolChange(symbol);
  }

  hideSearchDropdown() {
    // Delay hiding to allow click events
    setTimeout(() => {
      this.showSearchDropdown = false;
    }, 200);
  }

  get priceChangeClass(): string {
    return this.priceChange >= 0 ? 'text-success' : 'text-danger';
  }

  get priceChangeIcon(): string {
    return this.priceChange >= 0 ? 'fas fa-arrow-up' : 'fas fa-arrow-down';
  }

  formatPrice(price: number): string {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(price);
  }

  formatVolume(volume: number): string {
    if (volume >= 1000000) {
      return (volume / 1000000).toFixed(1) + 'M';
    } else if (volume >= 1000) {
      return (volume / 1000).toFixed(1) + 'K';
    }
    return volume.toString();
  }

  formatPercentage(percent: number): string {
    const sign = percent >= 0 ? '+' : '';
    return `${sign}${percent.toFixed(2)}%`;
  }
}
