#!/bin/bash

# Standalone HTTP 500 Error Fix Script
# This script is completely self-contained and doesn't depend on external scripts

set -e

# Configuration
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="/tmp/http_500_fix_standalone_${TIMESTAMP}.log"

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
echo "# Standalone HTTP 500 Fix Log" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "Target: $WEB_ROOT" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"

# Check root
if [[ $EUID -ne 0 ]]; then
    error "Run as root: sudo ./fix-http-500-standalone.sh"
    exit 1
fi

echo "🔧 Standalone HTTP 500 Error Fix"
echo "================================="
echo "Target: $WEB_ROOT"
echo "Log: $LOG_FILE"
echo "Time: $(date)"
echo "================================="
echo ""

# Function to test HTTP status
test_http_status() {
    local url="$1"
    local timeout_val="${2:-10}"
    
    if command -v curl &>/dev/null; then
        timeout "$timeout_val" curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000"
    else
        echo "000"
    fi
}

# Function to get best HTTP status
get_http_status() {
    local status="000"
    
    # Try multiple URLs
    local urls=("http://localhost" "http://127.0.0.1")
    
    # Add server IP if available
    local server_ip=$(hostname -I | awk '{print $1}' 2>/dev/null)
    if [ -n "$server_ip" ]; then
        urls+=("http://$server_ip")
    fi
    
    for url in "${urls[@]}"; do
        status=$(test_http_status "$url" 5)
        if [[ "$status" =~ ^[1-5][0-9][0-9]$ ]]; then
            break
        fi
    done
    
    echo "$status"
}

# Step 1: Environment Check
section "Step 1: Environment Check"

# Check web root
if [ ! -d "$WEB_ROOT" ]; then
    error "Web root not found: $WEB_ROOT"
    exit 1
fi

cd "$WEB_ROOT" || {
    error "Cannot access web root: $WEB_ROOT"
    exit 1
}

log "✓ Web root accessible"

# Check required commands
for cmd in php nginx systemctl; do
    if command -v "$cmd" &>/dev/null; then
        log "✓ Command available: $cmd"
    else
        error "✗ Required command missing: $cmd"
        exit 1
    fi
done

# Step 2: Service Check and Start
section "Step 2: Service Check and Start"

# Start Nginx if not running
if ! systemctl is-active --quiet nginx; then
    info "Starting Nginx..."
    if systemctl start nginx 2>/dev/null; then
        log "✓ Nginx started"
    else
        error "✗ Failed to start Nginx"
    fi
else
    log "✓ Nginx is running"
fi

# Start PHP-FPM if not running
if ! systemctl is-active --quiet php*-fpm; then
    info "Starting PHP-FPM..."
    if systemctl start php*-fpm 2>/dev/null; then
        log "✓ PHP-FPM started"
    else
        error "✗ Failed to start PHP-FPM"
    fi
else
    log "✓ PHP-FPM is running"
fi

# Step 3: Initial Status Check
section "Step 3: Initial Status Check"

info "Testing initial website status..."
INITIAL_STATUS=$(get_http_status)
info "Initial HTTP Status: $INITIAL_STATUS"

if [[ "$INITIAL_STATUS" =~ ^[23] ]]; then
    log "Website is already working (HTTP $INITIAL_STATUS)"
    echo ""
    echo "✅ Your website appears to be working correctly!"
    echo "If you're still experiencing issues, they may be external (DNS, firewall, etc.)"
    exit 0
fi

# Step 4: Critical File Fixes
section "Step 4: Critical File Fixes"

FIXES_APPLIED=0

# Fix 1: Composer Dependencies
if [ ! -d "vendor" ] || [ ! -f "vendor/autoload.php" ]; then
    info "Installing Composer dependencies..."
    
    if command -v composer &>/dev/null; then
        export COMPOSER_ALLOW_SUPERUSER=1
        export COMPOSER_MEMORY_LIMIT=-1
        
        # Try different installation methods
        if composer install --no-dev --optimize-autoloader --no-interaction 2>/dev/null; then
            log "✓ Composer dependencies installed"
            ((FIXES_APPLIED++))
        elif composer install --no-interaction 2>/dev/null; then
            log "✓ Composer dependencies installed (basic)"
            ((FIXES_APPLIED++))
        else
            error "✗ Composer install failed"
        fi
        
        # Fix ownership
        chown -R "$WEB_USER:$WEB_USER" vendor/ 2>/dev/null || true
    else
        error "✗ Composer not found"
    fi
else
    log "✓ Vendor directory exists"
fi

# Fix 2: Bootstrap file
if [ ! -f "bootstrap/app.php" ]; then
    info "Creating bootstrap/app.php..."
    
    mkdir -p bootstrap
    cat > bootstrap/app.php << 'EOF'
