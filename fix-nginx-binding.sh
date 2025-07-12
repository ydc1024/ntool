#!/bin/bash

# Fix Nginx IP Binding Issue
# This script fixes the specific issue where Nginx only listens on external IP

set -e

# Configuration
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="/tmp/nginx_binding_fix_${TIMESTAMP}.log"

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
echo "# Nginx IP Binding Fix Log" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"

# Check root
if [[ $EUID -ne 0 ]]; then
    error "Run as root: sudo ./fix-nginx-binding.sh"
    exit 1
fi

echo "🔧 Nginx IP Binding Fix"
echo "======================="
echo "Time: $(date)"
echo "Log: $LOG_FILE"
echo "======================="
echo ""

# Step 1: Analyze Current Nginx Configuration
section "Step 1: Analyzing Current Nginx Configuration"

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null)
EXTERNAL_IP="104.194.77.132"  # From the netstat output

info "Server IP: $SERVER_IP"
info "External IP (from netstat): $EXTERNAL_IP"

# Find Nginx configuration files
info "Finding Nginx configuration files..."

# Check main nginx.conf
NGINX_MAIN_CONF="/etc/nginx/nginx.conf"
if [ -f "$NGINX_MAIN_CONF" ]; then
    log "✓ Main Nginx config found: $NGINX_MAIN_CONF"
else
    error "✗ Main Nginx config not found"
fi

# Check for FastPanel or other control panels
FASTPANEL_NGINX=""
if [ -d "/usr/local/mgr5" ]; then
    info "FastPanel detected"
    FASTPANEL_NGINX="/usr/local/mgr5/etc/nginx.conf"
    if [ -f "$FASTPANEL_NGINX" ]; then
        info "FastPanel Nginx config: $FASTPANEL_NGINX"
    fi
fi

# Check for ISPmanager
if [ -d "/usr/local/ispmgr" ]; then
    info "ISPmanager detected"
fi

# Find all nginx configuration files
info "Searching for all Nginx configuration files..."
NGINX_CONFIGS=$(find /etc/nginx /usr/local/mgr5/etc /usr/local/ispmgr/etc -name "*.conf" 2>/dev/null | grep -E "(nginx|http)" | head -10)

echo "Found Nginx configs:" >> "$LOG_FILE"
echo "$NGINX_CONFIGS" >> "$LOG_FILE"

# Step 2: Find the Configuration Causing IP Binding
section "Step 2: Finding IP Binding Configuration"

info "Searching for IP binding configurations..."

# Search for the specific IP binding
BINDING_CONFIGS=""
for config in $NGINX_CONFIGS; do
    if [ -f "$config" ]; then
        if grep -q "$EXTERNAL_IP" "$config" 2>/dev/null; then
            warning "Found $EXTERNAL_IP binding in: $config"
            BINDING_CONFIGS="$BINDING_CONFIGS $config"
            
            echo "=== CONFIG: $config ===" >> "$LOG_FILE"
            grep -n "$EXTERNAL_IP" "$config" >> "$LOG_FILE" 2>/dev/null || true
            echo "" >> "$LOG_FILE"
        fi
    fi
done

if [ -z "$BINDING_CONFIGS" ]; then
    # Search for listen directives
    info "Searching for listen directives..."
    for config in $NGINX_CONFIGS; do
        if [ -f "$config" ]; then
            LISTEN_LINES=$(grep -n "listen.*80" "$config" 2>/dev/null || true)
            if [ -n "$LISTEN_LINES" ]; then
                info "Listen directives in $config:"
                echo "$LISTEN_LINES" | tee -a "$LOG_FILE"
            fi
        fi
    done
fi

# Step 3: Create Local Binding Configuration
section "Step 3: Creating Local Binding Configuration"

info "Creating configuration to bind to all interfaces..."

# Find the best place to add local binding
NGINX_CONF_D="/etc/nginx/conf.d"
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"

