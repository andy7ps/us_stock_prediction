#!/usr/bin/env python3
"""
Model Evaluation and Backtesting Script
Comprehensive evaluation of prediction models with backtesting and performance metrics.
"""

import sys
import os
import pandas as pd
import numpy as np
import json
from datetime import datetime, timedelta
import matplotlib.pyplot as plt
import seaborn as sns
from typing import Dict, List, Tuple
import argparse

# Import our models
from lstm_model import LSTMStockPredictor
from enhanced_predict import EnhancedPredictor
from ensemble_predict import EnsemblePredictor

try:
    import yfinance as yf
    YFINANCE_AVAILABLE = True
except ImportError:
    YFINANCE_AVAILABLE = False

class ModelEvaluator:
    """Comprehensive model evaluation and backtesting."""
    
    def __init__(self, model_dir='/app/persistent_data/ml_models'):
        self.model_dir = model_dir
        self.results = {}
        
    def download_test_data(self, symbol, period='1y'):
        """Download test data for evaluation."""
        if not YFINANCE_AVAILABLE:
            print("yfinance not available, using dummy data")
            return self.generate_dummy_data(symbol)
        
        try:
            ticker = yf.Ticker(symbol)
            data = ticker.history(period=period)
            
            if data.empty:
                return self.generate_dummy_data(symbol)
            
            data.columns = [col.lower() for col in data.columns]
            data.reset_index(inplace=True)
            return data
        
        except Exception as e:
            print(f"Error downloading data for {symbol}: {e}")
            return self.generate_dummy_data(symbol)
    
    def generate_dummy_data(self, symbol, days=252):
        """Generate dummy stock data for testing."""
        np.random.seed(42)  # For reproducibility
        
        # Generate realistic stock price movement
        initial_price = 100.0
        returns = np.random.normal(0.001, 0.02, days)  # Daily returns
        prices = [initial_price]
        
        for ret in returns:
            prices.append(prices[-1] * (1 + ret))
        
        dates = pd.date_range(start='2023-01-01', periods=days+1, freq='D')
        
        df = pd.DataFrame({
            'date': dates,
            'open': prices[:-1],
            'high': [p * (1 + abs(np.random.normal(0, 0.01))) for p in prices[:-1]],
            'low': [p * (1 - abs(np.random.normal(0, 0.01))) for p in prices[:-1]],
            'close': prices[1:],
            'volume': np.random.randint(1000000, 10000000, days)
        })
        
        return df
    
    def calculate_metrics(self, actual: np.array, predicted: np.array) -> Dict:
        """Calculate comprehensive evaluation metrics."""
        # Basic regression metrics
        mse = np.mean((predicted - actual) ** 2)
        mae = np.mean(np.abs(predicted - actual))
        rmse = np.sqrt(mse)
        
        # Percentage errors
        mape = np.mean(np.abs((predicted - actual) / actual)) * 100
        
        # Direction accuracy
        actual_direction = np.diff(actual) > 0
        predicted_direction = np.diff(predicted) > 0
        direction_accuracy = np.mean(actual_direction == predicted_direction) * 100
        
        # Correlation
        correlation = np.corrcoef(actual, predicted)[0, 1] if len(actual) > 1 else 0
        
        # Sharpe-like ratio for predictions
        prediction_returns = np.diff(predicted) / predicted[:-1]
        actual_returns = np.diff(actual) / actual[:-1]
        
        if np.std(prediction_returns) > 0:
            prediction_sharpe = np.mean(prediction_returns) / np.std(prediction_returns)
        else:
            prediction_sharpe = 0
        
        # Hit rate (percentage of predictions within 5% of actual)
        hit_rate = np.mean(np.abs((predicted - actual) / actual) < 0.05) * 100
        
        return {
            'mse': float(mse),
            'mae': float(mae),
            'rmse': float(rmse),
            'mape': float(mape),
            'direction_accuracy': float(direction_accuracy),
            'correlation': float(correlation),
            'prediction_sharpe': float(prediction_sharpe),
            'hit_rate': float(hit_rate),
            'sample_size': len(actual)
        }
    
    def backtest_model(self, model, data: pd.DataFrame, model_name: str, 
                      lookback_window: int = 60, prediction_horizon: int = 1) -> Dict:
        """Perform backtesting on a model."""
        predictions = []
        actuals = []
        dates = []
        
        print(f"Backtesting {model_name}...")
        
        # Rolling window backtesting
        for i in range(lookback_window, len(data) - prediction_horizon):
            try:
                # Get historical data window
                hist_data = data.iloc[i-lookback_window:i].copy()
                
                # Make prediction
                if model_name == 'lstm':
                    pred = model.predict(hist_data)
                elif model_name == 'enhanced':
                    result = model.ensemble_prediction(hist_data['close'].values)
                    pred = result['prediction'] if isinstance(result, dict) else result
                elif model_name == 'ensemble':
                    result = model.ensemble_predict(hist_data)
                    pred = result['prediction'] if isinstance(result, dict) else result
                else:
                    continue
                
                # Get actual future price
                actual = data.iloc[i + prediction_horizon - 1]['close']
                
                predictions.append(pred)
                actuals.append(actual)
                dates.append(data.iloc[i]['date'] if 'date' in data.columns else i)
                
            except Exception as e:
                print(f"Error in backtesting at step {i}: {e}")
                continue
        
        if len(predictions) == 0:
            return {'error': 'No predictions generated'}
        
        predictions = np.array(predictions)
        actuals = np.array(actuals)
        
        # Calculate metrics
        metrics = self.calculate_metrics(actuals, predictions)
        
        # Add backtesting specific metrics
        metrics['model_name'] = model_name
        metrics['lookback_window'] = lookback_window
        metrics['prediction_horizon'] = prediction_horizon
        
        # Calculate trading performance
        trading_metrics = self.calculate_trading_metrics(actuals, predictions)
        metrics.update(trading_metrics)
        
        return {
            'metrics': metrics,
            'predictions': predictions.tolist(),
            'actuals': actuals.tolist(),
            'dates': [str(d) for d in dates]
        }
    
    def calculate_trading_metrics(self, actual_prices: np.array, predicted_prices: np.array) -> Dict:
        """Calculate trading-specific performance metrics."""
        # Simple trading strategy: buy if prediction > current, sell otherwise
        actual_returns = np.diff(actual_prices) / actual_prices[:-1]
        predicted_direction = np.diff(predicted_prices) > 0
        
        # Strategy returns (assuming we follow predictions)
        strategy_returns = np.where(predicted_direction, actual_returns, -actual_returns)
        
        # Performance metrics
        total_return = np.prod(1 + strategy_returns) - 1
        annualized_return = (1 + total_return) ** (252 / len(strategy_returns)) - 1
        volatility = np.std(strategy_returns) * np.sqrt(252)
        
        sharpe_ratio = annualized_return / volatility if volatility > 0 else 0
        
        # Maximum drawdown
        cumulative_returns = np.cumprod(1 + strategy_returns)
        running_max = np.maximum.accumulate(cumulative_returns)
        drawdown = (cumulative_returns - running_max) / running_max
        max_drawdown = np.min(drawdown)
        
        # Win rate
        win_rate = np.mean(strategy_returns > 0) * 100
        
        return {
            'total_return': float(total_return),
            'annualized_return': float(annualized_return),
            'volatility': float(volatility),
            'sharpe_ratio': float(sharpe_ratio),
            'max_drawdown': float(max_drawdown),
            'win_rate': float(win_rate)
        }
    
    def evaluate_all_models(self, symbol: str, test_period: str = '1y') -> Dict:
        """Evaluate all available models."""
        print(f"\n=== Evaluating models for {symbol} ===")
        
        # Download test data
        data = self.download_test_data(symbol, test_period)
        print(f"Downloaded {len(data)} data points for evaluation")
        
        results = {}
        
        # Initialize models
        models = {}
        
        # LSTM Model
        try:
            lstm_model = LSTMStockPredictor(model_path=os.path.join(self.model_dir, f"{symbol.lower()}_lstm_model"))
            if lstm_model.load_model():
                models['lstm'] = lstm_model
                print("Loaded LSTM model")
            else:
                print("LSTM model not available")
        except Exception as e:
            print(f"Error loading LSTM model: {e}")
        
        # Enhanced Statistical Model
        try:
            enhanced_model = EnhancedPredictor()
            models['enhanced'] = enhanced_model
            print("Loaded Enhanced model")
        except Exception as e:
            print(f"Error loading Enhanced model: {e}")
        
        # Ensemble Model
        try:
            ensemble_model = EnsemblePredictor(model_dir=self.model_dir)
            ensemble_model.load_ensemble()
            models['ensemble'] = ensemble_model
            print("Loaded Ensemble model")
        except Exception as e:
            print(f"Error loading Ensemble model: {e}")
        
        # Backtest each model
        for model_name, model in models.items():
            try:
                result = self.backtest_model(model, data, model_name)
                results[model_name] = result
                
                if 'metrics' in result:
                    metrics = result['metrics']
                    print(f"\n{model_name.upper()} Results:")
                    print(f"  Direction Accuracy: {metrics['direction_accuracy']:.2f}%")
                    print(f"  MAPE: {metrics['mape']:.2f}%")
                    print(f"  Correlation: {metrics['correlation']:.3f}")
                    print(f"  Sharpe Ratio: {metrics['sharpe_ratio']:.3f}")
                    print(f"  Win Rate: {metrics['win_rate']:.2f}%")
                
            except Exception as e:
                print(f"Error evaluating {model_name}: {e}")
                results[model_name] = {'error': str(e)}
        
        return results
    
    def generate_report(self, results: Dict, symbol: str, output_dir: str = '.'):
        """Generate comprehensive evaluation report."""
        report = {
            'symbol': symbol,
            'evaluation_date': datetime.now().isoformat(),
            'results': results
        }
        
        # Calculate summary statistics
        valid_results = {k: v for k, v in results.items() if 'metrics' in v}
        
        if valid_results:
            summary = {}
            metrics_to_summarize = ['direction_accuracy', 'mape', 'correlation', 'sharpe_ratio', 'win_rate']
            
            for metric in metrics_to_summarize:
                values = [v['metrics'][metric] for v in valid_results.values() if metric in v['metrics']]
                if values:
                    summary[metric] = {
                        'best': max(values),
                        'worst': min(values),
                        'average': np.mean(values),
                        'best_model': max(valid_results.keys(), 
                                        key=lambda k: valid_results[k]['metrics'].get(metric, 0))
                    }
            
            report['summary'] = summary
        
        # Save report
        report_file = os.path.join(output_dir, f'{symbol}_evaluation_report.json')
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        print(f"\nEvaluation report saved to {report_file}")
        
        # Generate plots if matplotlib is available
        try:
            self.create_evaluation_plots(results, symbol, output_dir)
        except Exception as e:
            print(f"Could not generate plots: {e}")
        
        return report
    
    def create_evaluation_plots(self, results: Dict, symbol: str, output_dir: str):
        """Create evaluation plots."""
        valid_results = {k: v for k, v in results.items() if 'metrics' in v and 'predictions' in v}
        
        if not valid_results:
            return
        
        # Set up the plot style
        plt.style.use('seaborn-v0_8')
        fig, axes = plt.subplots(2, 2, figsize=(15, 12))
        fig.suptitle(f'Model Evaluation Results - {symbol}', fontsize=16)
        
        # Plot 1: Prediction vs Actual (first model)
        first_model = list(valid_results.keys())[0]
        first_result = valid_results[first_model]
        
        axes[0, 0].scatter(first_result['actuals'], first_result['predictions'], alpha=0.6)
        axes[0, 0].plot([min(first_result['actuals']), max(first_result['actuals'])], 
                       [min(first_result['actuals']), max(first_result['actuals'])], 'r--')
        axes[0, 0].set_xlabel('Actual Prices')
        axes[0, 0].set_ylabel('Predicted Prices')
        axes[0, 0].set_title(f'Prediction vs Actual - {first_model}')
        
        # Plot 2: Direction Accuracy Comparison
        models = list(valid_results.keys())
        direction_acc = [valid_results[m]['metrics']['direction_accuracy'] for m in models]
        
        axes[0, 1].bar(models, direction_acc)
        axes[0, 1].set_ylabel('Direction Accuracy (%)')
        axes[0, 1].set_title('Direction Accuracy Comparison')
        axes[0, 1].tick_params(axis='x', rotation=45)
        
        # Plot 3: MAPE Comparison
        mape_values = [valid_results[m]['metrics']['mape'] for m in models]
        axes[1, 0].bar(models, mape_values)
        axes[1, 0].set_ylabel('MAPE (%)')
        axes[1, 0].set_title('Mean Absolute Percentage Error')
        axes[1, 0].tick_params(axis='x', rotation=45)
        
        # Plot 4: Sharpe Ratio Comparison
        sharpe_values = [valid_results[m]['metrics']['sharpe_ratio'] for m in models]
        axes[1, 1].bar(models, sharpe_values)
        axes[1, 1].set_ylabel('Sharpe Ratio')
        axes[1, 1].set_title('Trading Sharpe Ratio')
        axes[1, 1].tick_params(axis='x', rotation=45)
        
        plt.tight_layout()
        
        # Save plot
        plot_file = os.path.join(output_dir, f'{symbol}_evaluation_plots.png')
        plt.savefig(plot_file, dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"Evaluation plots saved to {plot_file}")

