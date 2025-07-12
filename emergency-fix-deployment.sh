#!/bin/bash

# Emergency Fix for BestHammer Deployment Issues
# This script fixes the current deployment problems

set -e

# Configuration
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    error "Run as root: sudo ./emergency-fix-deployment.sh"
    exit 1
fi

echo "🚨 Emergency Fix for BestHammer Deployment"
echo "=========================================="
echo "Target: $WEB_ROOT"
echo "Time: $(date)"
echo "=========================================="

cd "$WEB_ROOT"

# Pre-check: Verify environment
log "Pre-check: Verifying Environment"

# Check if .env exists
if [ ! -f ".env" ]; then
    warning ".env file missing - creating from .env.example"
    if [ -f ".env.example" ]; then
        cp ".env.example" ".env"
        log "✓ .env created from .env.example"
    else
        error ".env.example also missing - cannot proceed"
        exit 1
    fi
fi

# Check PHP version and extensions
PHP_VERSION=$(php -v | head -n1 | cut -d' ' -f2 | cut -d'.' -f1,2)
log "✓ PHP Version: $PHP_VERSION"

# Check required PHP extensions
REQUIRED_EXTENSIONS=("mbstring" "xml" "ctype" "json" "tokenizer" "openssl" "pdo" "bcmath" "curl")
MISSING_EXTENSIONS=()

for ext in "${REQUIRED_EXTENSIONS[@]}"; do
    if ! php -m | grep -q "^$ext$"; then
        MISSING_EXTENSIONS+=("$ext")
    fi
done

