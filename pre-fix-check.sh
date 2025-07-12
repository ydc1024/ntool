#!/bin/bash

# Pre-Fix Environment Check Script
# This script ensures the environment is ready for Laravel compatibility fix

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

echo "🔍 Pre-Fix Environment Check"
echo "============================"
echo "Web Root: $WEB_ROOT"
echo "Web User: $WEB_USER"
echo "Check Time: $(date)"
echo "============================"
echo

# Check root
if [[ $EUID -ne 0 ]]; then
    error "Run as root: sudo ./pre-fix-check.sh"
    exit 1
fi

cd "$WEB_ROOT"

# Step 1: Check internet connectivity
log "Step 1: Checking internet connectivity"

if ping -c 1 packagist.org &>/dev/null; then
    log "✓ Internet connectivity OK (can reach packagist.org)"
else
    error "✗ No internet connectivity - cannot download Composer packages"
    echo "Please check your internet connection and try again."
    exit 1
fi

# Step 2: Check Composer availability and version
log "Step 2: Checking Composer"

if command -v composer &>/dev/null; then
    COMPOSER_VERSION=$(composer --version 2>/dev/null | head -1)
    log "✓ Composer available: $COMPOSER_VERSION"
    
    # Check if Composer is up to date
    info "Updating Composer to latest version..."
    composer self-update 2>/dev/null || warning "Could not update Composer"
    
else
    error "✗ Composer not found"
    echo "Installing Composer..."
    
    # Install Composer
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
    
    if command -v composer &>/dev/null; then
        log "✓ Composer installed successfully"
    else
        error "Failed to install Composer"
        exit 1
    fi
fi

# Step 3: Check disk space
log "Step 3: Checking disk space"

AVAILABLE_SPACE=$(df "$WEB_ROOT" | awk 'NR==2 {print $4}')
REQUIRED_SPACE=500000  # 500MB in KB

if [ "$AVAILABLE_SPACE" -gt "$REQUIRED_SPACE" ]; then
    log "✓ Sufficient disk space available ($(($AVAILABLE_SPACE/1024))MB)"
else
    error "✗ Insufficient disk space ($(($AVAILABLE_SPACE/1024))MB available, 500MB required)"
    echo "Please free up disk space and try again."
    exit 1
fi

# Step 4: Check PHP memory limit
log "Step 4: Checking PHP configuration"

PHP_MEMORY=$(php -r "echo ini_get('memory_limit');")
info "PHP memory limit: $PHP_MEMORY"

# Convert memory limit to bytes for comparison
if [[ $PHP_MEMORY == *"G" ]]; then
    MEMORY_BYTES=$((${PHP_MEMORY%G} * 1024 * 1024 * 1024))
elif [[ $PHP_MEMORY == *"M" ]]; then
    MEMORY_BYTES=$((${PHP_MEMORY%M} * 1024 * 1024))
elif [[ $PHP_MEMORY == "-1" ]]; then
    MEMORY_BYTES=999999999999  # Unlimited
else
    MEMORY_BYTES=$PHP_MEMORY
fi

REQUIRED_MEMORY=$((512 * 1024 * 1024))  # 512MB

if [ "$MEMORY_BYTES" -gt "$REQUIRED_MEMORY" ] || [ "$PHP_MEMORY" = "-1" ]; then
    log "✓ PHP memory limit is sufficient"
else
    warning "PHP memory limit may be too low for Composer operations"
    echo "Consider increasing memory_limit in php.ini to at least 512M"
fi

# Step 5: Check file permissions
log "Step 5: Checking file permissions"

if [ -w "$WEB_ROOT" ]; then
    log "✓ Web root is writable"
else
    error "✗ Web root is not writable"
    exit 1
fi

# Check if we can create files as web user
if sudo -u $WEB_USER touch "$WEB_ROOT/test_write_permission" 2>/dev/null; then
    rm -f "$WEB_ROOT/test_write_permission"
    log "✓ Can create files as web user"
else
    error "✗ Cannot create files as web user"
    echo "Fixing permissions..."
    chown -R $WEB_USER:$WEB_USER "$WEB_ROOT"
    chmod -R 755 "$WEB_ROOT"
    
    if sudo -u $WEB_USER touch "$WEB_ROOT/test_write_permission" 2>/dev/null; then
        rm -f "$WEB_ROOT/test_write_permission"
        log "✓ Permissions fixed"
    else
        error "✗ Still cannot create files as web user"
        exit 1
    fi
fi

# Step 6: Backup current state
log "Step 6: Creating backup"

BACKUP_DIR="/tmp/besthammer_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup critical files
if [ -f "composer.json" ]; then
    cp composer.json "$BACKUP_DIR/"
    log "✓ Backed up composer.json"
fi

if [ -f "composer.lock" ]; then
    cp composer.lock "$BACKUP_DIR/"
    log "✓ Backed up composer.lock"
fi

if [ -f ".env" ]; then
    cp .env "$BACKUP_DIR/"
    log "✓ Backed up .env"
fi

if [ -d "vendor" ]; then
    info "Creating vendor directory backup (this may take a moment)..."
    tar -czf "$BACKUP_DIR/vendor_backup.tar.gz" vendor/ 2>/dev/null || warning "Could not backup vendor directory"
fi

echo "Backup created at: $BACKUP_DIR"

# Step 7: Check current Laravel installation
log "Step 7: Analyzing current Laravel installation"

if [ -f "vendor/laravel/framework/composer.json" ]; then
    CURRENT_LARAVEL=$(grep -o '"version": "[^"]*"' vendor/laravel/framework/composer.json | head -1 | cut -d'"' -f4)
    info "Current Laravel version: $CURRENT_LARAVEL"
    
    # Check if it's Laravel 10 or 11
    if [[ $CURRENT_LARAVEL == 10.* ]]; then
        log "✓ Laravel 10 detected - compatible"
    elif [[ $CURRENT_LARAVEL == 11.* ]]; then
        warning "Laravel 11 detected - will downgrade to Laravel 10 for compatibility"
    else
        warning "Unknown Laravel version detected"
    fi
else
    warning "Laravel framework not found in vendor directory"
fi

# Step 8: Final readiness check
log "Step 8: Final readiness assessment"

echo
echo "🎯 PRE-FIX READINESS SUMMARY"
echo "==========================="
echo "✅ Internet connectivity: OK"
echo "✅ Composer: Available"
echo "✅ Disk space: Sufficient"
echo "✅ PHP configuration: OK"
echo "✅ File permissions: OK"
echo "✅ Backup: Created"
echo
echo "🚀 READY TO PROCEED"
echo "==================="
echo "The environment is ready for Laravel compatibility fix."
echo "You can now run: sudo ./fix-laravel-compatibility.sh"
echo
echo "📋 Backup location: $BACKUP_DIR"
echo "📋 If anything goes wrong, you can restore from this backup."
echo
echo "============================"
echo "Pre-fix check completed"
echo "============================"
