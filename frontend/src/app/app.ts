import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { StockPredictionComponent } from './components/stock-prediction.component';
import { PredictionAccuracyComponent } from './components/prediction-accuracy/prediction-accuracy.component';
import { HistoricalDataComponent } from './components/historical-data.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FormsModule, StockPredictionComponent, PredictionAccuracyComponent, HistoricalDataComponent],
  template: `
    <!-- Page Wrapper -->
    <div id="wrapper">
      
      <!-- Sidebar -->
      <ul class="navbar-nav bg-gradient-primary sidebar sidebar-dark accordion" id="accordionSidebar">
        
        <!-- Sidebar - Brand -->
        <a class="sidebar-brand d-flex align-items-center justify-content-center" href="#" (click)="setActiveTab('dashboard')">
          <div class="sidebar-brand-icon rotate-n-15">
            <i class="fas fa-chart-line"></i>
          </div>
          <div class="sidebar-brand-text mx-3">Stock Prediction <sup>AI</sup></div>
        </a>
        
        <!-- Divider -->
        <hr class="sidebar-divider my-0">
        
        <!-- Nav Item - Dashboard -->
        <li class="nav-item" [class.active]="activeTab === 'dashboard'">
          <a class="nav-link" href="#" (click)="setActiveTab('dashboard')">
            <i class="fas fa-fw fa-tachometer-alt"></i>
            <span>Dashboard</span>
          </a>
        </li>
        
        <!-- Divider -->
        <hr class="sidebar-divider">
        
        <!-- Heading -->
        <div class="sidebar-heading">
          ML Predictions
        </div>
        
        <!-- Nav Item - Stock Predictions -->
        <li class="nav-item" [class.active]="activeTab === 'predictions'">
          <a class="nav-link" href="#" (click)="setActiveTab('predictions')">
            <i class="fas fa-fw fa-chart-area"></i>
            <span>Stock Predictions</span>
          </a>
        </li>
        
        <!-- Nav Item - Accuracy Tracking -->
        <li class="nav-item" [class.active]="activeTab === 'accuracy'">
          <a class="nav-link" href="#" (click)="setActiveTab('accuracy')">
            <i class="fas fa-fw fa-bullseye"></i>
            <span>Accuracy Tracking</span>
          </a>
        </li>
        
        <!-- Divider -->
        <hr class="sidebar-divider">
        
        <!-- Heading -->
        <div class="sidebar-heading">
          Analytics
        </div>
        
        <!-- Nav Item - Performance -->
        <li class="nav-item" [class.active]="activeTab === 'performance'">
          <a class="nav-link" href="#" (click)="setActiveTab('performance')">
            <i class="fas fa-fw fa-chart-bar"></i>
            <span>Performance</span>
          </a>
        </li>
        
        <!-- Nav Item - Historical Data -->
        <li class="nav-item" [class.active]="activeTab === 'historical'">
          <a class="nav-link" href="#" (click)="setActiveTab('historical')">
            <i class="fas fa-fw fa-table"></i>
            <span>Historical Data</span>
          </a>
        </li>
        
        <!-- Divider -->
        <hr class="sidebar-divider d-none d-md-block">
        
        <!-- Sidebar Toggler (Sidebar) -->
        <div class="text-center d-none d-md-inline">
          <button class="rounded-circle border-0" id="sidebarToggle"></button>
        </div>
        
        <!-- Sidebar Card -->
        <div class="sidebar-card d-none d-lg-flex">
          <img class="sidebar-card-illustration mb-2" src="https://startbootstrap.github.io/startbootstrap-sb-admin-2/img/undraw_rocket.svg" alt="AI Powered">
          <p class="text-center mb-2"><strong>AI-Powered</strong> stock predictions with advanced machine learning models!</p>
          <div class="btn btn-success btn-sm">85%+ Accuracy</div>
        </div>
        
      </ul>
      <!-- End of Sidebar -->
      
      <!-- Content Wrapper -->
      <div id="content-wrapper" class="d-flex flex-column">
        
        <!-- Main Content -->
        <div id="content">
          
          <!-- Topbar -->
          <nav class="navbar navbar-expand navbar-light bg-white topbar mb-4 static-top shadow">
            
            <!-- Sidebar Toggle (Topbar) -->
            <button id="sidebarToggleTop" class="btn btn-link d-md-none rounded-circle mr-3">
              <i class="fa fa-bars"></i>
            </button>
            
            <!-- Topbar Search -->
            <form class="d-none d-sm-inline-block form-inline mr-auto ml-md-3 my-2 my-md-0 mw-100 navbar-search">
              <div class="input-group">
                <input type="text" class="form-control bg-light border-0 small" 
                       placeholder="Search stocks..." 
                       [(ngModel)]="searchSymbol"
                       (keyup.enter)="searchStock()"
                       aria-label="Search" aria-describedby="basic-addon2">
                <div class="input-group-append">
                  <button class="btn btn-primary" type="button" (click)="searchStock()">
                    <i class="fas fa-search fa-sm"></i>
                  </button>
                </div>
              </div>
            </form>
            
            <!-- Topbar Navbar -->
            <ul class="navbar-nav ml-auto">
              
              <!-- Nav Item - Search Dropdown (Visible Only XS) -->
              <li class="nav-item dropdown no-arrow d-sm-none">
                <a class="nav-link dropdown-toggle" href="#" id="searchDropdown" role="button"
                   data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                  <i class="fas fa-search fa-fw"></i>
                </a>
                <div class="dropdown-menu dropdown-menu-right p-3 shadow animated--grow-in"
                     aria-labelledby="searchDropdown">
                  <form class="form-inline mr-auto w-100 navbar-search">
                    <div class="input-group">
                      <input type="text" class="form-control bg-light border-0 small"
                             placeholder="Search stocks..." [(ngModel)]="searchSymbol"
                             aria-label="Search" aria-describedby="basic-addon2">
                      <div class="input-group-append">
                        <button class="btn btn-primary" type="button" (click)="searchStock()">
                          <i class="fas fa-search fa-sm"></i>
                        </button>
                      </div>
                    </div>
                  </form>
                </div>
              </li>
              
              <!-- Nav Item - Alerts -->
              <li class="nav-item dropdown no-arrow mx-1">
                <a class="nav-link dropdown-toggle" href="#" id="alertsDropdown" role="button"
                   data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                  <i class="fas fa-bell fa-fw"></i>
                  <span class="badge badge-danger badge-counter" *ngIf="alertCount > 0">{{alertCount}}</span>
                </a>
                <div class="dropdown-list dropdown-menu dropdown-menu-right shadow animated--grow-in"
                     aria-labelledby="alertsDropdown">
                  <h6 class="dropdown-header">
                    Prediction Alerts
                  </h6>
                  <div *ngFor="let alert of recentAlerts" class="dropdown-item d-flex align-items-center">
                    <div class="mr-3">
                      <div class="icon-circle" [ngClass]="getAlertIconClass(alert.type)">
                        <i class="fas fa-chart-line text-white"></i>
                      </div>
                    </div>
                    <div>
                      <div class="small text-gray-500">{{alert.time}}</div>
                      <span class="font-weight-bold">{{alert.message}}</span>
                    </div>
                  </div>
                  <a class="dropdown-item text-center small text-gray-500" href="#">Show All Alerts</a>
                </div>
              </li>
              
              <!-- Nav Item - Messages -->
              <li class="nav-item dropdown no-arrow mx-1">
                <a class="nav-link dropdown-toggle" href="#" id="messagesDropdown" role="button"
                   data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                  <i class="fas fa-envelope fa-fw"></i>
                  <span class="badge badge-danger badge-counter" *ngIf="messageCount > 0">{{messageCount}}</span>
                </a>
                <div class="dropdown-list dropdown-menu dropdown-menu-right shadow animated--grow-in"
                     aria-labelledby="messagesDropdown">
                  <h6 class="dropdown-header">
                    System Messages
                  </h6>
                  <div class="dropdown-item d-flex align-items-center">
                    <div class="mr-3">
                      <div class="icon-circle bg-success">
                        <i class="fas fa-check text-white"></i>
                      </div>
                    </div>
                    <div>
                      <div class="small text-gray-500">{{currentTime}}</div>
                      ML models are running optimally
                    </div>
                  </div>
                  <a class="dropdown-item text-center small text-gray-500" href="#">Read More Messages</a>
                </div>
              </li>
              
              <div class="topbar-divider d-none d-sm-block"></div>
              
              <!-- Nav Item - User Information -->
              <li class="nav-item dropdown no-arrow">
                <a class="nav-link dropdown-toggle" href="#" id="userDropdown" role="button"
                   data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                  <span class="mr-2 d-none d-lg-inline text-gray-600 small">Stock Trader</span>
                  <img class="img-profile rounded-circle" src="https://startbootstrap.github.io/startbootstrap-sb-admin-2/img/undraw_profile.svg">
                </a>
                <div class="dropdown-menu dropdown-menu-right shadow animated--grow-in"
                     aria-labelledby="userDropdown">
                  <a class="dropdown-item" href="#">
                    <i class="fas fa-user fa-sm fa-fw mr-2 text-gray-400"></i>
                    Profile
                  </a>
                  <a class="dropdown-item" href="#">
                    <i class="fas fa-cogs fa-sm fa-fw mr-2 text-gray-400"></i>
                    Settings
                  </a>
                  <a class="dropdown-item" href="#">
                    <i class="fas fa-list fa-sm fa-fw mr-2 text-gray-400"></i>
                    Activity Log
                  </a>
                  <div class="dropdown-divider"></div>
                  <a class="dropdown-item" href="#" data-toggle="modal" data-target="#logoutModal">
                    <i class="fas fa-sign-out-alt fa-sm fa-fw mr-2 text-gray-400"></i>
                    Logout
                  </a>
                </div>
              </li>
              
            </ul>
            
          </nav>
          <!-- End of Topbar -->
          
          <!-- Begin Page Content -->
          <div class="container-fluid">
            
            <!-- Page Heading -->
            <div class="d-sm-flex align-items-center justify-content-between mb-4">
              <h1 class="h3 mb-0 text-gray-800">{{getPageTitle()}}</h1>
              <a href="#" class="d-none d-sm-inline-block btn btn-sm btn-primary shadow-sm" (click)="generateReport()">
                <i class="fas fa-download fa-sm text-white-50"></i> Generate Report
              </a>
            </div>
            
            <!-- Dynamic Content Based on Active Tab -->
            <div [ngSwitch]="activeTab">
              
              <!-- Dashboard Tab -->
              <div *ngSwitchCase="'dashboard'">
                <app-stock-prediction></app-stock-prediction>
              </div>
              
              <!-- Predictions Tab -->
              <div *ngSwitchCase="'predictions'">
                <app-stock-prediction></app-stock-prediction>
              </div>
              
              <!-- Accuracy Tab -->
              <div *ngSwitchCase="'accuracy'">
                <app-prediction-accuracy></app-prediction-accuracy>
              </div>
              
              <!-- Performance Tab -->
              <div *ngSwitchCase="'performance'">
                <div class="row">
                  <div class="col-12">
                    <div class="card shadow mb-4">
                      <div class="card-header py-3">
                        <h6 class="m-0 font-weight-bold text-primary">Performance Analytics</h6>
                      </div>
                      <div class="card-body">
                        <p>Performance analytics coming soon...</p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              
              <!-- Historical Tab -->
              <div *ngSwitchCase="'historical'">
                <app-historical-data></app-historical-data>
              </div>
              
            </div>
            
          </div>
          <!-- /.container-fluid -->
          
        </div>
        <!-- End of Main Content -->
        
        <!-- Footer -->
        <footer class="sticky-footer bg-white">
          <div class="container my-auto">
            <div class="copyright text-center my-auto">
              <span>Copyright &copy; Stock Prediction Dashboard 2025 - Powered by SB Admin 2</span>
            </div>
          </div>
        </footer>
        <!-- End of Footer -->
        
      </div>
      <!-- End of Content Wrapper -->
      
    </div>
    <!-- End of Page Wrapper -->
    
    <!-- Scroll to Top Button-->
    <a class="scroll-to-top rounded" href="#page-top">
      <i class="fas fa-angle-up"></i>
    </a>
    
    <!-- Logout Modal-->
    <div class="modal fade" id="logoutModal" tabindex="-1" role="dialog" aria-labelledby="exampleModalLabel"
         aria-hidden="true">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title" id="exampleModalLabel">Ready to Leave?</h5>
            <button class="close" type="button" data-dismiss="modal" aria-label="Close">
              <span aria-hidden="true">×</span>
            </button>
          </div>
          <div class="modal-body">Select "Logout" below if you are ready to end your current session.</div>
          <div class="modal-footer">
            <button class="btn btn-secondary" type="button" data-dismiss="modal">Cancel</button>
            <a class="btn btn-primary" href="#">Logout</a>
          </div>
        </div>
      </div>
    </div>
  `,
  styleUrls: ['./app.css']
})
export class AppComponent implements OnInit {
  title = 'Stock Prediction Dashboard';
  activeTab = 'dashboard';
  searchSymbol = '';
  alertCount = 3;
  messageCount = 1;
  currentTime = new Date().toLocaleTimeString();
  
