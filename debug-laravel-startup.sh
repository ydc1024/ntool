#!/bin/bash

# Laravel Startup Debug Script
# This script diagnoses why Laravel artisan is not working

set -e

# Configuration
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️ $1${NC}"; }

echo "🔍 Laravel Startup Debug Analysis"
echo "================================="
echo "Web Root: $WEB_ROOT"
echo "Web User: $WEB_USER"
echo "Debug Time: $(date)"
echo "================================="
echo

cd "$WEB_ROOT"

# Step 1: Test PHP syntax of critical files
log "Step 1: Testing PHP syntax of critical files"

CRITICAL_FILES=(
    "bootstrap/app.php"
    "app/Http/Kernel.php"
    "config/app.php"
    "config/database.php"
    "artisan"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        if php -l "$file" &>/dev/null; then
            log "✓ $file syntax OK"
        else
            error "✗ $file has syntax errors:"
            php -l "$file"
        fi
    else
        error "✗ $file missing"
    fi
done

# Step 2: Test artisan file specifically
log "Step 2: Testing artisan file execution"

echo "Artisan file content (first 20 lines):"
head -20 artisan | sed 's/^/  /'
echo

echo "Testing artisan execution with detailed error output:"
echo "Command: sudo -u $WEB_USER php artisan --version"
echo "Output:"
sudo -u $WEB_USER php artisan --version 2>&1 | sed 's/^/  /' || true
echo

# Step 3: Test bootstrap/app.php loading
log "Step 3: Testing bootstrap/app.php loading"

echo "Testing bootstrap/app.php loading:"
cat > /tmp/test_bootstrap.php << 'EOF'
<?php
try {
    echo "Loading bootstrap/app.php...\n";
    $app = require_once __DIR__ . '/bootstrap/app.php';
    echo "Bootstrap loaded successfully!\n";
    echo "App class: " . get_class($app) . "\n";
} catch (Exception $e) {
    echo "Error loading bootstrap: " . $e->getMessage() . "\n";
    echo "File: " . $e->getFile() . "\n";
    echo "Line: " . $e->getLine() . "\n";
} catch (Error $e) {
    echo "Fatal error loading bootstrap: " . $e->getMessage() . "\n";
    echo "File: " . $e->getFile() . "\n";
    echo "Line: " . $e->getLine() . "\n";
}
EOF

sudo -u $WEB_USER php /tmp/test_bootstrap.php 2>&1 | sed 's/^/  /'
rm -f /tmp/test_bootstrap.php

# Step 4: Check vendor/autoload.php
log "Step 4: Checking Composer autoload"

if [ -f "vendor/autoload.php" ]; then
    log "✓ vendor/autoload.php exists"
    
    echo "Testing autoload loading:"
    cat > /tmp/test_autoload.php << 'EOF'
<?php
try {
    echo "Loading vendor/autoload.php...\n";
    require_once __DIR__ . '/vendor/autoload.php';
    echo "Autoload loaded successfully!\n";
    
    // Test if Laravel classes are available
    if (class_exists('Illuminate\Foundation\Application')) {
        echo "Laravel Application class found!\n";
    } else {
        echo "Laravel Application class NOT found!\n";
    }
    
} catch (Exception $e) {
    echo "Error loading autoload: " . $e->getMessage() . "\n";
} catch (Error $e) {
    echo "Fatal error loading autoload: " . $e->getMessage() . "\n";
}
EOF

    sudo -u $WEB_USER php /tmp/test_autoload.php 2>&1 | sed 's/^/  /'
    rm -f /tmp/test_autoload.php
else
    error "✗ vendor/autoload.php missing"
fi

# Step 5: Check Laravel version in composer.json vs vendor
log "Step 5: Checking Laravel version compatibility"

if [ -f "composer.json" ]; then
    COMPOSER_LARAVEL=$(grep -o '"laravel/framework": "[^"]*"' composer.json | cut -d'"' -f4)
    info "Laravel version in composer.json: $COMPOSER_LARAVEL"
fi

if [ -f "vendor/laravel/framework/composer.json" ]; then
    INSTALLED_LARAVEL=$(grep -o '"version": "[^"]*"' vendor/laravel/framework/composer.json | head -1 | cut -d'"' -f4)
    info "Installed Laravel version: $INSTALLED_LARAVEL"
else
    error "Laravel framework not found in vendor directory"
fi

# Step 6: Check PHP version compatibility
log "Step 6: Checking PHP version compatibility"

PHP_VERSION=$(php -r "echo PHP_VERSION;")
info "PHP version: $PHP_VERSION"

# Check if PHP version is compatible with Laravel 10+
if php -r "exit(version_compare(PHP_VERSION, '8.1.0', '>=') ? 0 : 1);"; then
    log "✓ PHP version is compatible with Laravel 10+"
else
    error "✗ PHP version is too old for Laravel 10+ (requires PHP 8.1+)"
fi

# Step 7: Test minimal Laravel application creation
log "Step 7: Testing minimal Laravel application creation"

cat > /tmp/test_laravel_app.php << 'EOF'
<?php
try {
    echo "Testing minimal Laravel app creation...\n";
    
    // Load autoload
    require_once __DIR__ . '/vendor/autoload.php';
    
    // Try to create Laravel application
    $app = new Illuminate\Foundation\Application(
        $_ENV['APP_BASE_PATH'] ?? dirname(__DIR__)
    );
    
    echo "Laravel Application created successfully!\n";
    echo "App version: " . $app->version() . "\n";
    
} catch (Exception $e) {
    echo "Error creating Laravel app: " . $e->getMessage() . "\n";
    echo "File: " . $e->getFile() . "\n";
    echo "Line: " . $e->getLine() . "\n";
    echo "Trace:\n" . $e->getTraceAsString() . "\n";
} catch (Error $e) {
    echo "Fatal error creating Laravel app: " . $e->getMessage() . "\n";
    echo "File: " . $e->getFile() . "\n";
    echo "Line: " . $e->getLine() . "\n";
    echo "Trace:\n" . $e->getTraceAsString() . "\n";
}
EOF

sudo -u $WEB_USER php /tmp/test_laravel_app.php 2>&1 | sed 's/^/  /'
rm -f /tmp/test_laravel_app.php

# Step 8: Check .env file loading
log "Step 8: Testing .env file loading"

if [ -f ".env" ]; then
    log "✓ .env file exists"
    
    echo "Testing .env loading:"
    cat > /tmp/test_env.php << 'EOF'
<?php
try {
    echo "Testing .env file loading...\n";
    
    require_once __DIR__ . '/vendor/autoload.php';
    
    // Try to load .env
    $dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
    $dotenv->load();
    
    echo ".env loaded successfully!\n";
    echo "APP_NAME: " . ($_ENV['APP_NAME'] ?? 'not set') . "\n";
    echo "APP_KEY: " . (isset($_ENV['APP_KEY']) ? 'set' : 'not set') . "\n";
    
} catch (Exception $e) {
    echo "Error loading .env: " . $e->getMessage() . "\n";
} catch (Error $e) {
    echo "Fatal error loading .env: " . $e->getMessage() . "\n";
}
EOF

    sudo -u $WEB_USER php /tmp/test_env.php 2>&1 | sed 's/^/  /'
    rm -f /tmp/test_env.php
else
    error "✗ .env file missing"
fi

# Step 9: Check for missing dependencies
log "Step 9: Checking for missing dependencies"

echo "Checking critical Composer packages:"
REQUIRED_PACKAGES=(
    "illuminate/foundation"
    "illuminate/console"
    "illuminate/container"
    "symfony/console"
    "vlucas/phpdotenv"
)

for package in "${REQUIRED_PACKAGES[@]}"; do
    PACKAGE_PATH="vendor/${package}"
    if [ -d "$PACKAGE_PATH" ]; then
        log "✓ $package found"
    else
        error "✗ $package missing"
    fi
done

# Step 10: Generate fix recommendations
log "Step 10: Generating fix recommendations"

echo
echo "🎯 DIAGNOSIS SUMMARY"
echo "==================="

# Check if this is a Laravel 11 vs 10 compatibility issue
if [ -f "bootstrap/app.php" ]; then
    if grep -q "Application::configure" bootstrap/app.php; then
        warning "Laravel 11 style bootstrap detected, but may need Laravel 10 compatibility"
        echo
        echo "🔧 RECOMMENDED FIXES:"
        echo "1. Update to Laravel 10 compatible bootstrap/app.php"
        echo "2. Ensure all dependencies are compatible"
        echo "3. Run composer install with proper constraints"
    fi
fi

echo
echo "📋 Next steps:"
echo "1. Check the detailed error output above"
echo "2. Run the recommended fixes"
echo "3. Test artisan command again"
echo
echo "================================="
echo "Debug analysis completed"
echo "================================="
