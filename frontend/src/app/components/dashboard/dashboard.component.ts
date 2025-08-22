import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './dashboard.component.html',
  styleUrls: ['./dashboard.component.css']
})
export class DashboardComponent implements OnInit {
  
  // Dashboard stats
  stats = {
    totalPredictions: 210,
    accurateCount: 13,
    averageAccuracy: 75.2,
    topPerformer: 'PLTR'
  };

  // Quick access symbols
  popularSymbols = [
    { symbol: 'NVDA', name: 'NVIDIA Corp', price: 175.40, change: 2.5 },
    { symbol: 'TSLA', name: 'Tesla Inc', price: 323.90, change: -1.2 },
    { symbol: 'AAPL', name: 'Apple Inc', price: 226.01, change: 0.8 },
    { symbol: 'MSFT', name: 'Microsoft Corp', price: 505.72, change: 1.5 },
    { symbol: 'GOOGL', name: 'Alphabet Inc', price: 199.32, change: -0.3 },
    { symbol: 'AMZN', name: 'Amazon.com Inc', price: 223.81, change: 0.9 },
    { symbol: 'NOC', name: 'Northrop Grumman', price: 485.20, change: 1.2 },
    { symbol: 'RTX', name: 'Raytheon Technologies', price: 118.45, change: 0.7 },
    { symbol: 'LMT', name: 'Lockheed Martin', price: 562.30, change: -0.5 },
    { symbol: 'COIN', name: 'Coinbase Global', price: 245.67, change: 3.2 },
    { symbol: 'BRK/B', name: 'Berkshire Hathaway B', price: 458.90, change: 0.4 }
  ];

  // Recent activities
  recentActivities = [
    { action: 'Prediction Generated', symbol: 'NVDA', time: '2 minutes ago', status: 'success' },
    { action: 'Accuracy Updated', symbol: 'PLTR', time: '15 minutes ago', status: 'info' },
    { action: 'Model Retrained', symbol: 'TSLA', time: '1 hour ago', status: 'warning' },
    { action: 'Daily Run Completed', symbol: 'ALL', time: '2 hours ago', status: 'success' }
  ];

  constructor() { }

  ngOnInit(): void {
    // Load dashboard data
    this.loadDashboardData();
  }

  loadDashboardData() {
    // In a real app, this would call services to get actual data
    console.log('Loading dashboard data...');
  }

  getChangeClass(change: number): string {
    return change >= 0 ? 'text-success' : 'text-danger';
  }

  getChangeIcon(change: number): string {
    return change >= 0 ? 'fas fa-arrow-up' : 'fas fa-arrow-down';
  }

  getStatusClass(status: string): string {
    switch (status) {
      case 'success': return 'text-success';
      case 'warning': return 'text-warning';
      case 'info': return 'text-info';
      case 'danger': return 'text-danger';
      default: return 'text-muted';
    }
  }

  getStatusIcon(status: string): string {
    switch (status) {
      case 'success': return 'fas fa-check-circle';
      case 'warning': return 'fas fa-exclamation-triangle';
      case 'info': return 'fas fa-info-circle';
      case 'danger': return 'fas fa-times-circle';
      default: return 'fas fa-circle';
    }
  }
}
