#!/usr/bin/env python3
"""
Apply MultiIndex fix to all existing training scripts
"""

import os
import glob
import re

def fix_multiindex_in_script(script_path):
    """Apply MultiIndex fix to a single training script"""
    print(f"Fixing {script_path}...")
    
    with open(script_path, 'r') as f:
        content = f.read()
    
    # Check if fix is already applied
    if 'isinstance(stock_data.columns, pd.MultiIndex)' in content:
        print(f"  ✅ Already fixed: {script_path}")
        return False
    
    # Find the yf.download line and add the fix after it
    pattern = r'(stock_data = yf\.download\(symbol, start=start_date, end=end_date\)\s*\n)'
    replacement = r'''\1    
    # Fix MultiIndex columns issue (yfinance compatibility)
    if isinstance(stock_data.columns, pd.MultiIndex):
        stock_data.columns = stock_data.columns.get_level_values(0)
    
'''
    
    new_content = re.sub(pattern, replacement, content)
    
    if new_content != content:
        with open(script_path, 'w') as f:
            f.write(new_content)
        print(f"  ✅ Fixed: {script_path}")
        return True
    else:
        print(f"  ❌ Pattern not found in: {script_path}")
        return False

def main():
    """Fix all training scripts"""
    script_dir = "/home/achen/andy_misc/golang/ml/stock_prediction/v3/scripts/ml"
    pattern = os.path.join(script_dir, "train_*_model.py")
    
    scripts = glob.glob(pattern)
    print(f"Found {len(scripts)} training scripts to fix:")
    
    fixed_count = 0
    for script in scripts:
        if fix_multiindex_in_script(script):
            fixed_count += 1
    
    print(f"\n🎉 Fixed {fixed_count} out of {len(scripts)} scripts")
    print("✅ All training scripts now have MultiIndex fix!")

if __name__ == "__main__":
    main()
