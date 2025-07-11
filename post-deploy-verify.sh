#!/bin/bash

# Post-deployment Verification Script for NTool Platform
# This script verifies that the deployment was successful

set -e

# Configuration
DOMAIN="besthammer.club"
WEB_ROOT="/var/www/html"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

fail() {
    echo -e "${RED}✗ $1${NC}"
}

check_web_server() {
    log "Checking web server status..."
    
    if systemctl is-active --quiet nginx; then
        success "Nginx is running"
    else
        fail "Nginx is not running"
        return 1
    fi
    
    if systemctl is-active --quiet php8.1-fpm || systemctl is-active --quiet php-fpm; then
        success "PHP-FPM is running"
    else
        fail "PHP-FPM is not running"
        return 1
    fi
}

check_website_accessibility() {
    log "Checking website accessibility..."
    
    # Check HTTP
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN" 2>/dev/null || echo "000")
    if [[ "$http_code" =~ ^[23] ]]; then
        success "HTTP access working (code: $http_code)"
    else
        fail "HTTP access failed (code: $http_code)"
    fi
    
    # Check HTTPS
    local https_code=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" 2>/dev/null || echo "000")
    if [[ "$https_code" =~ ^[23] ]]; then
        success "HTTPS access working (code: $https_code)"
    else
        warning "HTTPS access failed (code: $https_code)"
    fi
    
    # Check localhost
    local local_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost" 2>/dev/null || echo "000")
    if [[ "$local_code" =~ ^[23] ]]; then
        success "Localhost access working (code: $local_code)"
    else
        fail "Localhost access failed (code: $local_code)"
        return 1
    fi
}

check_laravel_application() {
    log "Checking Laravel application..."
    
    cd "$WEB_ROOT" || return 1
    
    # Check if artisan exists
    if [ -f "artisan" ]; then
        success "Laravel artisan found"
    else
        fail "Laravel artisan not found"
        return 1
    fi
    
    # Check application status
    if sudo -u www-data php artisan --version &>/dev/null; then
        local version=$(sudo -u www-data php artisan --version)
        success "Laravel application is working: $version"
    else
        fail "Laravel application is not working"
        return 1
    fi
    
    # Check environment
    if [ -f ".env" ]; then
        success ".env file exists"
        
        local app_env=$(grep "APP_ENV=" .env | cut -d'=' -f2)
        local app_debug=$(grep "APP_DEBUG=" .env | cut -d'=' -f2)
        
        info "Environment: $app_env"
        info "Debug mode: $app_debug"
        
        if [ "$app_env" = "production" ]; then
            success "Production environment configured"
        else
            warning "Not in production environment"
        fi
        
        if [ "$app_debug" = "false" ]; then
            success "Debug mode disabled"
        else
            warning "Debug mode is enabled"
        fi
    else
        fail ".env file not found"
        return 1
    fi
}

check_database_connection() {
    log "Checking database connection..."
    
    cd "$WEB_ROOT" || return 1
    
    if sudo -u www-data php artisan migrate:status &>/dev/null; then
        success "Database connection working"
        
        local migration_count=$(sudo -u www-data php artisan migrate:status | grep -c "Ran" || echo "0")
        info "Migrations run: $migration_count"
        
        if [ "$migration_count" -gt 0 ]; then
            success "Database migrations completed"
        else
            warning "No migrations found"
        fi
    else
        fail "Database connection failed"
        return 1
    fi
}

check_file_permissions() {
    log "Checking file permissions..."
    
    cd "$WEB_ROOT" || return 1
    
    # Check ownership
    local owner=$(stat -c '%U:%G' .)
    if [ "$owner" = "www-data:www-data" ]; then
        success "Correct ownership: $owner"
    else
        warning "Ownership may be incorrect: $owner"
    fi
    
    # Check storage permissions
    if [ -d "storage" ]; then
        if [ -w "storage" ]; then
            success "Storage directory is writable"
        else
            fail "Storage directory is not writable"
            return 1
        fi
    fi
    
    # Check bootstrap/cache permissions
    if [ -d "bootstrap/cache" ]; then
        if [ -w "bootstrap/cache" ]; then
            success "Bootstrap cache directory is writable"
        else
            fail "Bootstrap cache directory is not writable"
            return 1
        fi
    fi
}

check_caching() {
    log "Checking Laravel caching..."
    
    cd "$WEB_ROOT" || return 1
    
    # Check if caches are optimized
    if [ -f "bootstrap/cache/config.php" ]; then
        success "Configuration cache exists"
    else
        warning "Configuration not cached"
    fi
    
    if [ -f "bootstrap/cache/routes-v7.php" ]; then
        success "Route cache exists"
    else
        warning "Routes not cached"
    fi
    
    if [ -f "bootstrap/cache/packages.php" ]; then
        success "Package cache exists"
    else
        info "Package cache not found (normal for some setups)"
    fi
}

check_storage_link() {
    log "Checking storage link..."
    
    cd "$WEB_ROOT" || return 1
    
    if [ -L "public/storage" ]; then
        success "Storage link exists"
        
        local link_target=$(readlink "public/storage")
        info "Storage link points to: $link_target"
    else
        warning "Storage link not found"
        info "Run: php artisan storage:link"
    fi
}