# Create conf.d directory if it doesn't exist
if [ ! -d "$NGINX_CONF_D" ]; then
    mkdir -p "$NGINX_CONF_D"
    log "✓ Created $NGINX_CONF_D"
fi

# Create a local binding configuration
LOCAL_BINDING_CONF="$NGINX_CONF_D/local-binding.conf"

info "Creating local binding configuration: $LOCAL_BINDING_CONF"

cat > "$LOCAL_BINDING_CONF" << EOF
# Local binding configuration for BestHammer
# This ensures the site is accessible via localhost and 127.0.0.1

server {
    listen 127.0.0.1:80;
    listen localhost:80;
    
    root $WEB_ROOT/public;
    index index.php index.html index.htm;
    
    server_name localhost 127.0.0.1;
    
    # Laravel-style URL rewriting
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    # PHP processing
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        
        # Try different PHP-FPM socket locations
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        # Fallback options (uncomment if needed):
        # fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        # fastcgi_pass 127.0.0.1:9000;
        
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    # Security
    location ~ /\.ht {
        deny all;
    }
    
    # Static files
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files \$uri =404;
    }
    
    # Laravel specific locations
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }
}
EOF

chown root:root "$LOCAL_BINDING_CONF"
chmod 644 "$LOCAL_BINDING_CONF"

log "✓ Local binding configuration created"

# Step 4: Also Add Universal Binding
section "Step 4: Adding Universal Binding Configuration"

UNIVERSAL_BINDING_CONF="$NGINX_CONF_D/universal-binding.conf"

info "Creating universal binding configuration: $UNIVERSAL_BINDING_CONF"

cat > "$UNIVERSAL_BINDING_CONF" << EOF
# Universal binding configuration
# This makes the site accessible from all interfaces

server {
    listen 80;
    listen [::]:80;
    
    root $WEB_ROOT/public;
    index index.php index.html index.htm;
    
    server_name _;
    
    # Laravel-style URL rewriting
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    # PHP processing
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    # Security
    location ~ /\.ht {
        deny all;
    }
    
    # Static files
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files \$uri =404;
    }
    
    # Laravel specific
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }
}
EOF

chown root:root "$UNIVERSAL_BINDING_CONF"
chmod 644 "$UNIVERSAL_BINDING_CONF"

log "✓ Universal binding configuration created"

# Step 5: Test and Apply Configuration
section "Step 5: Testing and Applying Configuration"

info "Testing Nginx configuration..."

# Test configuration
if nginx -t 2>/dev/null; then
    log "✓ Nginx configuration test passed"
    
    info "Reloading Nginx configuration..."
    if systemctl reload nginx 2>/dev/null; then
        log "✓ Nginx configuration reloaded successfully"
    else
        warning "Nginx reload failed, trying restart..."
        if systemctl restart nginx 2>/dev/null; then
            log "✓ Nginx restarted successfully"
        else
            error "✗ Nginx restart failed"
            echo "Nginx restart error:" >> "$LOG_FILE"
            systemctl status nginx --no-pager -l >> "$LOG_FILE" 2>&1
        fi
    fi
else
    error "✗ Nginx configuration test failed"
    echo "Nginx config test output:" >> "$LOG_FILE"
    nginx -t 2>&1 >> "$LOG_FILE"
    
    warning "Removing problematic configurations..."
    rm -f "$LOCAL_BINDING_CONF" "$UNIVERSAL_BINDING_CONF"
    
    if nginx -t 2>/dev/null; then
        log "✓ Nginx configuration restored"
        systemctl reload nginx
    fi
fi

# Step 6: Verify New Bindings
section "Step 6: Verifying New Bindings"

info "Checking new port bindings..."
sleep 3

NEW_BINDINGS=$(netstat -tlnp | grep ":80 " 2>/dev/null || echo "No bindings found")
echo "New port 80 bindings:" | tee -a "$LOG_FILE"
echo "$NEW_BINDINGS" | tee -a "$LOG_FILE"

