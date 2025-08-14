import { Component, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { StockPredictionComponent } from './components/stock-prediction.component';
import { PredictionAccuracyComponent } from './components/prediction-accuracy/prediction-accuracy.component';

@Component({
  selector: 'app-root',
  imports: [StockPredictionComponent, PredictionAccuracyComponent, CommonModule],
  template: `
    <!-- Mantis Bootstrap Layout -->
    <div class="pc-container">
      <!-- Sidebar -->
      <nav class="pc-sidebar">
        <!-- Brand -->
        <div class="navbar-brand">
          <i class="fas fa-chart-line"></i>
          Stock Prediction
        </div>
        
        <!-- Navigation -->
        <div class="pc-navbar">
          <ul class="nav flex-column">
            <li class="nav-item">
              <a class="nav-link" 
                 [class.active]="activeTab() === 'predictions'"
                 (click)="setActiveTab('predictions')"
                 href="#" role="button">
                <i class="fas fa-chart-area"></i>
                <span>Predictions</span>
              </a>
            </li>
            <li class="nav-item">
              <a class="nav-link" 
                 [class.active]="activeTab() === 'accuracy'"
                 (click)="setActiveTab('accuracy')"
                 href="#" role="button">
                <i class="fas fa-chart-bar"></i>
                <span>Accuracy Tracking</span>
              </a>
            </li>
            <li class="nav-item">
              <a class="nav-link" 
                 [class.active]="activeTab() === 'analytics'"
                 (click)="setActiveTab('analytics')"
                 href="#" role="button">
                <i class="fas fa-chart-pie"></i>
                <span>Analytics</span>
              </a>
            </li>
            <li class="nav-item">
              <a class="nav-link" 
                 [class.active]="activeTab() === 'settings'"
                 (click)="setActiveTab('settings')"
                 href="#" role="button">
                <i class="fas fa-cog"></i>
                <span>Settings</span>
              </a>
            </li>
          </ul>
        </div>
      </nav>

      <!-- Main Content -->
      <div class="pc-content">
        <!-- Header -->
        <header class="pc-header">
          <div class="d-flex align-items-center">
            <button class="btn btn-link d-md-none me-3" data-bs-toggle="sidebar" type="button">
              <i class="fas fa-bars"></i>
            </button>
            <h1 class="h4 mb-0 text-dark fw-bold">
              {{ getPageTitle() }}
            </h1>
          </div>
          <div class="ms-auto d-flex align-items-center">
            <div class="dropdown">
              <button class="btn btn-outline-primary dropdown-toggle" type="button" data-bs-toggle="dropdown">
                <i class="fas fa-user-circle me-2"></i>
                Dashboard
              </button>
              <ul class="dropdown-menu">
                <li><a class="dropdown-item" href="#"><i class="fas fa-user me-2"></i>Profile</a></li>
                <li><a class="dropdown-item" href="#"><i class="fas fa-cog me-2"></i>Settings</a></li>
                <li><hr class="dropdown-divider"></li>
                <li><a class="dropdown-item" href="#"><i class="fas fa-sign-out-alt me-2"></i>Logout</a></li>
              </ul>
            </div>
          </div>
        </header>

        <!-- Main Content Area -->
        <main class="pc-main">
          <!-- Dashboard Overview Cards -->
          <div class="row mb-4" *ngIf="activeTab() === 'predictions'">
            <div class="col-xl-3 col-md-6 mb-4">
              <div class="card prediction-card text-white">
                <div class="card-body metric-card">
                  <div class="metric-value">
                    <i class="fas fa-chart-line"></i>
                  </div>
                  <div class="metric-label">Live Predictions</div>
                </div>
              </div>
            </div>
            <div class="col-xl-3 col-md-6 mb-4">
              <div class="card accuracy-card text-white">
                <div class="card-body metric-card">
                  <div class="metric-value">
                    <i class="fas fa-bullseye"></i>
                  </div>
                  <div class="metric-label">Accuracy Rate</div>
                </div>
              </div>
            </div>
            <div class="col-xl-3 col-md-6 mb-4">
              <div class="card analytics-card text-white">
                <div class="card-body metric-card">
                  <div class="metric-value">
                    <i class="fas fa-database"></i>
                  </div>
                  <div class="metric-label">Data Points</div>
                </div>
              </div>
            </div>
            <div class="col-xl-3 col-md-6 mb-4">
              <div class="card bg-success text-white">
                <div class="card-body metric-card">
                  <div class="metric-value">
                    <i class="fas fa-clock"></i>
                  </div>
                  <div class="metric-label">Real-time</div>
                </div>
              </div>
            </div>
          </div>

          <!-- Tab Content -->
          <div class="tab-content">
            <!-- Predictions Tab -->
            <div class="tab-pane fade" [class.show]="activeTab() === 'predictions'" [class.active]="activeTab() === 'predictions'">
              <div class="row">
                <div class="col-12">
                  <div class="card">
                    <div class="card-header d-flex justify-content-between align-items-center">
                      <h5 class="mb-0">
                        <i class="fas fa-chart-area text-primary me-2"></i>
                        Stock Price Predictions
                      </h5>
                      <div class="d-flex gap-2">
                        <button class="btn btn-outline-primary btn-sm">
                          <i class="fas fa-refresh me-1"></i>
                          Refresh
                        </button>
                        <button class="btn btn-primary btn-sm">
                          <i class="fas fa-download me-1"></i>
                          Export
                        </button>
                      </div>
                    </div>
                    <div class="card-body">
                      <app-stock-prediction></app-stock-prediction>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Accuracy Tracking Tab -->
            <div class="tab-pane fade" [class.show]="activeTab() === 'accuracy'" [class.active]="activeTab() === 'accuracy'">
              <div class="row">
                <div class="col-12">
                  <div class="card">
                    <div class="card-header d-flex justify-content-between align-items-center">
                      <h5 class="mb-0">
                        <i class="fas fa-chart-bar text-success me-2"></i>
                        Prediction Accuracy Analysis
                      </h5>
                      <div class="d-flex gap-2">
                        <button class="btn btn-outline-success btn-sm">
                          <i class="fas fa-calendar me-1"></i>
                          Date Range
                        </button>
                        <button class="btn btn-success btn-sm">
                          <i class="fas fa-file-excel me-1"></i>
                          Export Report
                        </button>
                      </div>
                    </div>
                    <div class="card-body">
                      <app-prediction-accuracy></app-prediction-accuracy>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Analytics Tab -->
            <div class="tab-pane fade" [class.show]="activeTab() === 'analytics'" [class.active]="activeTab() === 'analytics'">
              <div class="row">
                <div class="col-12">
                  <div class="card">
                    <div class="card-header">
                      <h5 class="mb-0">
                        <i class="fas fa-chart-pie text-info me-2"></i>
                        Advanced Analytics
                      </h5>
                    </div>
                    <div class="card-body">
                      <div class="row">
                        <div class="col-md-6">
                          <div class="card bg-light">
                            <div class="card-body text-center">
                              <i class="fas fa-chart-line fa-3x text-primary mb-3"></i>
                              <h5>Performance Metrics</h5>
                              <p class="text-muted">Detailed analysis of prediction performance across different time periods and market conditions.</p>
                              <button class="btn btn-primary">View Details</button>
                            </div>
                          </div>
                        </div>
                        <div class="col-md-6">
                          <div class="card bg-light">
                            <div class="card-body text-center">
                              <i class="fas fa-brain fa-3x text-success mb-3"></i>
                              <h5>Model Insights</h5>
                              <p class="text-muted">Deep dive into machine learning model behavior and feature importance analysis.</p>
                              <button class="btn btn-success">Explore</button>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Settings Tab -->
            <div class="tab-pane fade" [class.show]="activeTab() === 'settings'" [class.active]="activeTab() === 'settings'">
              <div class="row">
                <div class="col-12">
                  <div class="card">
                    <div class="card-header">
                      <h5 class="mb-0">
                        <i class="fas fa-cog text-secondary me-2"></i>
                        System Settings
                      </h5>
                    </div>
                    <div class="card-body">
                      <div class="row">
                        <div class="col-md-6">
                          <h6>Prediction Settings</h6>
                          <div class="form-check form-switch mb-3">
                            <input class="form-check-input" type="checkbox" id="autoRefresh" checked>
                            <label class="form-check-label" for="autoRefresh">
                              Auto-refresh predictions
                            </label>
                          </div>
                          <div class="form-check form-switch mb-3">
                            <input class="form-check-input" type="checkbox" id="notifications">
                            <label class="form-check-label" for="notifications">
                              Enable notifications
                            </label>
                          </div>
                        </div>
                        <div class="col-md-6">
                          <h6>Display Settings</h6>
                          <div class="form-check form-switch mb-3">
                            <input class="form-check-input" type="checkbox" id="darkMode">
                            <label class="form-check-label" for="darkMode">
                              Dark mode
                            </label>
                          </div>
                          <div class="form-check form-switch mb-3">
                            <input class="form-check-input" type="checkbox" id="compactView">
                            <label class="form-check-label" for="compactView">
                              Compact view
                            </label>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </main>
      </div>
    </div>
  `,
  styleUrls: ['./app.css']
})
export class AppComponent {
  title = 'US Stock Prediction Service';
  activeTab = signal('predictions');

  setActiveTab(tab: string) {
    this.activeTab.set(tab);
  }

  getPageTitle(): string {
    switch (this.activeTab()) {
      case 'predictions':
        return 'Stock Price Predictions';
      case 'accuracy':
        return 'Accuracy Tracking';
      case 'analytics':
        return 'Advanced Analytics';
      case 'settings':
        return 'System Settings';
      default:
        return 'Dashboard';
    }
  }
}