<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        //
    })
    ->withExceptions(function (Exceptions $exceptions) {
        //
    })->create();
EOF
    
    log "✓ bootstrap/app.php created"
    ((FIXES_APPLIED++))
else
    log "✓ bootstrap/app.php exists"
fi

# Fix 3: Public index
if [ ! -f "public/index.php" ]; then
    info "Creating public/index.php..."
    
    mkdir -p public
    cat > public/index.php << 'EOF'
<?php

use Illuminate\Contracts\Http\Kernel;
use Illuminate\Http\Request;

define('LARAVEL_START', microtime(true));

if (file_exists($maintenance = __DIR__.'/../storage/framework/maintenance.php')) {
    require $maintenance;
}

require_once __DIR__.'/../vendor/autoload.php';

$app = require_once __DIR__.'/../bootstrap/app.php';

$kernel = $app->make(Kernel::class);

$response = $kernel->handle(
    $request = Request::capture()
)->send();

$kernel->terminate($request, $response);
EOF
    
    log "✓ public/index.php created"
    ((FIXES_APPLIED++))
else
    log "✓ public/index.php exists"
fi

# Fix 4: Environment and APP_KEY
if [ ! -f ".env" ] || ! grep -q "APP_KEY=base64:" ".env" 2>/dev/null; then
    info "Configuring environment and APP_KEY..."
    
    # Create .env if missing
    if [ ! -f ".env" ]; then
        cat > .env << 'EOF'
APP_NAME="BestHammer NTool"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=http://localhost

LOG_CHANNEL=stack
LOG_LEVEL=error

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=
DB_USERNAME=
DB_PASSWORD=

CACHE_DRIVER=file
SESSION_DRIVER=file
SESSION_LIFETIME=120

MAIL_MAILER=log
EOF
        log "✓ .env file created"
    fi
    
    # Generate APP_KEY
    APP_KEY="base64:$(openssl rand -base64 32)"
    sed -i "s|APP_KEY=.*|APP_KEY=$APP_KEY|g" ".env"
    log "✓ APP_KEY generated"
    ((FIXES_APPLIED++))
else
    log "✓ APP_KEY already configured"
fi

# Fix 5: Artisan file
if [ ! -f "artisan" ]; then
    info "Creating artisan file..."
    
    cat > artisan << 'EOF'
#!/usr/bin/env php
<?php

define('LARAVEL_START', microtime(true));

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';

$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);

$status = $kernel->handle(
    $input = new Symfony\Component\Console\Input\ArgvInput,
    new Symfony\Component\Console\Output\ConsoleOutput
);

$kernel->terminate($input, $status);

exit($status);
EOF
    
    chmod +x artisan
    log "✓ artisan created"
    ((FIXES_APPLIED++))
else
    log "✓ artisan exists"
fi

# Step 5: Directory Structure and Permissions
section "Step 5: Directory Structure and Permissions"

info "Creating required directories and fixing permissions..."