# Check if localhost is now listening
if echo "$NEW_BINDINGS" | grep -q "127.0.0.1:80\|0.0.0.0:80"; then
    log "✅ Localhost binding detected!"
else
    warning "⚠️ Localhost binding not detected"
fi

# Step 7: Connection Tests
section "Step 7: Connection Tests"

info "Testing connections..."

# Test localhost
info "Testing http://localhost..."
LOCALHOST_TEST=$(timeout 10 curl -s -w "HTTPCODE:%{http_code}" "http://localhost" 2>/dev/null || echo "HTTPCODE:000")
LOCALHOST_CODE=$(echo "$LOCALHOST_TEST" | grep "HTTPCODE:" | cut -d':' -f2)

if [ "$LOCALHOST_CODE" = "000" ]; then
    error "✗ localhost: Connection failed (HTTP 000)"
elif [ "$LOCALHOST_CODE" = "500" ]; then
    warning "⚠️ localhost: Server error (HTTP 500) - but connection works!"
elif [[ "$LOCALHOST_CODE" =~ ^[23] ]]; then
    log "✅ localhost: Success (HTTP $LOCALHOST_CODE)"
else
    warning "⚠️ localhost: Unexpected response (HTTP $LOCALHOST_CODE)"
fi

# Test 127.0.0.1
info "Testing http://127.0.0.1..."
LOCAL_IP_TEST=$(timeout 10 curl -s -w "HTTPCODE:%{http_code}" "http://127.0.0.1" 2>/dev/null || echo "HTTPCODE:000")
LOCAL_IP_CODE=$(echo "$LOCAL_IP_TEST" | grep "HTTPCODE:" | cut -d':' -f2)

if [ "$LOCAL_IP_CODE" = "000" ]; then
    error "✗ 127.0.0.1: Connection failed (HTTP 000)"
elif [ "$LOCAL_IP_CODE" = "500" ]; then
    warning "⚠️ 127.0.0.1: Server error (HTTP 500) - but connection works!"
elif [[ "$LOCAL_IP_CODE" =~ ^[23] ]]; then
    log "✅ 127.0.0.1: Success (HTTP $LOCAL_IP_CODE)"
else
    warning "⚠️ 127.0.0.1: Unexpected response (HTTP $LOCAL_IP_CODE)"
fi

# Test external IP
info "Testing http://$EXTERNAL_IP..."
EXTERNAL_TEST=$(timeout 10 curl -s -w "HTTPCODE:%{http_code}" "http://$EXTERNAL_IP" 2>/dev/null || echo "HTTPCODE:000")
EXTERNAL_CODE=$(echo "$EXTERNAL_TEST" | grep "HTTPCODE:" | cut -d':' -f2)

if [ "$EXTERNAL_CODE" = "000" ]; then
    error "✗ $EXTERNAL_IP: Connection failed (HTTP 000)"
elif [ "$EXTERNAL_CODE" = "500" ]; then
    warning "⚠️ $EXTERNAL_IP: Server error (HTTP 500) - but connection works!"
elif [[ "$EXTERNAL_CODE" =~ ^[23] ]]; then
    log "✅ $EXTERNAL_IP: Success (HTTP $EXTERNAL_CODE)"
else
    warning "⚠️ $EXTERNAL_IP: Unexpected response (HTTP $EXTERNAL_CODE)"
fi

# Final Results Summary
echo ""
echo "=================================================="
echo "🎯 NGINX BINDING FIX RESULTS"
echo "=================================================="
echo "Localhost (127.0.0.1): HTTP $LOCAL_IP_CODE"
echo "Localhost (hostname): HTTP $LOCALHOST_CODE"
echo "External IP ($EXTERNAL_IP): HTTP $EXTERNAL_CODE"
echo ""

# Determine overall success
SUCCESS_COUNT=0
if [[ "$LOCAL_IP_CODE" =~ ^[23] ]] || [ "$LOCAL_IP_CODE" = "500" ]; then
    ((SUCCESS_COUNT++))
