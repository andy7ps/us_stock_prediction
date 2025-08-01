#!/bin/bash

# Email Setup Script for Stock Prediction Testing
# This script helps configure email notifications

echo "Stock Prediction Test Email Setup"
echo "=================================="
echo ""

echo "Your email is configured to: andy7ps.chen@gmail.com"
echo ""

echo "Email Methods Available:"
echo "1. System mail command (mailutils package)"
echo "2. Sendmail"
echo "3. Mutt email client"
echo "4. Python SMTP (Gmail)"
echo ""

echo "Setup Instructions:"
echo ""

echo "Method 1: Install mailutils (Recommended for Ubuntu/Debian)"
echo "  sudo apt update"
echo "  sudo apt install mailutils"
echo "  # Follow the configuration prompts"
echo ""

echo "Method 2: Install and configure sendmail"
echo "  sudo apt install sendmail"
echo "  sudo sendmailconfig"
echo ""

echo "Method 3: Install mutt"
echo "  sudo apt install mutt"
echo "  # Configure ~/.muttrc with your email settings"
echo ""

echo "Method 4: Gmail SMTP (Requires App Password)"
echo "  1. Enable 2-factor authentication on your Gmail account"
echo "  2. Generate an App Password:"
echo "     - Go to Google Account settings"
echo "     - Security > 2-Step Verification > App passwords"
echo "     - Generate password for 'Mail'"
echo "  3. Set environment variables:"
echo "     export GMAIL_USER='your-gmail@gmail.com'"
echo "     export GMAIL_APP_PASSWORD='your-app-password'"
echo "  4. Add to ~/.bashrc for persistence:"
echo "     echo 'export GMAIL_USER=\"your-gmail@gmail.com\"' >> ~/.bashrc"
echo "     echo 'export GMAIL_APP_PASSWORD=\"your-app-password\"' >> ~/.bashrc"
echo ""

echo "Testing Email Setup:"
echo "  # Test with a simple message"
echo "  echo 'Test message' | mail -s 'Test Subject' andy7ps.chen@gmail.com"
echo ""

echo "The test script will automatically try all available methods and"
echo "fall back to saving results to a file if email sending fails."
echo ""

echo "Current email configuration in test script:"
echo "  EMAIL_TO=\"andy7ps.chen@gmail.com\""
echo "  Results will be saved to: /tmp/prediction_test_results.txt"
echo ""

# Check what's currently available
echo "Checking available email tools on your system:"
echo ""

if command -v mail >/dev/null 2>&1; then
    echo "✓ mail command is available"
else
    echo "✗ mail command not found"
fi

if command -v sendmail >/dev/null 2>&1; then
    echo "✓ sendmail is available"
else
    echo "✗ sendmail not found"
fi

if command -v mutt >/dev/null 2>&1; then
    echo "✓ mutt is available"
else
    echo "✗ mutt not found"
fi

if command -v python3 >/dev/null 2>&1; then
    echo "✓ python3 is available (for SMTP method)"
    if python3 -c "import smtplib; print('✓ smtplib module available')" 2>/dev/null; then
        echo "✓ smtplib module available"
    else
        echo "✗ smtplib module not available"
    fi
else
    echo "✗ python3 not found"
fi

echo ""
echo "Gmail environment variables:"
if [ -n "$GMAIL_USER" ]; then
    echo "✓ GMAIL_USER is set: $GMAIL_USER"
else
    echo "✗ GMAIL_USER not set"
fi

if [ -n "$GMAIL_APP_PASSWORD" ]; then
    echo "✓ GMAIL_APP_PASSWORD is set (hidden)"
else
    echo "✗ GMAIL_APP_PASSWORD not set"
fi

echo ""
echo "Setup complete! Run the test script to see email notifications in action."