check_composer_dependencies() {
    log "Checking Composer dependencies..."
    
    cd "$WEB_ROOT" || return 1
    
    if [ -d "vendor" ]; then
        success "Vendor directory exists"
        
        if [ -f "vendor/autoload.php" ]; then
            success "Composer autoloader exists"
        else
            fail "Composer autoloader not found"
            return 1
        fi
        
        # Check if dependencies are optimized
        if [ -f "vendor/composer/autoload_classmap.php" ]; then
            success "Composer autoloader is optimized"
        else
            warning "Composer autoloader not optimized"
        fi
    else
        fail "Vendor directory not found"
        return 1
    fi
}

check_npm_assets() {
    log "Checking NPM assets..."
    
    cd "$WEB_ROOT" || return 1
    
    if [ -f "package.json" ]; then
        success "package.json found"
        
        if [ -d "public/build" ] || [ -d "public/js" ] || [ -d "public/css" ]; then
            success "Built assets found"
        else
            warning "Built assets not found"
        fi
    else
        info "package.json not found (may not be needed)"
    fi
}

check_logs() {
    log "Checking application logs..."
    
    cd "$WEB_ROOT" || return 1
    
    if [ -d "storage/logs" ]; then
        success "Log directory exists"
        
        local error_count=$(find storage/logs -name "*.log" -exec grep -l "ERROR\|CRITICAL\|EMERGENCY" {} \; 2>/dev/null | wc -l)
        
        if [ "$error_count" -eq 0 ]; then
            success "No critical errors in logs"
        else
            warning "$error_count log files contain errors"
            info "Check logs with: tail -f storage/logs/laravel.log"
        fi
    else
        warning "Log directory not found"
    fi
}

check_cron_jobs() {
    log "Checking cron jobs..."
    
    if sudo -u www-data crontab -l 2>/dev/null | grep -q "artisan schedule:run"; then
        success "Laravel scheduler cron job is configured"
    else
        warning "Laravel scheduler cron job not found"
        info "Add to crontab: * * * * * cd $WEB_ROOT && php artisan schedule:run >> /dev/null 2>&1"
    fi
}

check_ssl_certificate() {
    log "Checking SSL certificate..."
    
    local cert_info=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "")
    
    if [ -n "$cert_info" ]; then
        success "SSL certificate is accessible"
        
        local expiry_date=$(echo "$cert_info" | grep "notAfter" | cut -d'=' -f2)
        local expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
        local current_timestamp=$(date +%s)
        local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
        
        if [ $days_until_expiry -gt 30 ]; then
            success "SSL certificate valid for $days_until_expiry days"
        else
            warning "SSL certificate expires in $days_until_expiry days"
        fi
    else
        warning "SSL certificate not accessible"
    fi
}

check_security_headers() {
    log "Checking security headers..."
    
    local headers=$(curl -s -I "https://$DOMAIN" 2>/dev/null || curl -s -I "http://$DOMAIN" 2>/dev/null || echo "")
    
    if echo "$headers" | grep -qi "x-frame-options"; then
        success "X-Frame-Options header present"
    else
        warning "X-Frame-Options header missing"
    fi
    
    if echo "$headers" | grep -qi "x-content-type-options"; then
        success "X-Content-Type-Options header present"
    else
        warning "X-Content-Type-Options header missing"
    fi
    
    if echo "$headers" | grep -qi "x-xss-protection"; then
        success "X-XSS-Protection header present"
    else
        warning "X-XSS-Protection header missing"
    fi
}

generate_report() {
    log "Generating verification report..."
    
    echo
    echo "=================================="
    echo "DEPLOYMENT VERIFICATION REPORT"
    echo "=================================="
    echo "Domain: $DOMAIN"
    echo "Timestamp: $(date)"
    echo "Status: $overall_status"
    echo
    
    if [ $overall_status -eq 0 ]; then
        echo -e "${GREEN}🎉 DEPLOYMENT VERIFICATION PASSED${NC}"
        echo
        echo "Your NTool Platform is successfully deployed and running!"
        echo
        echo "Next steps:"
        echo "1. Test all calculator functions"
        echo "2. Verify user registration and login"
        echo "3. Check subscription features"
        echo "4. Monitor logs for any issues"
        echo "5. Set up monitoring and backups"
    else
        echo -e "${RED}❌ DEPLOYMENT VERIFICATION FAILED${NC}"
        echo
        echo "Some issues were detected. Please review the output above."
        echo "Consider running the rollback script if critical issues exist."
    fi
    echo
}

main() {
    log "Starting post-deployment verification for NTool Platform..."
    echo
    
    overall_status=0
    
    # Run all checks
    check_web_server || overall_status=1
    check_website_accessibility || overall_status=1
    check_laravel_application || overall_status=1
    check_database_connection || overall_status=1
    check_file_permissions || overall_status=1
    check_caching
    check_storage_link
    check_composer_dependencies || overall_status=1
    check_npm_assets
    check_logs
    check_cron_jobs
    check_ssl_certificate
    check_security_headers
    
    generate_report
    
    exit $overall_status
}

main "$@"