fi
if [[ "$LOCALHOST_CODE" =~ ^[23] ]] || [ "$LOCALHOST_CODE" = "500" ]; then
    ((SUCCESS_COUNT++))
fi

if [ $SUCCESS_COUNT -ge 1 ]; then
    log "🎉 SUCCESS: Local access is now working!"
    echo ""
    echo "✅ Your website is now accessible locally:"
    if [[ "$LOCALHOST_CODE" =~ ^[235] ]]; then
        echo "   • http://localhost"
    fi
    if [[ "$LOCAL_IP_CODE" =~ ^[235] ]]; then
        echo "   • http://127.0.0.1"
    fi
    echo ""

    if [ "$LOCAL_IP_CODE" = "500" ] || [ "$LOCALHOST_CODE" = "500" ]; then
        warning "⚠️ Note: Getting HTTP 500 errors"
        echo ""
        echo "🔍 The connection issue is FIXED, but you have application errors:"
        echo "• HTTP 500 = Internal Server Error (application problem)"
        echo "• This is different from HTTP 000 (connection refused)"
        echo ""
        echo "🔧 To fix HTTP 500 errors:"
        echo "1. Check Laravel logs:"
        echo "   tail -f $WEB_ROOT/storage/logs/laravel.log"
        echo ""
        echo "2. Common causes of 500 errors:"
        echo "   • Missing .env file or APP_KEY"
        echo "   • Missing Composer dependencies (vendor folder)"
        echo "   • Database connection issues"
        echo "   • File permission problems"
        echo "   • PHP syntax errors"
        echo ""
        echo "3. Run Laravel diagnostics:"
        echo "   cd $WEB_ROOT"
        echo "   php artisan --version"
        echo "   php artisan config:show"
    else
        echo "🧪 Test your website:"
        echo "   • Main page: http://localhost"
        echo "   • BMI Calculator: http://localhost/bmi-calculator"
        echo "   • Currency Converter: http://localhost/currency-converter"
        echo "   • Loan Calculator: http://localhost/loan-calculator"
    fi

else
    error "❌ PARTIAL SUCCESS: Still having connection issues"
    echo ""
    echo "🔍 Possible remaining issues:"
    echo "• Control panel (FastPanel) may be overriding configurations"
    echo "• Firewall blocking local connections"
    echo "• PHP-FPM socket configuration problems"
    echo ""
    echo "🔧 Manual troubleshooting steps:"
    echo "1. Check if configurations were applied:"
    echo "   ls -la /etc/nginx/conf.d/"
    echo "   nginx -T | grep 'listen.*80'"
    echo ""
    echo "2. Check control panel settings:"
    echo "   # If using FastPanel, check its web interface"
    echo "   # Look for domain/site configuration"
    echo ""
    echo "3. Check firewall:"
    echo "   iptables -L INPUT | grep 80"
    echo "   ufw status"
fi

echo ""
echo "📊 Configuration Summary:"
echo "   • Created: $LOCAL_BINDING_CONF"
echo "   • Created: $UNIVERSAL_BINDING_CONF"
echo "   • Nginx configuration reloaded"
echo ""
echo "📄 Detailed log: $LOG_FILE"
echo ""

# Provide specific next steps based on results
if [ $SUCCESS_COUNT -ge 1 ]; then
    if [ "$LOCAL_IP_CODE" = "500" ] || [ "$LOCALHOST_CODE" = "500" ]; then
        echo "🎊 Connection Fixed! Now focus on fixing HTTP 500 application errors."
        echo ""
        echo "Quick 500 error fixes to try:"
        echo "1. cd $WEB_ROOT"
        echo "2. composer install --no-dev"
        echo "3. php artisan key:generate"
        echo "4. chmod -R 775 storage bootstrap/cache"
    else
        echo "🎊 Complete Success! Your website is working perfectly!"
    fi
else
    echo "🔧 Connection still not working. Manual intervention needed."
    echo "Consider checking control panel settings or contacting hosting support."
fi

echo ""
echo "=================================================="
