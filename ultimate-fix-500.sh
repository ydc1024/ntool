#!/bin/bash

# Ultimate HTTP 500/000 Error Fix Script
# This script diagnoses and fixes the real underlying issues

set -e

# Configuration
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="/tmp/ultimate_fix_${TIMESTAMP}.log"

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
echo "# Ultimate HTTP Error Fix Log" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"

# Check root
if [[ $EUID -ne 0 ]]; then
    error "Run as root: sudo ./ultimate-fix-500.sh"
    exit 1
fi

echo "🚨 Ultimate HTTP Error Fix"
echo "=========================="
echo "Time: $(date)"
echo "Log: $LOG_FILE"
echo "=========================="
echo ""

# Step 1: Basic System Diagnosis
section "Step 1: Basic System Diagnosis"

# Check if web root exists
if [ ! -d "$WEB_ROOT" ]; then
    error "Web root not found: $WEB_ROOT"
    info "Creating web root directory..."
    mkdir -p "$WEB_ROOT"
    chown "$WEB_USER:$WEB_USER" "$WEB_ROOT"
    log "✓ Web root created"
fi

cd "$WEB_ROOT" || exit 1

# Check what's actually listening on port 80
info "Checking what's listening on port 80..."
PORT_80_INFO=$(netstat -tlnp | grep ":80 " 2>/dev/null || echo "Nothing listening on port 80")
echo "Port 80 status: $PORT_80_INFO" | tee -a "$LOG_FILE"

if echo "$PORT_80_INFO" | grep -q "nginx"; then
    log "✓ Nginx is listening on port 80"
elif echo "$PORT_80_INFO" | grep -q ":80"; then
    warning "Something else is using port 80: $PORT_80_INFO"
else
    error "Nothing is listening on port 80!"
fi

# Check what's actually listening on port 443
PORT_443_INFO=$(netstat -tlnp | grep ":443 " 2>/dev/null || echo "Nothing listening on port 443")
echo "Port 443 status: $PORT_443_INFO" | tee -a "$LOG_FILE"

# Step 2: Service Status Deep Check
section "Step 2: Service Status Deep Check"

# Check Nginx status in detail
info "Checking Nginx status..."
if systemctl is-active --quiet nginx; then
    log "✓ Nginx service is active"
    
    # Check Nginx configuration
    if nginx -t 2>/dev/null; then
        log "✓ Nginx configuration is valid"
    else
        error "✗ Nginx configuration is invalid"
        echo "Nginx config test output:" >> "$LOG_FILE"
        nginx -t 2>&1 >> "$LOG_FILE"
    fi
    
    # Check Nginx error log
    if [ -f "/var/log/nginx/error.log" ]; then
        RECENT_NGINX_ERRORS=$(tail -10 /var/log/nginx/error.log | wc -l)
        if [ "$RECENT_NGINX_ERRORS" -gt 0 ]; then
            warning "Recent Nginx errors found"
            echo "=== RECENT NGINX ERRORS ===" >> "$LOG_FILE"
            tail -10 /var/log/nginx/error.log >> "$LOG_FILE"
        fi
    fi
else
    error "✗ Nginx service is not active"
    info "Attempting to start Nginx..."
    
    if systemctl start nginx 2>/dev/null; then
        log "✓ Nginx started successfully"
    else
        error "✗ Failed to start Nginx"
        echo "Nginx start error:" >> "$LOG_FILE"
        systemctl status nginx --no-pager -l >> "$LOG_FILE" 2>&1
    fi
fi

# Check PHP-FPM status in detail
info "Checking PHP-FPM status..."
PHP_FPM_SERVICE=$(systemctl list-units --type=service | grep php | grep fpm | awk '{print $1}' | head -1)

if [ -n "$PHP_FPM_SERVICE" ]; then
    info "Found PHP-FPM service: $PHP_FPM_SERVICE"
    
    if systemctl is-active --quiet "$PHP_FPM_SERVICE"; then
        log "✓ $PHP_FPM_SERVICE is active"
    else
        error "✗ $PHP_FPM_SERVICE is not active"
        info "Attempting to start $PHP_FPM_SERVICE..."
        
        if systemctl start "$PHP_FPM_SERVICE" 2>/dev/null; then
            log "✓ $PHP_FPM_SERVICE started successfully"
        else
            error "✗ Failed to start $PHP_FPM_SERVICE"
            echo "$PHP_FPM_SERVICE start error:" >> "$LOG_FILE"
            systemctl status "$PHP_FPM_SERVICE" --no-pager -l >> "$LOG_FILE" 2>&1
        fi
    fi