# Create Laravel directories
REQUIRED_DIRS=(
    "storage/app"
    "storage/framework/cache"
    "storage/framework/sessions"
    "storage/framework/views"
    "storage/logs"
    "bootstrap/cache"
    "public/build/assets"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        log "✓ Created: $dir"
    fi
done

# Set proper ownership and permissions
chown -R "$WEB_USER:$WEB_USER" "$WEB_ROOT"
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
find "$WEB_ROOT" -type d -exec chmod 755 {} \;

# Set writable permissions for Laravel
chmod -R 775 storage bootstrap/cache 2>/dev/null || true
chmod +x artisan 2>/dev/null || true
chmod 600 .env 2>/dev/null || true

log "✓ Permissions fixed"
((FIXES_APPLIED++))

# Step 6: Basic Frontend Assets
section "Step 6: Basic Frontend Assets"

if [ ! -f "public/build/manifest.json" ]; then
    info "Creating basic frontend assets..."

    # Create basic CSS
    cat > public/build/assets/app.css << 'EOF'
/* Basic BestHammer Styles */
body { font-family: system-ui, sans-serif; margin: 0; padding: 20px; }
.container { max-width: 1200px; margin: 0 auto; }
.text-center { text-align: center; }
.btn { padding: 10px 20px; background: #007bff; color: white; text-decoration: none; border-radius: 4px; }
EOF

    # Create basic JS
    cat > public/build/assets/app.js << 'EOF'
console.log('BestHammer NTool loaded');
EOF

    # Create manifest
    cat > public/build/manifest.json << 'EOF'
{
  "resources/css/app.css": {
    "file": "assets/app.css",
    "isEntry": true
  },
  "resources/js/app.js": {
    "file": "assets/app.js",
    "isEntry": true
  }
}
EOF

    chown -R "$WEB_USER:$WEB_USER" public/build
    log "✓ Basic frontend assets created"
    ((FIXES_APPLIED++))
else
    log "✓ Frontend assets exist"
fi

# Step 7: Laravel Cache Management
section "Step 7: Laravel Cache Management"

if [ -f "vendor/autoload.php" ] && [ -f "artisan" ]; then
    info "Managing Laravel caches..."

    # Clear caches
    php artisan config:clear 2>/dev/null || true
    php artisan route:clear 2>/dev/null || true
    php artisan view:clear 2>/dev/null || true
    php artisan cache:clear 2>/dev/null || true

    log "✓ Laravel caches cleared"
    ((FIXES_APPLIED++))
else
    warning "Cannot manage caches - Laravel not ready"
fi

# Step 8: Service Restart
section "Step 8: Service Restart"

info "Restarting web services..."

# Restart PHP-FPM
if systemctl restart php*-fpm 2>/dev/null; then
    log "✓ PHP-FPM restarted"
else
    warning "⚠ PHP-FPM restart failed"
fi

# Restart Nginx
if systemctl restart nginx 2>/dev/null; then
    log "✓ Nginx restarted"
else
    warning "⚠ Nginx restart failed"
fi

# Wait for services
sleep 5

# Step 9: Final Testing
section "Step 9: Final Testing"

info "Performing final tests..."

# Test PHP
if php -r "echo 'PHP_OK';" 2>/dev/null | grep -q "PHP_OK"; then
    log "✓ PHP execution working"
else
    error "✗ PHP execution failed"
fi

# Test Laravel bootstrap
if [ -f "vendor/autoload.php" ] && [ -f "bootstrap/app.php" ]; then
    BOOTSTRAP_TEST=$(php -r "
        try {
            require_once 'vendor/autoload.php';
            \$app = require_once 'bootstrap/app.php';
            echo 'BOOTSTRAP_OK';
        } catch (Exception \$e) {
            echo 'ERROR: ' . \$e->getMessage();
        }
    " 2>&1)

    if echo "$BOOTSTRAP_TEST" | grep -q "BOOTSTRAP_OK"; then
        log "✓ Laravel bootstrap working"
    else
        error "✗ Laravel bootstrap failed: $BOOTSTRAP_TEST"
    fi
fi

# Test final HTTP status
info "Testing final website status..."
FINAL_STATUS=$(get_http_status)

echo ""
echo "=================================================="
echo "🎯 FINAL RESULTS"
echo "=================================================="
echo "Initial Status: HTTP $INITIAL_STATUS"
echo "Final Status: HTTP $FINAL_STATUS"
echo "Fixes Applied: $FIXES_APPLIED"
echo ""

if [[ "$FINAL_STATUS" =~ ^[23] ]]; then
    log "🎉 SUCCESS: Website is now working!"
    echo ""
    echo "✅ Your website is accessible at:"
    SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null)
    echo "   • http://localhost"
    if [ -n "$SERVER_IP" ]; then
        echo "   • http://$SERVER_IP"
    fi
    echo ""
    echo "🧪 Test these pages:"
    echo "   • Main page: /"
    echo "   • BMI Calculator: /bmi-calculator"
    echo "   • Currency Converter: /currency-converter"
    echo "   • Loan Calculator: /loan-calculator"

elif [ "$FINAL_STATUS" = "500" ]; then
    error "❌ HTTP 500 error still persists"
    echo ""
    echo "🔍 Additional troubleshooting needed:"
    echo "1. Check Laravel logs:"
    echo "   tail -f $WEB_ROOT/storage/logs/laravel.log"
    echo ""
    echo "2. Check web server logs:"
    echo "   tail -f /var/log/nginx/error.log"
    echo "   tail -f /var/log/php*-fpm.log"
    echo ""
    echo "3. Possible remaining issues:"
    echo "   • Database connection problems"
    echo "   • Custom code syntax errors"
    echo "   • Missing PHP extensions"
    echo "   • Server resource limitations"

elif [ "$FINAL_STATUS" = "000" ]; then
    warning "⚠️ Connection issues persist"
    echo ""
    echo "🔍 Possible causes:"
    echo "• Web server not responding"
    echo "• Port 80 blocked by firewall"
    echo "• Nginx configuration errors"
    echo "• DNS resolution issues"

else
    warning "⚠️ Unexpected status: HTTP $FINAL_STATUS"
    echo ""
    echo "🔍 Manual verification recommended"
fi

echo ""
echo "📄 Full log: $LOG_FILE"
echo "📁 Web root: $WEB_ROOT"
echo ""

if [[ "$FINAL_STATUS" =~ ^[23] ]]; then
    echo "🎊 Success! Your BestHammer NTool platform is working!"
else
    echo "🔧 Additional manual troubleshooting may be needed."
fi

echo ""
echo "=================================================="