  recentAlerts = [
    {
      type: 'success',
      time: '2 minutes ago',
      message: 'NVDA prediction accuracy: 87.5%'
    },
    {
      type: 'warning',
      time: '15 minutes ago',
      message: 'TSLA volatility increased'
    },
    {
      type: 'info',
      time: '1 hour ago',
      message: 'Daily predictions completed'
    }
  ];

  ngOnInit() {
    // Update current time every minute
    setInterval(() => {
      this.currentTime = new Date().toLocaleTimeString();
    }, 60000);
    
    // Initialize SB Admin 2 sidebar toggle after Angular loads
    setTimeout(() => {
      this.initializeSBAdmin2();
    }, 500);
  }

  setActiveTab(tab: string) {
    this.activeTab = tab;
  }

  getPageTitle(): string {
    switch (this.activeTab) {
      case 'dashboard':
        return 'Dashboard';
      case 'predictions':
        return 'Stock Predictions';
      case 'accuracy':
        return 'Accuracy Tracking';
      case 'performance':
        return 'Performance Analytics';
      case 'historical':
        return 'Historical Data';
      default:
        return 'Dashboard';
    }
  }

  searchStock() {
    if (this.searchSymbol.trim()) {
      console.log('Searching for stock:', this.searchSymbol);
      // Implement stock search functionality
    }
  }