else
    error "✗ No PHP-FPM service found"
    info "Available PHP services:"
    systemctl list-units --type=service | grep php | tee -a "$LOG_FILE"
fi

# Step 3: Nginx Configuration Fix
section "Step 3: Nginx Configuration Fix"

info "Checking and fixing Nginx configuration..."

# Find the correct Nginx site configuration
NGINX_SITES_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"

# Check if FastPanel is being used
if [ -d "/usr/local/mgr5" ]; then
    info "FastPanel detected - checking FastPanel Nginx config"
    FASTPANEL_NGINX_CONF="/usr/local/mgr5/etc/nginx.conf"
    if [ -f "$FASTPANEL_NGINX_CONF" ]; then
        info "FastPanel Nginx config found: $FASTPANEL_NGINX_CONF"
    fi
fi

# Create or fix the default site configuration
DEFAULT_SITE="$NGINX_SITES_DIR/default"
if [ ! -f "$DEFAULT_SITE" ]; then
    info "Creating default Nginx site configuration..."
    
    cat > "$DEFAULT_SITE" << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root $WEB_ROOT/public;
    index index.php index.html index.htm;
    
    server_name _;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.ht {
        deny all;
    }
    
    # Laravel specific
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files \$uri =404;
    }
}
EOF
    
    log "✓ Default Nginx site configuration created"
else
    info "Default Nginx site configuration exists"
fi

# Enable the site
if [ ! -L "$NGINX_ENABLED_DIR/default" ]; then
    ln -sf "$DEFAULT_SITE" "$NGINX_ENABLED_DIR/default"
    log "✓ Default site enabled"
fi

# Test and reload Nginx configuration
if nginx -t 2>/dev/null; then
    log "✓ Nginx configuration test passed"
    
    if systemctl reload nginx 2>/dev/null; then
        log "✓ Nginx configuration reloaded"
    else
        warning "Failed to reload Nginx - attempting restart"
        systemctl restart nginx
    fi
else
    error "✗ Nginx configuration test failed"
    echo "Nginx config test output:" >> "$LOG_FILE"
    nginx -t 2>&1 >> "$LOG_FILE"
fi

# Step 4: PHP-FPM Socket Check and Fix
section "Step 4: PHP-FPM Socket Check and Fix"

info "Checking PHP-FPM socket configuration..."

# Find PHP version
PHP_VERSION=$(php -v | head -n1 | grep -oP '\d+\.\d+' | head -1)
info "PHP Version: $PHP_VERSION"

# Check if PHP-FPM socket exists
PHP_SOCK="/var/run/php/php${PHP_VERSION}-fpm.sock"
if [ -S "$PHP_SOCK" ]; then
    log "✓ PHP-FPM socket exists: $PHP_SOCK"
else
    error "✗ PHP-FPM socket not found: $PHP_SOCK"
    
    # List available sockets
    info "Available PHP sockets:"
    ls -la /var/run/php/ 2>/dev/null | tee -a "$LOG_FILE" || echo "No PHP sockets found"
    
    # Try to find any PHP-FPM socket
    AVAILABLE_SOCK=$(find /var/run/php/ -name "php*-fpm.sock" 2>/dev/null | head -1)
    if [ -n "$AVAILABLE_SOCK" ]; then
        warning "Found alternative socket: $AVAILABLE_SOCK"
        info "Updating Nginx configuration to use correct socket..."
        
        # Update Nginx configuration with correct socket
        sed -i "s|fastcgi_pass unix:/var/run/php/php.*-fpm.sock;|fastcgi_pass unix:$AVAILABLE_SOCK;|g" "$DEFAULT_SITE"
        
        # Reload Nginx
        nginx -t && systemctl reload nginx
        log "✓ Nginx updated with correct PHP socket"
    fi
fi

# Step 5: Laravel Application Fix
section "Step 5: Laravel Application Fix"

info "Ensuring Laravel application is properly set up..."

# Create basic Laravel structure if missing
if [ ! -f "public/index.php" ]; then
    info "Creating Laravel public/index.php..."
    
    mkdir -p public
    cat > public/index.php << 'EOF'
<?php
// Basic test page
echo "<h1>BestHammer NTool Platform</h1>";
echo "<p>Server Time: " . date('Y-m-d H:i:s') . "</p>";
echo "<p>PHP Version: " . phpversion() . "</p>";
echo "<p>Document Root: " . $_SERVER['DOCUMENT_ROOT'] . "</p>";

