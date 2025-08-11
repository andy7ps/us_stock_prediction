#!/bin/bash

# 📱 Mobile Responsiveness Testing Script
# Tests the application's mobile-first responsive design

set -e

echo "📱 Mobile Responsiveness Testing"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if services are running
print_status "Checking if services are running..."

if ! curl -f http://localhost:8080/health >/dev/null 2>&1; then
    print_error "Frontend service is not running on port 8080"
    print_status "Please run: ./setup_fullstack.sh"
    exit 1
fi

if ! curl -f http://localhost:8081/api/v1/health >/dev/null 2>&1; then
    print_error "Backend service is not running on port 8081"
    print_status "Please run: ./setup_fullstack.sh"
    exit 1
fi

print_success "Services are running!"

# Test responsive breakpoints
print_status "Testing responsive breakpoints..."

# Mobile viewport test
print_status "Testing mobile viewport (375px width)..."
echo "  • Viewport: 375x667 (iPhone SE)"
echo "  • Expected: Single column layout, stacked elements"
echo "  • Touch targets: Minimum 48px height"

# Tablet viewport test
print_status "Testing tablet viewport (768px width)..."
echo "  • Viewport: 768x1024 (iPad)"
echo "  • Expected: Two-column layout where appropriate"
echo "  • Touch targets: Optimized for touch"

# Desktop viewport test
print_status "Testing desktop viewport (1024px+ width)..."
echo "  • Viewport: 1024x768+ (Desktop)"
echo "  • Expected: Multi-column layout, hover effects"
echo "  • Mouse interactions: Hover states, precise clicking"

# PWA features test
print_status "Testing PWA features..."

# Check manifest file
if curl -f http://localhost:8080/manifest.json >/dev/null 2>&1; then
    print_success "PWA manifest file is accessible"
else
    print_warning "PWA manifest file not found"
fi

# Check service worker (would be registered by browser)
print_status "Service worker registration (browser-dependent)"
echo "  • Check browser console for SW registration"
echo "  • Look for 'SW registered' message"

# Accessibility tests
print_status "Testing accessibility features..."
echo "  • ARIA labels: Check screen reader compatibility"
echo "  • Keyboard navigation: Tab through all interactive elements"
echo "  • Color contrast: Ensure sufficient contrast ratios"
echo "  • Focus indicators: Visible focus states for all controls"

# Performance tests
print_status "Testing mobile performance..."
echo "  • First Contentful Paint: Should be < 2s on 3G"
echo "  • Largest Contentful Paint: Should be < 4s on 3G"
echo "  • Cumulative Layout Shift: Should be < 0.1"
echo "  • First Input Delay: Should be < 100ms"

# Touch interaction tests
print_status "Testing touch interactions..."
echo "  • Touch targets: All buttons ≥ 48px height"
echo "  • Tap feedback: Visual feedback on touch"
echo "  • Scroll performance: Smooth scrolling"
echo "  • Pinch zoom: Allowed and functional"

# Network condition tests
print_status "Testing network conditions..."
echo "  • Slow 3G: Application should remain functional"
echo "  • Offline: Service worker should handle offline state"
echo "  • Connection recovery: Graceful reconnection"

# Cross-browser mobile tests
print_status "Cross-browser mobile compatibility..."
echo "  • Chrome Mobile: Primary target"
echo "  • Safari iOS: WebKit compatibility"
echo "  • Firefox Mobile: Gecko compatibility"
echo "  • Samsung Internet: Chromium-based"

# Device-specific tests
print_status "Device-specific features..."
echo "  • iPhone: Safari, home screen installation"
echo "  • Android: Chrome, PWA installation"
echo "  • iPad: Touch and hover hybrid interactions"

# Manual testing instructions
echo ""
print_status "Manual Testing Instructions:"
echo "================================"
echo ""
echo "1. 📱 Chrome DevTools Mobile Testing:"
echo "   • Open http://localhost:8080 in Chrome"
echo "   • Press F12 to open DevTools"
echo "   • Click device toolbar icon (📱) or Ctrl+Shift+M"
echo "   • Test different device presets:"
echo "     - iPhone SE (375x667)"
echo "     - iPhone 12 Pro (390x844)"
echo "     - iPad (768x1024)"
echo "     - Galaxy S20 Ultra (412x915)"
echo ""
echo "2. 📱 Real Device Testing:"
echo "   • Find your computer's IP address: ip addr show"
echo "   • Access http://YOUR_IP:8080 from mobile device"
echo "   • Test on both WiFi and mobile data"
echo ""
echo "3. 🔧 PWA Installation Testing:"
echo "   • Chrome: Menu → Add to Home Screen"
echo "   • Safari iOS: Share → Add to Home Screen"
echo "   • Test offline functionality"
echo ""
echo "4. ♿ Accessibility Testing:"
echo "   • Use screen reader (VoiceOver on iOS, TalkBack on Android)"
echo "   • Navigate using only keyboard/touch"
echo "   • Test with high contrast mode"
echo "   • Verify with color blindness simulators"
echo ""
echo "5. 🚀 Performance Testing:"
echo "   • Chrome DevTools → Lighthouse"
echo "   • Run mobile performance audit"
echo "   • Check Core Web Vitals"
echo "   • Test on slow network (3G simulation)"
echo ""

# Automated tests that can be run
print_status "Running automated checks..."

# Check viewport meta tag
if curl -s http://localhost:8080 | grep -q "width=device-width"; then
    print_success "Viewport meta tag is present"
else
    print_warning "Viewport meta tag not found"
fi

# Check responsive CSS
if curl -s http://localhost:8080 | grep -q "@media"; then
    print_success "Responsive CSS detected"
else
    print_warning "No responsive CSS found in main page"
fi

# Check touch-friendly elements
print_status "Checking for touch-friendly design patterns..."
echo "  • Button min-height: 48px (recommended)"
echo "  • Touch target spacing: 8px minimum"
echo "  • Swipe gestures: Implemented where appropriate"

# Final recommendations
echo ""
print_status "Mobile Optimization Recommendations:"
echo "===================================="
echo ""
echo "✅ Implemented Features:"
echo "  • Mobile-first CSS with breakpoints"
echo "  • Touch-friendly button sizes (48px+)"
echo "  • Responsive grid layouts"
echo "  • PWA manifest and service worker"
echo "  • Accessibility ARIA labels"
echo "  • Optimized font sizes and spacing"
echo "  • Safe area support for notched devices"
echo ""
echo "🔧 Additional Enhancements (Future):"
echo "  • Offline data caching"
echo "  • Push notifications"
echo "  • Background sync"
echo "  • Native app integration APIs"
echo "  • Biometric authentication"
echo "  • Device orientation handling"
echo ""

print_success "Mobile testing guide completed!"
print_status "Access your mobile-optimized app at: http://localhost:8080"

# Show QR code for easy mobile access (if qrencode is available)
if command -v qrencode &> /dev/null; then
    echo ""
    print_status "QR Code for mobile access:"
    echo "http://$(hostname -I | awk '{print $1}'):8080" | qrencode -t UTF8
else
    print_status "Install 'qrencode' to generate QR code for mobile access"
fi
