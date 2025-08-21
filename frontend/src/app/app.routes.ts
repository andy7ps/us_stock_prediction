import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: '',
    redirectTo: '/dashboard',
    pathMatch: 'full'
  },
  {
    path: 'dashboard',
    loadComponent: () => import('./components/dashboard/dashboard.component').then(m => m.DashboardComponent),
    title: 'Dashboard - Stock Prediction'
  },
  {
    path: 'predictions',
    loadComponent: () => import('./components/stock-prediction.component').then(m => m.StockPredictionComponent),
    title: 'Predictions - Stock Prediction'
  },
  {
    path: 'historical',
    loadComponent: () => import('./components/historical-data.component').then(m => m.HistoricalDataComponent),
    title: 'Historical Data - Stock Prediction'
  },
  {
    path: 'charts',
    loadComponent: () => import('./components/candlestick-chart/candlestick-chart.component').then(m => m.CandlestickChartComponent),
    title: 'Stock Charts - Stock Prediction'
  },
  {
    path: 'accuracy',
    loadComponent: () => import('./components/prediction-accuracy/prediction-accuracy.component').then(m => m.PredictionAccuracyComponent),
    title: 'Accuracy Tracking - Stock Prediction'
  },
  {
    path: '**',
    redirectTo: '/dashboard'
  }
];
