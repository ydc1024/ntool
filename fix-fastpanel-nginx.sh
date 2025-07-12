#!/bin/bash

# Fix FastPanel Nginx Configuration
# This script modifies existing FastPanel configurations to enable local access

set -e

# Configuration
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="/tmp/fastpanel_nginx_fix_${TIMESTAMP}.log"
BACKUP_DIR="/tmp/nginx_backup_${TIMESTAMP}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() { echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}⚠️ $1${NC}" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"; }
info() { echo -e "${BLUE}ℹ️ $1${NC}" | tee -a "$LOG_FILE"; }
section() { echo -e "${PURPLE}🔍 $1${NC}" | tee -a "$LOG_FILE"; }

# Initialize log
echo "# FastPanel Nginx Fix Log" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"

# Check root
if [[ $EUID -ne 0 ]]; then
    error "Run as root: sudo ./fix-fastpanel-nginx.sh"
    exit 1
fi

echo "🔧 FastPanel Nginx Configuration Fix"
echo "===================================="
echo "Time: $(date)"
echo "Log: $LOG_FILE"
echo "===================================="
echo ""

# Step 1: Create Backup
section "Step 1: Creating Configuration Backup"

mkdir -p "$BACKUP_DIR"

# Backup key configuration files
CONFIG_FILES=(
    "/etc/nginx/conf.d/parking.conf"
    "/etc/nginx/conf.d/reuseport.conf"
    "/etc/nginx/fastpanel2-sites/besthammer_c_usr/besthammer.club.conf"
    "/etc/nginx/conf.d/local-binding.conf"
    "/etc/nginx/conf.d/universal-binding.conf"
)

for config in "${CONFIG_FILES[@]}"; do
    if [ -f "$config" ]; then
        cp "$config" "$BACKUP_DIR/" 2>/dev/null || true
        log "✓ Backed up: $(basename $config)"
    fi
done

log "✓ Configuration backup created in: $BACKUP_DIR"

# Step 2: Clean Up Previous Attempts
section "Step 2: Cleaning Up Previous Configurations"

# Remove our previous configurations that caused conflicts
if [ -f "/etc/nginx/conf.d/local-binding.conf" ]; then
    rm -f "/etc/nginx/conf.d/local-binding.conf"
    log "✓ Removed conflicting local-binding.conf"
fi

if [ -f "/etc/nginx/conf.d/universal-binding.conf" ]; then
    rm -f "/etc/nginx/conf.d/universal-binding.conf"
    log "✓ Removed conflicting universal-binding.conf"
fi

# Step 3: Analyze Existing Configurations
section "Step 3: Analyzing Existing Configurations"

EXTERNAL_IP="104.194.77.132"
FASTPANEL_SITE_CONF="/etc/nginx/fastpanel2-sites/besthammer_c_usr/besthammer.club.conf"

info "Analyzing FastPanel site configuration..."

if [ -f "$FASTPANEL_SITE_CONF" ]; then
    log "✓ Found FastPanel site config: $FASTPANEL_SITE_CONF"
    
    echo "=== ORIGINAL FASTPANEL CONFIG ===" >> "$LOG_FILE"
    cat "$FASTPANEL_SITE_CONF" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Check current listen directives
    CURRENT_LISTENS=$(grep -n "listen" "$FASTPANEL_SITE_CONF" 2>/dev/null || echo "No listen directives found")
    info "Current listen directives:"
    echo "$CURRENT_LISTENS" | tee -a "$LOG_FILE"
    
else
    error "✗ FastPanel site config not found: $FASTPANEL_SITE_CONF"
    exit 1
fi

# Step 4: Modify FastPanel Configuration
section "Step 4: Modifying FastPanel Configuration"

info "Modifying FastPanel site configuration to add local access..."

# Create a modified version of the FastPanel config
TEMP_CONFIG="/tmp/fastpanel_modified_${TIMESTAMP}.conf"