def main():
    parser = argparse.ArgumentParser(description='Evaluate stock prediction models')
    parser.add_argument('--symbols', nargs='+', default=['NVDA', 'TSLA', 'AAPL'],
                        help='Stock symbols to evaluate')
    parser.add_argument('--model-dir', default='/app/persistent_data/ml_models',
                        help='Directory containing trained models')
    parser.add_argument('--output-dir', default='.',
                        help='Output directory for reports and plots')
    parser.add_argument('--period', default='1y',
                        help='Test period for evaluation (1y, 6mo, 3mo)')
    
    args = parser.parse_args()
    
    print("=== Stock Prediction Model Evaluation ===")
    print(f"Symbols: {args.symbols}")
    print(f"Model directory: {args.model_dir}")
    print(f"Test period: {args.period}")
    
    # Create output directory
    os.makedirs(args.output_dir, exist_ok=True)
    
    # Initialize evaluator
    evaluator = ModelEvaluator(model_dir=args.model_dir)
    
    # Evaluate each symbol
    all_results = {}
    for symbol in args.symbols:
        try:
            results = evaluator.evaluate_all_models(symbol, args.period)
            all_results[symbol] = results
            
            # Generate individual report
            evaluator.generate_report(results, symbol, args.output_dir)
            
        except Exception as e:
            print(f"Error evaluating {symbol}: {e}")
            continue
    
    # Generate summary report
    summary_file = os.path.join(args.output_dir, 'evaluation_summary.json')
    with open(summary_file, 'w') as f:
        json.dump({
            'evaluation_date': datetime.now().isoformat(),
            'symbols_evaluated': list(all_results.keys()),
            'results': all_results
        }, f, indent=2, default=str)
    
    print(f"\nSummary report saved to {summary_file}")
    print("Evaluation complete!")

if __name__ == "__main__":
    main()
