# 🚀 Release Notes - US Stock Prediction Service v3.6.0

**Release Date:** August 22, 2025  
**Version:** v3.6.0  
**Codename:** "Defense & Crypto Expansion"

---

## 🎯 **What's New in v3.6.0**

This major release significantly expands our stock prediction capabilities with **5 new symbols** across defense contractors, cryptocurrency exchanges, and value investing sectors, bringing our total coverage to **19 symbols** with enhanced ML training infrastructure.

---

## ✨ **Major Features**

### 🏭 **New Stock Symbol Support**
- **NOC** - Northrop Grumman Corporation (Defense Contractor)
- **RTX** - Raytheon Technologies Corporation (Defense Contractor)  
- **LMT** - Lockheed Martin Corporation (Defense Contractor)
- **COIN** - Coinbase Global Inc (Cryptocurrency Exchange)
- **BRK/B** - Berkshire Hathaway Class B (Value Investment)

### 🤖 **Enhanced ML Training System**
- **Symbol-Specific Training Scripts**: Individual optimized training configurations for each new symbol
- **Sector-Based Optimization**: 
  - Defense contractors (NOC, RTX, LMT): 120 epochs with stability focus
  - Crypto exchange (COIN): 150 epochs with high volatility handling
  - Value stock (BRK/B): 100 epochs with long-term trend analysis
- **Automated Training Pipeline**: Enhanced training scripts with intelligent model management

### 📈 **Expanded Market Coverage**
- **Total Symbols**: Now supporting 19 stock symbols across all major sectors
- **Sector Diversification**: 
  - Tech Giants: NVDA, TSLA, AAPL, MSFT, GOOGL, AMZN, META
  - Growth Stocks: AUR, PLTR, SMCI
  - International: TSM
  - Materials: MP
  - Energy: SMR
  - ETF: SPY
  - **Defense**: NOC, RTX, LMT *(New)*
  - **Crypto**: COIN *(New)*
  - **Value**: BRK/B *(New)*

---

## 🔧 **Technical Improvements**

### 🧠 **ML Model Enhancements**
- **Individual Training Scripts**: Created dedicated training scripts for each new symbol
- **Optimized Configurations**: Symbol-specific LSTM architectures and hyperparameters
- **Enhanced Feature Engineering**: Sector-specific technical indicators and market analysis
- **Improved Model Management**: Updated `manage_ml_models.sh` with new symbol support

### 🎨 **Frontend Updates**
- **Dashboard Integration**: Added new symbols to popular stocks section with realistic price data
- **Component Updates**: Updated all frontend components (dashboard, stock-prediction, historical-data)
- **Symbol Arrays**: Expanded symbol lists across all Angular components
- **UI Consistency**: Maintained consistent styling and functionality for new symbols

### 🐳 **Infrastructure Improvements**
- **Container Optimization**: Resolved frontend caching issues with proper container rebuilds
- **Deployment Pipeline**: Enhanced deployment process for seamless updates
- **Persistent Storage**: All new models stored in persistent data directory
- **Training Automation**: Improved training scripts with better error handling

---

## 📊 **Performance Metrics**

### 🎯 **Model Performance**
- **NOC**: 75.3% confidence, SELL signal capability
- **RTX**: 88.2% confidence, BUY signal capability  
- **LMT**: 83.6% confidence, HOLD signal capability
- **COIN**: 55.1% confidence, high volatility handling
- **BRK/B**: Trained and operational (symbol format optimization)

### 🚀 **System Performance**
- **Training Speed**: ~2 seconds per symbol for 500 data points
- **API Response**: <2 seconds for real-time predictions
- **Model Storage**: Efficient JSON model format for quick loading
- **Success Rate**: 100% training success rate across all symbols

---

## 🛠️ **Files Modified**

### 📱 **Frontend Components**
```
frontend/src/app/components/dashboard/dashboard.component.ts
frontend/src/app/components/stock-prediction.component.ts  
frontend/src/app/components/historical-data.component.ts
```

### 🤖 **ML Training Scripts**
```
scripts/ml/train_noc_model.py
scripts/ml/train_rtx_model.py
scripts/ml/train_lmt_model.py
scripts/ml/train_coin_model.py
scripts/ml/train_brkb_model.py
```

### ⚙️ **Configuration & Management**
```
enhanced_training.sh
manage_ml_models.sh
docker-compose.yml
frontend/nginx.conf
```

---

## 🔄 **Migration Guide**

### For Existing Users:
1. **Pull Latest Changes**: `git pull origin v3_6`
2. **Rebuild Frontend**: `npm run build` in frontend directory
3. **Restart Services**: `docker-compose down && docker-compose up -d`
4. **Train New Models**: `./manage_ml_models.sh train` (optional - models included)

### For New Installations:
1. **Clone Repository**: `git clone -b v3_6 [repository-url]`
2. **Run Setup**: `./deploy_docker_bootstrap.sh`
3. **Access Application**: http://localhost:8080

---

## 🐛 **Bug Fixes**

- **Container Caching**: Fixed frontend container caching preventing updated code deployment
- **Symbol Format**: Resolved BRK/B symbol handling with proper filename sanitization
- **Training Pipeline**: Fixed path issues in training scripts for special characters
- **Frontend Compilation**: Ensured all new symbols compile correctly into JavaScript bundles

---

## 🔒 **Security Updates**

- **Container Security**: Maintained non-root execution for all containers
- **Data Validation**: Enhanced input validation for new stock symbols
- **API Security**: Continued rate limiting and secure API practices

---

## 📚 **Documentation Updates**

- **README.md**: Updated to v3.6.0 with new features and symbol list
- **Release Notes**: Comprehensive documentation of all changes
- **Training Guides**: Updated ML training documentation
- **API Documentation**: Added examples for new symbols

---

## 🎉 **What's Next**

### **v3.7 Roadmap**
- Advanced ML models (Transformer, GRU)
- Real-time WebSocket API
- Multi-timeframe predictions
- Enhanced portfolio analysis

---

## 🙏 **Acknowledgments**

Special thanks to the community for requesting defense contractor and cryptocurrency coverage. This release significantly expands our market analysis capabilities across diverse sectors.

---

## 📞 **Support & Feedback**

- **Issues**: [GitHub Issues](https://github.com/andy7ps/us_stock_prediction/issues)
- **Discussions**: [GitHub Discussions](https://github.com/andy7ps/us_stock_prediction/discussions)
- **Email**: andy7ps@eland.idv.tw

---

**Happy Trading with v3.6.0! 📈💰**

*The US Stock Prediction Service Team*
