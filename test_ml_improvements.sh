#!/bin/bash

# Test ML Improvements Script
# Verifies that all ML improvements are working correctly

set -e

echo "=== Testing ML Improvements ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

# Test counter
tests_run=0
tests_passed=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    print_test "$test_name"
    tests_run=$((tests_run + 1))
    
    if eval "$test_command" > /dev/null 2>&1; then
        print_pass "$test_name"
        tests_passed=$((tests_passed + 1))
        return 0
    else
        print_fail "$test_name"
        return 1
    fi
}

# Check if we're in the right directory
if [ ! -f "main.go" ]; then
    echo "Please run this script from the project root directory"
    exit 1
fi

# Test 1: Check if ML scripts exist
print_test "Checking ML script files..."
required_files=(
    "scripts/ml/lstm_model.py"
    "scripts/ml/ensemble_predict.py"
    "scripts/ml/train_model.py"
    "scripts/ml/evaluate_models.py"
    "scripts/ml/enhanced_predict.py"
)

all_files_exist=true
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (missing)"
        all_files_exist=false
    fi
done

if [ "$all_files_exist" = true ]; then
    print_pass "All ML script files exist"
    tests_passed=$((tests_passed + 1))
else
    print_fail "Some ML script files are missing"
fi
tests_run=$((tests_run + 1))

# Test 2: Check Python environment
print_test "Checking Python environment..."
if [ -d "venv" ]; then
    source venv/bin/activate
    print_pass "Virtual environment activated"
else
    print_skip "Virtual environment not found, using system Python"
fi

# Test 3: Check Python dependencies
print_test "Checking Python dependencies..."
required_packages=("numpy" "pandas" "sklearn")
package_names=("numpy" "pandas" "scikit-learn")
missing_packages=()

for i in "${!required_packages[@]}"; do
    package="${required_packages[$i]}"
    display_name="${package_names[$i]}"
    if python3 -c "import $package" 2>/dev/null; then
        echo "  ✓ $display_name"
    else
        echo "  ✗ $display_name (missing)"
        missing_packages+=("$display_name")
    fi
done

if [ ${#missing_packages[@]} -eq 0 ]; then
    print_pass "All required Python packages available"
    tests_passed=$((tests_passed + 1))
else
    print_fail "Missing packages: ${missing_packages[*]}"
fi
tests_run=$((tests_run + 1))

# Test 4: Test basic prediction models
sample_data="100,101,102,103,104,105,106,107,108,109,110"

run_test "Enhanced prediction model" "python3 scripts/ml/enhanced_predict.py '$sample_data'"
run_test "LSTM model (fallback mode)" "python3 scripts/ml/lstm_model.py '$sample_data'"
run_test "Ensemble prediction model" "python3 scripts/ml/ensemble_predict.py '$sample_data'"

# Test 5: Check if TensorFlow is available
print_test "Checking TensorFlow availability..."
if python3 -c "import tensorflow as tf; print(f'TensorFlow {tf.__version__} available')" 2>/dev/null; then
    print_pass "TensorFlow is available for deep learning"
    tests_passed=$((tests_passed + 1))
else
    print_skip "TensorFlow not available (deep learning models will use fallback)"
fi
tests_run=$((tests_run + 1))

# Test 6: Check if yfinance is available
print_test "Checking yfinance availability..."
if python3 -c "import yfinance as yf; print('yfinance available')" 2>/dev/null; then
    print_pass "yfinance is available for real market data"
    tests_passed=$((tests_passed + 1))
else
    print_skip "yfinance not available (will use dummy data for training)"
fi
tests_run=$((tests_run + 1))

# Test 7: Test model training (quick test)
print_test "Testing model training functionality..."
if python3 scripts/ml/train_model.py --symbols TEST --epochs 1 --model-dir /tmp/test_models 2>/dev/null; then
    print_pass "Model training functionality works"
    tests_passed=$((tests_passed + 1))
    rm -rf /tmp/test_models
else
    print_fail "Model training functionality failed"
fi
tests_run=$((tests_run + 1))

# Test 8: Test evaluation functionality
print_test "Testing model evaluation functionality..."
if python3 scripts/ml/evaluate_models.py --symbols TEST --model-dir /tmp/test_models --output-dir /tmp/test_eval 2>/dev/null; then
    print_pass "Model evaluation functionality works"
    tests_passed=$((tests_passed + 1))
    rm -rf /tmp/test_eval
else
    print_fail "Model evaluation functionality failed"
fi
tests_run=$((tests_run + 1))

# Test 9: Check directory structure
print_test "Checking directory structure..."
required_dirs=(
    "persistent_data/ml_models"
    "persistent_data/ml_cache"
    "scripts/ml"
)

all_dirs_exist=true
for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo "  ✓ $dir"
    else
        echo "  ✗ $dir (missing)"
        all_dirs_exist=false
    fi
done

if [ "$all_dirs_exist" = true ]; then
    print_pass "All required directories exist"
    tests_passed=$((tests_passed + 1))
else
    print_fail "Some required directories are missing"
fi
tests_run=$((tests_run + 1))

# Test 10: Test Go service integration
print_test "Testing Go service integration..."
if [ -f ".env" ] && grep -q "ML_PYTHON_SCRIPT" .env; then
    ml_script=$(grep "ML_PYTHON_SCRIPT" .env | cut -d'=' -f2)
    if [ -f "$ml_script" ]; then
        print_pass "Go service ML integration configured correctly"
        tests_passed=$((tests_passed + 1))
    else
        print_fail "ML script specified in .env does not exist: $ml_script"
    fi
else
    print_fail "ML_PYTHON_SCRIPT not configured in .env"
fi
tests_run=$((tests_run + 1))

# Test 11: Test management script
print_test "Testing management script..."
if [ -f "manage_ml_models.sh" ] && [ -x "manage_ml_models.sh" ]; then
    if ./manage_ml_models.sh test > /dev/null 2>&1; then
        print_pass "Management script works correctly"
        tests_passed=$((tests_passed + 1))
    else
        print_fail "Management script test failed"
    fi
else
    print_fail "Management script missing or not executable"
fi
tests_run=$((tests_run + 1))

# Summary
echo
echo "=== Test Summary ==="
echo "Tests run: $tests_run"
echo "Tests passed: $tests_passed"
echo "Tests failed: $((tests_run - tests_passed))"

if [ $tests_passed -eq $tests_run ]; then
    echo -e "${GREEN}All tests passed! ✅${NC}"
    echo
    echo "🎉 ML improvements are working correctly!"
    echo
    echo "Next steps:"
    echo "1. Train models: ./manage_ml_models.sh train NVDA TSLA AAPL"
    echo "2. Evaluate models: ./manage_ml_models.sh evaluate NVDA TSLA AAPL"
    echo "3. Restart your Go service to use the new models"
    exit 0
else
    echo -e "${RED}Some tests failed! ❌${NC}"
    echo
    echo "Please check the failed tests and run setup_ml_improvements.sh if needed"
    exit 1
fi
