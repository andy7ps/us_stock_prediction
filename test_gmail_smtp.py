#!/usr/bin/env python3
"""
Gmail SMTP Test Script
Tests the Gmail SMTP configuration for the stock prediction system
"""

import smtplib
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime

def test_gmail_smtp():
    """Test Gmail SMTP configuration"""
    
    print("Gmail SMTP Configuration Test")
    print("=" * 40)
    
    # Check environment variables
    gmail_user = os.getenv('GMAIL_USER')
    gmail_password = os.getenv('GMAIL_APP_PASSWORD')
    
    print(f"GMAIL_USER: {'✓ Set' if gmail_user else '✗ Not set'}")
    if gmail_user:
        print(f"  Value: {gmail_user}")
    
    print(f"GMAIL_APP_PASSWORD: {'✓ Set' if gmail_password else '✗ Not set'}")
    if gmail_password:
        print(f"  Length: {len(gmail_password)} characters")
    
    if not gmail_user or not gmail_password:
        print("\n❌ Gmail credentials not properly configured!")
        print("\nSetup Instructions:")
        print("1. Generate Gmail App Password:")
        print("   - Go to https://myaccount.google.com/security")
        print("   - Enable 2-Factor Authentication")
        print("   - Generate App Password for 'Mail'")
        print("2. Set environment variables:")
        print(f"   export GMAIL_USER=\"andy7ps.chen@gmail.com\"")
        print(f"   export GMAIL_APP_PASSWORD=\"your-16-char-password\"")
        print("3. Add to ~/.bashrc for persistence")
        return False
    
    print(f"\n📧 Testing email connection...")
    
    try:
        # Create test message
        msg = MIMEMultipart()
        msg['From'] = gmail_user
        msg['To'] = "andy7ps.chen@gmail.com"
        msg['Subject'] = f"Gmail SMTP Test - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
        
        body = f"""
Gmail SMTP Test Message
======================

This is a test email from the stock prediction system.

Test Details:
- Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
- From: {gmail_user}
- SMTP Server: smtp.gmail.com:587
- Authentication: App Password

If you receive this email, Gmail SMTP is configured correctly! ✅

Next step: Run the prediction tests to receive automated results.

---
Stock Prediction Testing System
"""
        
        msg.attach(MIMEText(body, 'plain'))
        
        # Connect to Gmail SMTP
        print("  Connecting to smtp.gmail.com:587...")
        server = smtplib.SMTP('smtp.gmail.com', 587)
        
        print("  Starting TLS encryption...")
        server.starttls()
        
        print("  Authenticating...")
        server.login(gmail_user, gmail_password)
        
        print("  Sending test email...")
        text = msg.as_string()
        server.sendmail(gmail_user, "andy7ps.chen@gmail.com", text)
        
        print("  Closing connection...")
        server.quit()
        
        print("\n✅ SUCCESS! Test email sent successfully!")
        print(f"📬 Check your inbox: andy7ps.chen@gmail.com")
        print("\nGmail SMTP is now configured and ready for automated test notifications.")
        
        return True
        
    except smtplib.SMTPAuthenticationError as e:
        print(f"\n❌ AUTHENTICATION FAILED!")
        print(f"Error: {e}")
        print("\nPossible issues:")
        print("- Incorrect Gmail App Password")
        print("- 2-Factor Authentication not enabled")
        print("- App Password not generated correctly")
        print("\nSolution:")
        print("1. Verify 2FA is enabled on your Gmail account")
        print("2. Generate a new App Password")
        print("3. Update GMAIL_APP_PASSWORD environment variable")
        return False
        
    except smtplib.SMTPException as e:
        print(f"\n❌ SMTP ERROR!")
        print(f"Error: {e}")
        print("\nPossible issues:")
        print("- Network connectivity problems")
        print("- Gmail SMTP server issues")
        print("- Firewall blocking SMTP traffic")
        return False
        
    except Exception as e:
        print(f"\n❌ UNEXPECTED ERROR!")
        print(f"Error: {e}")
        print(f"Error type: {type(e).__name__}")
        return False

if __name__ == "__main__":
    success = test_gmail_smtp()
    exit(0 if success else 1)