# Read the original config and modify it
if [ -f "$FASTPANEL_SITE_CONF" ]; then
    # Copy original config
    cp "$FASTPANEL_SITE_CONF" "$TEMP_CONFIG"
    
    # Add local listen directives after the first listen directive
    # Find the first listen line and add our local listens after it
    if grep -q "listen.*$EXTERNAL_IP:80" "$TEMP_CONFIG"; then
        info "Adding local listen directives..."
        
        # Use sed to add local listen directives after the external IP listen
        sed -i "/listen.*$EXTERNAL_IP:80/a\\
    listen 127.0.0.1:80;\\
    listen localhost:80;" "$TEMP_CONFIG"
        
        log "✓ Added local listen directives"
    else
        warning "Could not find external IP listen directive to modify"
    fi
    
    # Also add universal listen if not present
    if ! grep -q "listen 80;" "$TEMP_CONFIG" && ! grep -q "listen \*:80;" "$TEMP_CONFIG"; then
        info "Adding universal listen directive..."
        sed -i "/listen.*$EXTERNAL_IP:80/a\\
    listen 80;" "$TEMP_CONFIG"
        log "✓ Added universal listen directive"
    fi
    
    echo "=== MODIFIED FASTPANEL CONFIG ===" >> "$LOG_FILE"
    cat "$TEMP_CONFIG" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
else
    error "✗ Cannot modify FastPanel config - file not found"
    exit 1
fi

# Step 5: Test Modified Configuration
section "Step 5: Testing Modified Configuration"

info "Testing modified configuration..."

# Temporarily replace the config for testing
cp "$FASTPANEL_SITE_CONF" "${FASTPANEL_SITE_CONF}.backup"
cp "$TEMP_CONFIG" "$FASTPANEL_SITE_CONF"

# Test nginx configuration
if nginx -t 2>/dev/null; then
    log "✓ Modified configuration test passed"
    
    info "Applying modified configuration..."
    if systemctl reload nginx 2>/dev/null; then
        log "✓ Nginx reloaded with modified configuration"
    else
        warning "Nginx reload failed, trying restart..."
        if systemctl restart nginx 2>/dev/null; then
            log "✓ Nginx restarted successfully"
        else
            error "✗ Nginx restart failed"
            # Restore backup
            cp "${FASTPANEL_SITE_CONF}.backup" "$FASTPANEL_SITE_CONF"
            systemctl reload nginx
            exit 1
        fi
    fi
    
else
    error "✗ Modified configuration test failed"
    echo "Nginx config test output:" >> "$LOG_FILE"
    nginx -t 2>&1 >> "$LOG_FILE"
    
    # Restore original configuration
    warning "Restoring original configuration..."
    cp "${FASTPANEL_SITE_CONF}.backup" "$FASTPANEL_SITE_CONF"
    
    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        log "✓ Original configuration restored"
    fi
    
    exit 1
fi

# Step 6: Verify New Bindings
section "Step 6: Verifying New Bindings"

info "Checking new port bindings..."
sleep 3

NEW_BINDINGS=$(netstat -tlnp | grep ":80 " 2>/dev/null || echo "No bindings found")
echo "Current port 80 bindings:" | tee -a "$LOG_FILE"
echo "$NEW_BINDINGS" | tee -a "$LOG_FILE"

# Check for local bindings
LOCAL_BINDING_COUNT=0
if echo "$NEW_BINDINGS" | grep -q "127.0.0.1:80"; then
    log "✅ 127.0.0.1:80 binding detected"
    ((LOCAL_BINDING_COUNT++))
fi

if echo "$NEW_BINDINGS" | grep -q "0.0.0.0:80"; then
    log "✅ 0.0.0.0:80 (universal) binding detected"
    ((LOCAL_BINDING_COUNT++))
fi

if [ $LOCAL_BINDING_COUNT -eq 0 ]; then
    warning "⚠️ No local bindings detected - configuration may not have applied"
fi

# Step 7: Connection Tests
section "Step 7: Connection Tests"

info "Testing connections..."

# Test localhost
info "Testing http://localhost..."
LOCALHOST_TEST=$(timeout 10 curl -s -w "HTTPCODE:%{http_code}" "http://localhost" 2>/dev/null || echo "HTTPCODE:000")
LOCALHOST_CODE=$(echo "$LOCALHOST_TEST" | grep "HTTPCODE:" | cut -d':' -f2)

# Test 127.0.0.1
info "Testing http://127.0.0.1..."
LOCAL_IP_TEST=$(timeout 10 curl -s -w "HTTPCODE:%{http_code}" "http://127.0.0.1" 2>/dev/null || echo "HTTPCODE:000")
LOCAL_IP_CODE=$(echo "$LOCAL_IP_TEST" | grep "HTTPCODE:" | cut -d':' -f2)

