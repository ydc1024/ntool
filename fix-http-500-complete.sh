#!/bin/bash

# Complete HTTP 500 Error Fix Script
# This script runs diagnosis first, then applies appropriate fixes

set -e

# Configuration
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
section() { echo -e "${PURPLE}🔍 $1${NC}"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    error "Run as root: sudo ./fix-http-500-complete.sh"
    exit 1
fi

echo "🚨 Complete HTTP 500 Error Fix"
echo "==============================="
echo "Target: $WEB_ROOT"
echo "Time: $(date)"
echo "==============================="
echo ""

# Step 1: Quick Status Check
section "Step 1: Quick Status Check"

cd "$WEB_ROOT" 2>/dev/null || {
    error "Cannot access web root: $WEB_ROOT"
    exit 1
}

# Test current HTTP status
info "Testing current website status..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost" 2>/dev/null || echo "000")

if [[ "$HTTP_CODE" =~ ^[23] ]]; then
    log "Website is working (HTTP $HTTP_CODE) - no fix needed!"
    exit 0
elif [ "$HTTP_CODE" = "500" ]; then
    error "Confirmed: HTTP 500 error detected"
else
    warning "Unexpected HTTP status: $HTTP_CODE"
fi

echo ""

# Step 2: Run Diagnostic
section "Step 2: Running Diagnostic Analysis"

info "Running comprehensive diagnostic..."

# Make diagnostic script executable
chmod +x http-500-error-diagnostic.sh 2>/dev/null || {
    error "Diagnostic script not found. Please ensure http-500-error-diagnostic.sh is in the current directory."
    exit 1
}

# Run diagnostic
./http-500-error-diagnostic.sh

echo ""

# Step 3: Apply Fixes
section "Step 3: Applying Automatic Fixes"

info "Running automatic fixes..."

# Make fix script executable
chmod +x http-500-auto-fix.sh 2>/dev/null || {
    error "Auto-fix script not found. Please ensure http-500-auto-fix.sh is in the current directory."
    exit 1
}

# Run fixes
./http-500-auto-fix.sh

echo ""

# Step 4: Final Verification
section "Step 4: Final Verification"

info "Performing final verification..."

# Wait for services to stabilize
sleep 5

# Test website again
HTTP_CODE_FINAL=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost" 2>/dev/null || echo "000")

echo ""
echo "=================================================="
echo "🎯 FINAL RESULTS"
echo "=================================================="
echo "Initial Status: HTTP 500"
echo "Final Status: HTTP $HTTP_CODE_FINAL"
echo ""

if [[ "$HTTP_CODE_FINAL" =~ ^[23] ]]; then
    log "🎉 SUCCESS: HTTP 500 error has been fixed!"
    echo ""
    echo "✅ Your website is now accessible:"
    echo "   • Main site: http://$(hostname -I | awk '{print $1}')"
    echo "   • BMI Calculator: http://$(hostname -I | awk '{print $1}')/bmi-calculator"
    echo "   • Currency Converter: http://$(hostname -I | awk '{print $1}')/currency-converter"
    echo "   • Loan Calculator: http://$(hostname -I | awk '{print $1}')/loan-calculator"
    echo ""
    echo "🧪 Recommended next steps:"
    echo "1. Test all calculator functions"
    echo "2. Verify API endpoints work"
    echo "3. Check admin panel if applicable"
    echo "4. Monitor error logs for any issues"
    
elif [ "$HTTP_CODE_FINAL" = "500" ]; then
    error "❌ HTTP 500 error persists after fixes"
    echo ""
    echo "🔍 Additional troubleshooting needed:"
    echo "1. Check detailed diagnostic report"
    echo "2. Review error logs manually:"
    echo "   tail -f $WEB_ROOT/storage/logs/laravel.log"
    echo "   tail -f /var/log/nginx/error.log"
    echo "   tail -f /var/log/php*-fpm.log"
    echo ""
    echo "3. Possible advanced issues:"
    echo "   • Custom code syntax errors"
    echo "   • Database schema problems"
    echo "   • Server configuration conflicts"
    echo "   • Memory/resource limitations"
    echo ""
    echo "4. Consider manual investigation or professional support"
    
else
    warning "⚠️ Unexpected final status: HTTP $HTTP_CODE_FINAL"
    echo ""
    echo "🔍 Manual verification needed:"
    echo "1. Check if website loads in browser"
    echo "2. Verify domain/DNS configuration"
    echo "3. Test direct IP access"
    echo "4. Check firewall settings"
fi

echo ""
echo "📊 Summary:"
echo "   • Diagnostic completed"
echo "   • Automatic fixes applied"
echo "   • Services restarted"
echo "   • Final status: HTTP $HTTP_CODE_FINAL"
echo ""
echo "📁 Files created:"
echo "   • Diagnostic reports in /tmp/"
echo "   • Fix logs in /tmp/"
echo "   • Error log backups in /tmp/"
echo ""
echo "=================================================="

# Provide next steps based on result
if [[ "$HTTP_CODE_FINAL" =~ ^[23] ]]; then
    echo "🎊 Congratulations! Your BestHammer NTool platform is now working!"
elif [ "$HTTP_CODE_FINAL" = "500" ]; then
    echo "🔧 Additional manual intervention required."
    echo "Consider running: tail -f $WEB_ROOT/storage/logs/laravel.log"
else
    echo "🤔 Unusual situation - manual verification recommended."
fi

echo ""
echo "Thank you for using the BestHammer HTTP 500 Fix Tool!"
echo "=================================================="