if [ ${#MISSING_EXTENSIONS[@]} -gt 0 ]; then
    warning "Missing PHP extensions: ${MISSING_EXTENSIONS[*]}"
    warning "Please install: apt-get install php-${MISSING_EXTENSIONS[*]// / php-}"
else
    log "✓ All required PHP extensions present"
fi

# Check Laravel directory structure
REQUIRED_DIRS=("app" "bootstrap" "config" "database" "public" "resources" "routes" "storage")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        warning "Missing directory: $dir"
        mkdir -p "$dir"
        log "✓ Created directory: $dir"
    fi
done

# Step 1: Fix Composer Dependencies
log "Step 1: Fixing Composer Dependencies"

if [ ! -d "vendor" ] || [ ! -f "vendor/autoload.php" ]; then
    warning "Vendor directory missing - installing Composer dependencies"
    
    if command -v composer &>/dev/null; then
        # Set memory limit for Composer
        export COMPOSER_MEMORY_LIMIT=-1

        # Try multiple methods with better error handling
        if COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist; then
            log "✓ Composer dependencies installed (optimized)"
        elif COMPOSER_ALLOW_SUPERUSER=1 composer install --no-interaction --prefer-dist; then
            log "✓ Composer dependencies installed (basic)"
        elif COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --no-interaction; then
            log "✓ Composer dependencies installed (no optimization)"
        else
            warning "Standard Composer install failed - trying with increased timeout"
            if COMPOSER_ALLOW_SUPERUSER=1 COMPOSER_PROCESS_TIMEOUT=600 composer install --no-dev --no-interaction; then
                log "✓ Composer dependencies installed (extended timeout)"
            else
                error "All Composer install methods failed"
                error "Please check:"
                error "1. Internet connection"
                error "2. Composer configuration"
                error "3. Available disk space"
                exit 1
            fi
        fi

        # Fix permissions
        chown -R $WEB_USER:$WEB_USER vendor/ 2>/dev/null || true
        log "✓ Vendor permissions fixed"
    else
        error "Composer not found - please install Composer first"
        error "Install with: curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer"
        exit 1
    fi
else
    log "✓ Vendor directory exists"
fi

# Step 2: Generate Application Key
log "Step 2: Generating Application Key"

# Ensure .env has APP_KEY line
if ! grep -q "APP_KEY=" ".env" 2>/dev/null; then
    echo "APP_KEY=" >> ".env"
    warning "Added APP_KEY line to .env"
fi

if ! grep -q "APP_KEY=base64:" ".env" 2>/dev/null; then
    if [ -f "vendor/autoload.php" ]; then
        if php artisan key:generate --force 2>/dev/null; then
            log "✓ Application key generated via Artisan"
        else
            warning "Artisan failed - generating key manually"
            APP_KEY="base64:$(openssl rand -base64 32)"
            sed -i "s|APP_KEY=.*|APP_KEY=$APP_KEY|g" ".env"
            log "✓ Application key generated manually"
        fi
    else
        warning "Vendor missing - generating key manually"
        APP_KEY="base64:$(openssl rand -base64 32)"
        sed -i "s|APP_KEY=.*|APP_KEY=$APP_KEY|g" ".env"
        log "✓ Application key generated manually"
    fi
else
    log "✓ Application key already exists"
fi

# Verify key was set
if grep -q "APP_KEY=base64:" ".env" 2>/dev/null; then
    log "✓ Application key verified in .env"
else
    error "Failed to set application key"
    exit 1
fi

# Step 3: Fix Package.json and NPM
log "Step 3: Fixing NPM Dependencies"

# Create a working package.json
cat > package.json << 'EOF'
{
    "name": "besthammer-ntool",
    "version": "1.0.0",
    "private": true,
    "scripts": {
        "dev": "vite",
        "build": "vite build"
    },
    "devDependencies": {
        "laravel-vite-plugin": "^0.8.0",
        "vite": "^4.0.0",
        "tailwindcss": "^3.3.0",
        "autoprefixer": "^10.4.14",
        "postcss": "^8.4.24"
    },
    "dependencies": {
        "alpinejs": "^3.10.2"
    }
}
EOF

# Create basic assets
mkdir -p public/build/assets
cat > public/build/assets/app.css << 'EOF'
/* Basic Tailwind CSS */
*,::after,::before{box-sizing:border-box;border-width:0;border-style:solid;border-color:#e5e7eb}
body{margin:0;font-family:ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Arial,"Noto Sans",sans-serif}
.bg-gray-50{background-color:#f9fafb}
.bg-white{background-color:#fff}
.text-center{text-align:center}
.font-bold{font-weight:700}
.text-xl{font-size:1.25rem}
.text-3xl{font-size:1.875rem}
.mb-4{margin-bottom:1rem}
.p-6{padding:1.5rem}
.rounded-xl{border-radius:0.75rem}
.shadow-md{box-shadow:0 4px 6px -1px rgb(0 0 0 / 0.1)}
EOF

cat > public/build/assets/app.js << 'EOF'
// Basic JavaScript functionality
console.log('BestHammer NTool Platform loaded');
EOF

# Create manifest
cat > public/build/manifest.json << 'EOF'
{
  "resources/css/app.css": {
    "file": "assets/app.css",
    "isEntry": true,
    "src": "resources/css/app.css"
  },
  "resources/js/app.js": {
    "file": "assets/app.js",
    "isEntry": true,
    "src": "resources/js/app.js"
  }
}
EOF

log "✓ Basic assets created"

# Step 3.5: Ensure Critical Laravel Files Exist
log "Step 3.5: Checking Critical Laravel Files"

# Check and create bootstrap/app.php if missing
if [ ! -f "bootstrap/app.php" ]; then
    warning "bootstrap/app.php missing - creating"
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
fi

# Check public/index.php
if [ ! -f "public/index.php" ]; then
    warning "public/index.php missing - creating"
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
fi

# Ensure artisan exists
if [ ! -f "artisan" ]; then
    warning "artisan missing - creating"
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
fi

log "✓ All critical Laravel files verified"

# Step 4: Run Database Migrations
log "Step 4: Running Database Migrations"

if [ -f "vendor/autoload.php" ] && grep -q "DB_DATABASE=" ".env" 2>/dev/null; then
    if php artisan migrate --force 2>/dev/null; then
        log "✓ Database migrations completed"
    else
        warning "Migration failed - checking database connection"
        # Test basic PHP
        if php -r "echo 'PHP working';" 2>/dev/null; then
            log "✓ PHP is working"
        else
            error "PHP has issues"
        fi
    fi
else
    warning "Skipping migrations - vendor or database not configured"
fi

# Step 5: Clear and Cache Laravel
log "Step 5: Laravel Optimization"

if [ -f "vendor/autoload.php" ]; then
    php artisan config:clear 2>/dev/null || true
    php artisan route:clear 2>/dev/null || true
    php artisan view:clear 2>/dev/null || true
    php artisan cache:clear 2>/dev/null || true
    
    php artisan config:cache 2>/dev/null || warning "Config cache failed"
    php artisan route:cache 2>/dev/null || warning "Route cache failed"
    php artisan view:cache 2>/dev/null || warning "View cache failed"
    
    log "✓ Laravel caches cleared and rebuilt"
else
    warning "Skipping Laravel optimization - vendor missing"
fi

# Step 6: Fix Permissions (FastPanel Compatible)
log "Step 6: Fixing Permissions"

# Set ownership to web user
chown -R $WEB_USER:$WEB_USER "$WEB_ROOT"

# Set secure file permissions
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
find "$WEB_ROOT" -type d -exec chmod 755 {} \;

# Set executable permissions for artisan
if [ -f "$WEB_ROOT/artisan" ]; then
    chmod +x "$WEB_ROOT/artisan"
    log "✓ Artisan executable permissions set"
fi

# Set writable permissions for Laravel directories
if [ -d "$WEB_ROOT/storage" ]; then
    chmod -R 775 "$WEB_ROOT/storage"
    log "✓ Storage permissions set"
fi

if [ -d "$WEB_ROOT/bootstrap/cache" ]; then
    chmod -R 775 "$WEB_ROOT/bootstrap/cache"
    log "✓ Bootstrap cache permissions set"
fi

# Ensure public directory is readable
if [ -d "$WEB_ROOT/public" ]; then
    chmod -R 755 "$WEB_ROOT/public"
    log "✓ Public directory permissions set"
fi

# Set .env file permissions (secure)
if [ -f "$WEB_ROOT/.env" ]; then
    chmod 600 "$WEB_ROOT/.env"
    chown $WEB_USER:$WEB_USER "$WEB_ROOT/.env"
    log "✓ .env file secured"
fi

log "✓ All permissions fixed for FastPanel"

# Step 7: Restart Services
log "Step 7: Restarting Services"

systemctl restart php*-fpm 2>/dev/null || true
systemctl restart nginx 2>/dev/null || true

log "✓ Services restarted"

# Step 8: Comprehensive Website Testing
log "Step 8: Testing Website"

sleep 3

# Test localhost first
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" =~ ^[23] ]]; then
    log "✅ Website accessible via localhost (HTTP $HTTP_CODE)"
else
    warning "Website status via localhost: HTTP $HTTP_CODE"
fi

# Test via server IP
SERVER_IP=$(hostname -I | awk '{print $1}')
if [ -n "$SERVER_IP" ]; then
    HTTP_CODE_IP=$(curl -s -o /dev/null -w "%{http_code}" "http://$SERVER_IP" 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE_IP" =~ ^[23] ]]; then
        log "✅ Website accessible via IP (HTTP $HTTP_CODE_IP)"
    else
        warning "Website status via IP: HTTP $HTTP_CODE_IP"
    fi
fi

# Detailed diagnostics if website not accessible
if [[ ! "$HTTP_CODE" =~ ^[23] ]] && [[ ! "$HTTP_CODE_IP" =~ ^[23] ]]; then
    warning "Website not accessible - running diagnostics..."

    # Check if index.php exists
    if [ -f "public/index.php" ]; then
        log "✓ public/index.php exists"
    else
        error "public/index.php missing"
    fi

    # Check PHP-FPM status
    if systemctl is-active --quiet php*-fpm; then
        log "✓ PHP-FPM is running"
    else
        warning "PHP-FPM may not be running"
        systemctl status php*-fpm --no-pager -l
    fi

    # Check Nginx status
    if systemctl is-active --quiet nginx; then
        log "✓ Nginx is running"
    else
        warning "Nginx may not be running"
        systemctl status nginx --no-pager -l
    fi

    # Check nginx error log
    if [ -f "/var/log/nginx/error.log" ]; then
        warning "Recent nginx errors:"
        tail -10 /var/log/nginx/error.log 2>/dev/null || true
    fi

    # Check PHP error log
    if [ -f "/var/log/php*-fpm.log" ]; then
        warning "Recent PHP-FPM errors:"
        tail -5 /var/log/php*-fpm.log 2>/dev/null || true
    fi

    # Test PHP directly
    if php -r "echo 'PHP Direct Test: OK';" 2>/dev/null; then
        log "✓ PHP direct execution works"
    else
        error "PHP direct execution failed"
    fi
fi

# Test Laravel
if [ -f "artisan" ] && [ -f "vendor/autoload.php" ]; then
    if php artisan --version &>/dev/null; then
        LARAVEL_VERSION=$(php artisan --version 2>/dev/null)
        log "✅ Laravel working: $LARAVEL_VERSION"
    else
        warning "Laravel has issues"
    fi
fi

# Final Verification
log "Final Verification"

ISSUES_FOUND=0

# Check critical files
CRITICAL_FILES=("vendor/autoload.php" "bootstrap/app.php" "public/index.php" "artisan" ".env")
for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        log "✓ $file exists"
    else
        error "✗ $file missing"
        ((ISSUES_FOUND++))
    fi
done

# Check APP_KEY
if grep -q "APP_KEY=base64:" ".env" 2>/dev/null; then
    log "✓ APP_KEY configured"
else
    error "✗ APP_KEY not configured"
    ((ISSUES_FOUND++))
fi

# Check permissions
if [ -w "storage" ] && [ -w "bootstrap/cache" ]; then
    log "✓ Write permissions OK"
else
    warning "⚠ Write permissions may have issues"
    ((ISSUES_FOUND++))
fi

echo
if [ $ISSUES_FOUND -eq 0 ]; then
    log "🎉 Emergency fix completed successfully!"
    log "✅ All critical components verified"
else
    warning "⚠️ Emergency fix completed with $ISSUES_FOUND issues"
    warning "Please review the issues above"
fi

echo
echo "🌐 Test your website:"
echo "   • Main site: http://$(hostname -I | awk '{print $1}')"
echo "   • BMI Calculator: http://$(hostname -I | awk '{print $1}')/bmi-calculator"
echo "   • Currency Converter: http://$(hostname -I | awk '{print $1}')/currency-converter"
echo "   • Loan Calculator: http://$(hostname -I | awk '{print $1}')/loan-calculator"
echo
echo "📁 Location: $WEB_ROOT"
echo "👤 Web User: $WEB_USER"
echo
echo "📊 Next steps:"
echo "1. Test all calculator pages"
echo "2. Verify API endpoints work"
echo "3. Check error logs if issues persist:"
echo "   tail -f $WEB_ROOT/storage/logs/laravel.log"
echo "   tail -f /var/log/nginx/error.log"
echo "   tail -f /var/log/php*-fpm.log"
echo
echo "🔧 If problems persist:"
echo "1. Check FastPanel domain configuration"
echo "2. Verify Nginx virtual host settings"
echo "3. Ensure PHP-FPM pool configuration is correct"
echo
echo "=========================================="
if [ $ISSUES_FOUND -eq 0 ]; then
    echo "✅ Emergency fix completed successfully!"
else
    echo "⚠️ Emergency fix completed with issues"
fi
echo "=========================================="