// Test Laravel if available
if (file_exists(__DIR__ . '/../vendor/autoload.php')) {
    echo "<p>✅ Composer autoloader found</p>";
    
    try {
        require_once __DIR__ . '/../vendor/autoload.php';
        echo "<p>✅ Autoloader loaded successfully</p>";
        
        if (file_exists(__DIR__ . '/../bootstrap/app.php')) {
            echo "<p>✅ Laravel bootstrap found</p>";
            $app = require_once __DIR__ . '/../bootstrap/app.php';
            echo "<p>✅ Laravel application loaded</p>";
        } else {
            echo "<p>⚠️ Laravel bootstrap not found</p>";
        }
    } catch (Exception $e) {
        echo "<p>❌ Error: " . $e->getMessage() . "</p>";
    }
} else {
    echo "<p>⚠️ Composer autoloader not found</p>";
}
EOF
    
    chown "$WEB_USER:$WEB_USER" public/index.php
    log "✓ Basic test page created"
fi

# Fix permissions
chown -R "$WEB_USER:$WEB_USER" "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"
if [ -d "storage" ]; then
    chmod -R 775 storage
fi
if [ -d "bootstrap/cache" ]; then
    chmod -R 775 bootstrap/cache
fi

log "✓ Permissions fixed"

# Step 6: Firewall and Security Check
section "Step 6: Firewall and Security Check"

info "Checking firewall configuration..."

# Check UFW status
if command -v ufw &>/dev/null; then
    UFW_STATUS=$(ufw status 2>/dev/null || echo "inactive")
    info "UFW Status: $UFW_STATUS"

    if echo "$UFW_STATUS" | grep -q "Status: active"; then
        # Check if port 80 is allowed
        if echo "$UFW_STATUS" | grep -q "80/tcp"; then
            log "✓ Port 80 is allowed in UFW"
        else
            warning "Port 80 not explicitly allowed in UFW"
            info "Adding UFW rule for port 80..."
            ufw allow 80/tcp
            log "✓ Port 80 allowed in UFW"
        fi
    fi
fi

# Check iptables
IPTABLES_RULES=$(iptables -L INPUT -n 2>/dev/null | grep -c "dpt:80" || echo "0")
if [ "$IPTABLES_RULES" -gt 0 ]; then
    log "✓ iptables rules found for port 80"
else
    info "No specific iptables rules for port 80 (may be using default ACCEPT)"
fi

# Step 7: Real Connection Test
section "Step 7: Real Connection Test"

info "Performing comprehensive connection tests..."

# Wait for services to be ready
sleep 3

# Test 1: Direct socket test
info "Testing direct socket connection..."
if timeout 5 bash -c "</dev/tcp/127.0.0.1/80" 2>/dev/null; then
    log "✓ Socket connection to port 80 successful"
else
    error "✗ Cannot connect to port 80 via socket"
fi

# Test 2: Netcat test
if command -v nc &>/dev/null; then
    info "Testing with netcat..."
    if echo -e "GET / HTTP/1.0\r\n\r\n" | nc -w 5 127.0.0.1 80 | grep -q "HTTP"; then
        log "✓ Netcat HTTP test successful"
    else
        error "✗ Netcat HTTP test failed"
    fi
fi

# Test 3: Curl with verbose output
info "Testing with curl (verbose)..."
CURL_OUTPUT=$(curl -v -s --connect-timeout 10 "http://127.0.0.1" 2>&1)
CURL_EXIT_CODE=$?

echo "=== CURL VERBOSE OUTPUT ===" >> "$LOG_FILE"
echo "$CURL_OUTPUT" >> "$LOG_FILE"
echo "Curl exit code: $CURL_EXIT_CODE" >> "$LOG_FILE"

if [ $CURL_EXIT_CODE -eq 0 ]; then
    log "✅ Curl test successful"
elif [ $CURL_EXIT_CODE -eq 7 ]; then
    error "❌ Curl: Connection refused (exit code 7)"
elif [ $CURL_EXIT_CODE -eq 28 ]; then
    error "❌ Curl: Timeout (exit code 28)"
else
    error "❌ Curl failed with exit code: $CURL_EXIT_CODE"
fi

# Test 4: Test different URLs
TEST_URLS=("http://127.0.0.1" "http://localhost")
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null)
if [ -n "$SERVER_IP" ]; then
    TEST_URLS+=("http://$SERVER_IP")
fi