# Test external IP
info "Testing http://$EXTERNAL_IP..."
EXTERNAL_TEST=$(timeout 10 curl -s -w "HTTPCODE:%{http_code}" "http://$EXTERNAL_IP" 2>/dev/null || echo "HTTPCODE:000")
EXTERNAL_CODE=$(echo "$EXTERNAL_TEST" | grep "HTTPCODE:" | cut -d':' -f2)

# Step 8: Results Analysis
section "Step 8: Results Analysis"

echo ""
echo "=================================================="
echo "🎯 FASTPANEL NGINX FIX RESULTS"
echo "=================================================="
echo "Localhost (hostname): HTTP $LOCALHOST_CODE"
echo "Localhost (127.0.0.1): HTTP $LOCAL_IP_CODE"
echo "External IP ($EXTERNAL_IP): HTTP $EXTERNAL_CODE"
echo ""

# Count successful connections
SUCCESS_COUNT=0
if [[ "$LOCALHOST_CODE" =~ ^[235] ]]; then
    ((SUCCESS_COUNT++))
fi
if [[ "$LOCAL_IP_CODE" =~ ^[235] ]]; then
    ((SUCCESS_COUNT++))
fi

if [ $SUCCESS_COUNT -ge 1 ]; then
    log "🎉 SUCCESS: Local access is now working!"
    echo ""
    echo "✅ Your website is now accessible locally:"
    if [[ "$LOCALHOST_CODE" =~ ^[235] ]]; then
        echo "   • http://localhost (HTTP $LOCALHOST_CODE)"
    fi
    if [[ "$LOCAL_IP_CODE" =~ ^[235] ]]; then
        echo "   • http://127.0.0.1 (HTTP $LOCAL_IP_CODE)"
    fi
    echo ""
    
    if [ "$LOCALHOST_CODE" = "500" ] || [ "$LOCAL_IP_CODE" = "500" ]; then
        warning "⚠️ Note: Getting HTTP 500 errors"
        echo ""
        echo "🔍 Connection is FIXED, but you have application errors:"
        echo "• The Nginx binding issue is resolved"
        echo "• HTTP 500 = Laravel/PHP application errors"
        echo ""
        echo "🔧 To fix HTTP 500 application errors:"
        echo "1. Check Laravel logs:"
        echo "   tail -f $WEB_ROOT/storage/logs/laravel.log"
        echo ""
        echo "2. Common fixes:"
        echo "   cd $WEB_ROOT"
        echo "   composer install --no-dev"
        echo "   php artisan key:generate"
        echo "   chmod -R 775 storage bootstrap/cache"
    else
        echo "🧪 Test your website:"
        echo "   • Main page: http://localhost"
        echo "   • BMI Calculator: http://localhost/bmi-calculator"
        echo "   • Currency Converter: http://localhost/currency-converter"
    fi
    
else
    error "❌ Connection issues persist"
    echo ""
    echo "🔍 Possible issues:"
    echo "• FastPanel may be overriding our changes"
    echo "• Additional firewall restrictions"
    echo "• PHP-FPM configuration problems"
    echo ""
    echo "🔧 Manual steps:"
    echo "1. Check FastPanel web interface for site settings"
    echo "2. Verify the modified config is still in place:"
    echo "   cat $FASTPANEL_SITE_CONF"
    echo "3. Check nginx error logs:"
    echo "   tail -f /var/log/nginx/error.log"
fi

echo ""
echo "📊 Configuration Summary:"
echo "   • Modified: $FASTPANEL_SITE_CONF"
echo "   • Backup: ${FASTPANEL_SITE_CONF}.backup"
echo "   • Full backup: $BACKUP_DIR"
echo ""
echo "📄 Detailed log: $LOG_FILE"
echo ""

if [ $SUCCESS_COUNT -ge 1 ]; then
    echo "🎊 FastPanel Nginx binding issue RESOLVED!"
    if [ "$LOCALHOST_CODE" = "500" ] || [ "$LOCAL_IP_CODE" = "500" ]; then
        echo "Next: Fix the HTTP 500 application errors."
    else
        echo "Your website is fully functional!"
    fi
else
    echo "🔧 Additional troubleshooting needed."
    echo "Check FastPanel settings or contact hosting support."
fi

echo ""
echo "=================================================="

# Cleanup
rm -f "$TEMP_CONFIG"
