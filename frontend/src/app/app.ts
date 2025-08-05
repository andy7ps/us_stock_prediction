import { Component, signal } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { StockPredictionComponent } from './components/stock-prediction.component';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, StockPredictionComponent],
  template: `
    <app-stock-prediction></app-stock-prediction>
    <router-outlet />
  `,
  styleUrl: './app.css'
})
export class App {
  protected readonly title = signal('US Stock Prediction Service');
}