for url in "${TEST_URLS[@]}"; do
    info "Testing URL: $url"

    HTTP_RESPONSE=$(curl -s -w "HTTPCODE:%{http_code}\nTIME:%{time_total}" --connect-timeout 10 "$url" 2>/dev/null || echo "HTTPCODE:000")
    HTTP_CODE=$(echo "$HTTP_RESPONSE" | grep "HTTPCODE:" | cut -d':' -f2)

    if [ "$HTTP_CODE" = "000" ]; then
        error "✗ $url: Connection failed (HTTP 000)"
    elif [ "$HTTP_CODE" = "500" ]; then
        error "✗ $url: Internal Server Error (HTTP 500)"
    elif [[ "$HTTP_CODE" =~ ^[23] ]]; then
        log "✅ $url: Success (HTTP $HTTP_CODE)"
    else
        warning "⚠️ $url: Unexpected response (HTTP $HTTP_CODE)"
    fi
done

# Step 8: Service Restart and Final Test
section "Step 8: Service Restart and Final Test"

info "Performing final service restart..."

# Stop services
systemctl stop nginx 2>/dev/null || true
if [ -n "$PHP_FPM_SERVICE" ]; then
    systemctl stop "$PHP_FPM_SERVICE" 2>/dev/null || true
fi

sleep 2

# Start services
if [ -n "$PHP_FPM_SERVICE" ]; then
    if systemctl start "$PHP_FPM_SERVICE"; then
        log "✓ $PHP_FPM_SERVICE started"
    else
        error "✗ Failed to start $PHP_FPM_SERVICE"
    fi
fi

if systemctl start nginx; then
    log "✓ Nginx started"
else
    error "✗ Failed to start Nginx"
fi

sleep 5

# Final comprehensive test
info "Final comprehensive test..."
FINAL_TEST=$(curl -s -w "HTTPCODE:%{http_code}" --connect-timeout 10 "http://127.0.0.1" 2>/dev/null || echo "HTTPCODE:000")
FINAL_CODE=$(echo "$FINAL_TEST" | grep "HTTPCODE:" | cut -d':' -f2)

echo ""
echo "=================================================="
echo "🎯 ULTIMATE FIX RESULTS"
echo "=================================================="
echo "Final HTTP Status: $FINAL_CODE"

if [ "$FINAL_CODE" = "000" ]; then
    error "❌ CRITICAL: Still cannot connect to web server"
    echo ""
    echo "🔍 Possible remaining issues:"
    echo "• Web server not starting properly"
    echo "• Port 80 blocked by system firewall"
    echo "• FastPanel or other control panel conflicts"
    echo "• PHP-FPM socket configuration issues"
    echo ""
    echo "🔧 Manual steps to try:"
    echo "1. Check service status:"
    echo "   systemctl status nginx"
    echo "   systemctl status php*-fpm"
    echo ""
    echo "2. Check what's using port 80:"
    echo "   netstat -tlnp | grep :80"
    echo ""
    echo "3. Check logs:"
    echo "   tail -f /var/log/nginx/error.log"
    echo "   journalctl -u nginx -f"

elif [ "$FINAL_CODE" = "500" ]; then
    warning "⚠️ PARTIAL SUCCESS: Server responding but with 500 error"
    echo ""
    echo "🔍 Server is now accessible but returning 500 errors"
    echo "This indicates application-level issues:"
    echo "• Laravel configuration problems"
    echo "• Missing dependencies"
    echo "• Database connection issues"
    echo "• PHP errors in the application"
    echo ""
    echo "🔧 Next steps:"
    echo "1. Check Laravel logs:"
    echo "   tail -f $WEB_ROOT/storage/logs/laravel.log"
    echo ""
    echo "2. Check PHP-FPM logs:"
    echo "   tail -f /var/log/php*-fpm.log"

elif [[ "$FINAL_CODE" =~ ^[23] ]]; then
    log "🎉 SUCCESS: Web server is now working!"
    echo ""
    echo "✅ Your website is now accessible:"
    echo "   • http://127.0.0.1"
    echo "   • http://localhost"
    if [ -n "$SERVER_IP" ]; then
        echo "   • http://$SERVER_IP"
    fi
    echo ""
    echo "🧪 Test these pages:"
    echo "   • Main page: /"
    echo "   • Test page shows server info and Laravel status"
    echo ""
    echo "🔧 If you need the full Laravel application:"
    echo "1. Install Composer dependencies"
    echo "2. Set up proper Laravel files"
    echo "3. Configure database connection"

else
    warning "⚠️ UNKNOWN: Unexpected response code $FINAL_CODE"
    echo ""
    echo "🔍 Manual verification needed"
fi

echo ""
echo "📄 Detailed log: $LOG_FILE"
echo "📁 Web root: $WEB_ROOT"
echo ""
echo "=================================================="