  generateReport() {
    console.log('Generating report...');
    // Implement report generation
  }

  getAlertIconClass(type: string): string {
    switch (type) {
      case 'success':
        return 'bg-success';
      case 'warning':
        return 'bg-warning';
      case 'danger':
        return 'bg-danger';
      case 'info':
        return 'bg-info';
      default:
        return 'bg-primary';
    }
  }

  private initializeSBAdmin2() {
    // Wait for jQuery to be available
    const checkJQuery = () => {
      if (typeof (window as any).$ !== 'undefined') {
        const $ = (window as any).$;
        
        // Toggle the side navigation
        $("#sidebarToggle, #sidebarToggleTop").on('click', (e: any) => {
          $("body").toggleClass("sidebar-toggled");
          $(".sidebar").toggleClass("toggled");
          if ($(".sidebar").hasClass("toggled")) {
            $('.sidebar .collapse').collapse('hide');
          }
        });

        // Close any open menu accordions when window is resized below 768px
        $(window).resize(() => {
          if ($(window).width() < 768) {
            $('.sidebar .collapse').collapse('hide');
          }
          
          // Toggle the side navigation when window is resized below 480px
          if ($(window).width() < 480 && !$(".sidebar").hasClass("toggled")) {
            $("body").addClass("sidebar-toggled");
            $(".sidebar").addClass("toggled");
            $('.sidebar .collapse').collapse('hide');
          }
        });

        // Scroll to top button appear
        $(document).on('scroll', () => {
          const scrollDistance = $(document).scrollTop();
          if (scrollDistance > 100) {
            $('.scroll-to-top').fadeIn();
          } else {
            $('.scroll-to-top').fadeOut();
          }
        });

        // Smooth scrolling using jQuery easing
        $(document).on('click', 'a.scroll-to-top', (e: any) => {
          const $anchor = $(e.currentTarget);
          $('html, body').stop().animate({
            scrollTop: ($($anchor.attr('href')).offset().top)
          }, 1000, 'easeInOutExpo');
          e.preventDefault();
        });

        console.log('SB Admin 2 JavaScript initialized');
      } else {
        // Retry after 100ms if jQuery is not loaded yet
        setTimeout(checkJQuery, 100);
      }
    };
    
    checkJQuery();
  }
}
