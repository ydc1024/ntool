#!/bin/bash

# BestHammer NTool Platform - Complete Website Diagnostic Script
# This script diagnoses 500 errors and all website issues

set -e

# Configuration
DOMAIN="besthammer.club"
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

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

echo "🔍 BestHammer NTool Platform - Complete Website Diagnostic"
echo "========================================================"
echo "Domain: $DOMAIN"
echo "Web Root: $WEB_ROOT"
echo "Web User: $WEB_USER"
echo "Diagnostic Time: $(date)"
echo "========================================================"
echo

# Step 1: Basic Environment Check
log "Step 1: Basic Environment Check"

echo "📋 System Information:"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Uptime: $(uptime -p)"
echo

# Check if web root exists
if [ ! -d "$WEB_ROOT" ]; then
    error "Web root directory does not exist: $WEB_ROOT"
    exit 1
else
    log "✓ Web root directory exists"
fi

# Check web user
if id "$WEB_USER" &>/dev/null; then
    log "✓ Web user exists: $WEB_USER"
else
    error "Web user does not exist: $WEB_USER"
fi

# Step 2: Web Server Analysis
log "Step 2: Web Server Analysis"

echo "🌐 Web Server Status:"

# Check Nginx
if systemctl is-active --quiet nginx; then
    log "✓ Nginx is running"
    NGINX_VERSION=$(nginx -v 2>&1 | cut -d'/' -f2)
    info "Nginx version: $NGINX_VERSION"
else
    error "Nginx is not running"
    systemctl status nginx --no-pager -l
fi

# Check Apache (if exists)
if command -v apache2 &>/dev/null; then
    if systemctl is-active --quiet apache2; then
        log "✓ Apache is running"
        APACHE_VERSION=$(apache2 -v | head -1 | cut -d'/' -f2 | cut -d' ' -f1)
        info "Apache version: $APACHE_VERSION"
    else
        warning "Apache is installed but not running"
    fi
fi

# Check PHP-FPM
PHP_FPM_STATUS="Unknown"
for php_version in 8.3 8.2 8.1 8.0 7.4; do
    if systemctl is-active --quiet "php${php_version}-fpm"; then
        log "✓ PHP-FPM ${php_version} is running"
        PHP_FPM_STATUS="Running (${php_version})"
        PHP_VERSION=$php_version
        break
    fi
done

if [ "$PHP_FPM_STATUS" = "Unknown" ]; then
    error "No PHP-FPM service is running"
fi

# Step 3: PHP Environment Analysis
log "Step 3: PHP Environment Analysis"

echo "🐘 PHP Configuration:"

# Check PHP CLI version
if command -v php &>/dev/null; then
    PHP_CLI_VERSION=$(php -v | head -1 | cut -d' ' -f2 | cut -d'-' -f1)
    log "✓ PHP CLI version: $PHP_CLI_VERSION"
    
    # Check PHP modules
    echo "PHP Extensions:"
    REQUIRED_EXTENSIONS=("mbstring" "xml" "curl" "zip" "gd" "mysql" "pdo" "pdo_mysql" "json" "tokenizer" "openssl")
    
    for ext in "${REQUIRED_EXTENSIONS[@]}"; do
        if php -m | grep -q "^$ext$"; then
            info "  ✓ $ext"
        else
            error "  ✗ $ext (missing)"
        fi
    done
    
    # Check PHP configuration
    echo
    echo "PHP Configuration:"
    info "Memory limit: $(php -r "echo ini_get('memory_limit');")"
    info "Max execution time: $(php -r "echo ini_get('max_execution_time');")"
    info "Upload max filesize: $(php -r "echo ini_get('upload_max_filesize');")"
    info "Post max size: $(php -r "echo ini_get('post_max_size');")"
    
else
    error "PHP CLI is not available"
fi

# Step 4: Laravel Application Analysis
log "Step 4: Laravel Application Analysis"

cd "$WEB_ROOT" || exit 1

echo "🔨 Laravel Application Status:"

# Check Laravel files
LARAVEL_FILES=("artisan" "composer.json" ".env" "app/Http/Kernel.php" "config/app.php")
for file in "${LARAVEL_FILES[@]}"; do
    if [ -f "$file" ]; then
        log "✓ $file exists"
    else
        error "✗ $file missing"
    fi
done

# Check Laravel directories
LARAVEL_DIRS=("app" "config" "database" "public" "resources" "routes" "storage" "vendor")
for dir in "${LARAVEL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        log "✓ $dir directory exists"
    else
        error "✗ $dir directory missing"
    fi
done

# Check if vendor directory has content
if [ -d "vendor" ] && [ "$(ls -A vendor)" ]; then
    log "✓ Vendor directory has content"
else
    error "✗ Vendor directory is empty - Composer dependencies not installed"
fi

# Check Laravel version
if [ -f "artisan" ]; then
    if sudo -u $WEB_USER php artisan --version &>/dev/null; then
        LARAVEL_VERSION=$(sudo -u $WEB_USER php artisan --version 2>/dev/null)
        log "✓ Laravel is working: $LARAVEL_VERSION"
    else
        error "✗ Laravel artisan command failed"
        echo "Artisan error output:"
        sudo -u $WEB_USER php artisan --version 2>&1 | head -10
    fi
fi

# Step 5: File Permissions Analysis
log "Step 5: File Permissions Analysis"

echo "🔐 File Permissions Check:"

# Check ownership
OWNER=$(stat -c '%U:%G' "$WEB_ROOT")
if [ "$OWNER" = "$WEB_USER:$WEB_USER" ]; then
    log "✓ Web root ownership is correct: $OWNER"
else
    error "✗ Web root ownership is incorrect: $OWNER (should be $WEB_USER:$WEB_USER)"
fi

# Check critical directory permissions
CRITICAL_DIRS=("storage" "bootstrap/cache" "public")
for dir in "${CRITICAL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        PERMS=$(stat -c '%a' "$dir")
        if [ "$PERMS" -ge 775 ]; then
            log "✓ $dir permissions: $PERMS"
        else
            error "✗ $dir permissions: $PERMS (should be 775 or higher)"
        fi
    fi
done

# Check storage subdirectories
if [ -d "storage" ]; then
    STORAGE_DIRS=("logs" "framework/cache" "framework/sessions" "framework/views" "app")
    for dir in "${STORAGE_DIRS[@]}"; do
        if [ -d "storage/$dir" ]; then
            PERMS=$(stat -c '%a' "storage/$dir")
            if [ "$PERMS" -ge 775 ]; then
                log "✓ storage/$dir permissions: $PERMS"
            else
                error "✗ storage/$dir permissions: $PERMS (should be 775 or higher)"
            fi
        else
            error "✗ storage/$dir directory missing"
        fi
    done
fi

# Step 6: Environment Configuration Analysis
log "Step 6: Environment Configuration Analysis"

echo "⚙️ Environment Configuration:"

if [ -f ".env" ]; then
    log "✓ .env file exists"
    
    # Check critical .env variables
    ENV_VARS=("APP_NAME" "APP_ENV" "APP_KEY" "APP_DEBUG" "APP_URL" "DB_CONNECTION" "DB_HOST" "DB_DATABASE" "DB_USERNAME")
    
    for var in "${ENV_VARS[@]}"; do
        if grep -q "^$var=" ".env"; then
            VALUE=$(grep "^$var=" ".env" | cut -d'=' -f2- | tr -d '"')
            if [ -n "$VALUE" ]; then
                if [ "$var" = "APP_KEY" ]; then
                    if [[ $VALUE == base64:* ]]; then
                        log "✓ $var is set (base64 encoded)"
                    else
                        error "✗ $var is not base64 encoded"
                    fi
                elif [ "$var" = "DB_PASSWORD" ]; then
                    log "✓ $var is set (hidden)"
                else
                    log "✓ $var = $VALUE"
                fi
            else
                error "✗ $var is empty"
            fi
        else
            error "✗ $var is not set"
        fi
    done
    
else
    error "✗ .env file missing"
fi

# Step 7: Database Connection Analysis
log "Step 7: Database Connection Analysis"

echo "🗄️ Database Connection:"

if [ -f ".env" ]; then
    DB_HOST=$(grep "^DB_HOST=" ".env" | cut -d'=' -f2 | tr -d '"')
    DB_DATABASE=$(grep "^DB_DATABASE=" ".env" | cut -d'=' -f2 | tr -d '"')
    DB_USERNAME=$(grep "^DB_USERNAME=" ".env" | cut -d'=' -f2 | tr -d '"')
    DB_PASSWORD=$(grep "^DB_PASSWORD=" ".env" | cut -d'=' -f2 | tr -d '"')
    
    if [ -n "$DB_HOST" ] && [ -n "$DB_DATABASE" ] && [ -n "$DB_USERNAME" ]; then
        # Test database connection
        if command -v mysql &>/dev/null; then
            if mysql -h"$DB_HOST" -u"$DB_USERNAME" -p"$DB_PASSWORD" -e "USE $DB_DATABASE;" 2>/dev/null; then
                log "✓ Database connection successful"
                
                # Check if database has tables
                TABLE_COUNT=$(mysql -h"$DB_HOST" -u"$DB_USERNAME" -p"$DB_PASSWORD" -D"$DB_DATABASE" -e "SHOW TABLES;" 2>/dev/null | wc -l)
                if [ "$TABLE_COUNT" -gt 1 ]; then
                    log "✓ Database has $((TABLE_COUNT-1)) tables"
                else
                    warning "Database is empty - migrations may need to be run"
                fi
            else
                error "✗ Database connection failed"
            fi
        else
            warning "MySQL client not available for testing"
        fi
    else
        error "✗ Database configuration incomplete"
    fi
fi

info "✓ Environment analysis completed"

# Step 8: Laravel Configuration Analysis
log "Step 8: Laravel Configuration Analysis"

echo "🔧 Laravel Configuration:"

# Test Laravel configuration
if [ -f "artisan" ]; then
    # Check if Laravel can load
    if sudo -u $WEB_USER php artisan config:show app.name &>/dev/null; then
        log "✓ Laravel configuration loads successfully"

        APP_NAME=$(sudo -u $WEB_USER php artisan config:show app.name 2>/dev/null | grep -o '".*"' | tr -d '"')
        APP_ENV=$(sudo -u $WEB_USER php artisan config:show app.env 2>/dev/null | grep -o '".*"' | tr -d '"')
        APP_DEBUG=$(sudo -u $WEB_USER php artisan config:show app.debug 2>/dev/null)

        info "App Name: $APP_NAME"
        info "App Environment: $APP_ENV"
        info "Debug Mode: $APP_DEBUG"

    else
        error "✗ Laravel configuration failed to load"
        echo "Configuration error output:"
        sudo -u $WEB_USER php artisan config:show app.name 2>&1 | head -10
    fi

    # Check routes
    if sudo -u $WEB_USER php artisan route:list &>/dev/null; then
        log "✓ Routes load successfully"
        ROUTE_COUNT=$(sudo -u $WEB_USER php artisan route:list --json 2>/dev/null | jq length 2>/dev/null || echo "Unknown")
        info "Total routes: $ROUTE_COUNT"
    else
        error "✗ Routes failed to load"
        echo "Route error output:"
        sudo -u $WEB_USER php artisan route:list 2>&1 | head -10
    fi
fi

# Step 9: Web Server Configuration Analysis
log "Step 9: Web Server Configuration Analysis"

echo "🌐 Web Server Configuration:"

# Check Nginx configuration
if command -v nginx &>/dev/null; then
    # Test Nginx configuration
    if nginx -t &>/dev/null; then
        log "✓ Nginx configuration is valid"
    else
        error "✗ Nginx configuration has errors"
        nginx -t 2>&1
    fi

    # Check if site configuration exists
    NGINX_SITES_DIR="/etc/nginx/sites-available"
    if [ -d "$NGINX_SITES_DIR" ]; then
        if ls "$NGINX_SITES_DIR"/*"$DOMAIN"* &>/dev/null || ls "$NGINX_SITES_DIR"/default &>/dev/null; then
            log "✓ Nginx site configuration found"

            # Check for common configuration issues
            SITE_CONFIG=$(find "$NGINX_SITES_DIR" -name "*$DOMAIN*" -o -name "default" | head -1)
            if [ -f "$SITE_CONFIG" ]; then
                info "Site config: $SITE_CONFIG"

                # Check document root
                if grep -q "root.*$WEB_ROOT" "$SITE_CONFIG"; then
                    log "✓ Document root correctly set to $WEB_ROOT"
                else
                    error "✗ Document root may be incorrect"
                    grep "root" "$SITE_CONFIG" | head -3
                fi

                # Check PHP handling
                if grep -q "\.php" "$SITE_CONFIG"; then
                    log "✓ PHP handling configured"
                else
                    error "✗ PHP handling not configured"
                fi

                # Check Laravel rewrite rules
                if grep -q "try_files.*index\.php" "$SITE_CONFIG"; then
                    log "✓ Laravel rewrite rules found"
                else
                    error "✗ Laravel rewrite rules missing"
                fi
            fi
        else
            error "✗ No Nginx site configuration found for $DOMAIN"
        fi
    fi
fi

# Step 10: SSL/HTTPS Analysis
log "Step 10: SSL/HTTPS Analysis"

echo "🔒 SSL/HTTPS Configuration:"

# Check SSL certificate
if command -v openssl &>/dev/null; then
    # Test HTTPS connection
    if timeout 10 openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" </dev/null &>/dev/null; then
        log "✓ SSL certificate is accessible"

        # Get certificate details
        CERT_INFO=$(timeout 10 openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" </dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
        if [ -n "$CERT_INFO" ]; then
            info "Certificate details:"
            echo "$CERT_INFO" | sed 's/^/  /'
        fi
    else
        error "✗ SSL certificate not accessible"
    fi
else
    warning "OpenSSL not available for SSL testing"
fi

# Check HTTP to HTTPS redirect
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN" 2>/dev/null || echo "000")
if [ "$HTTP_RESPONSE" = "301" ] || [ "$HTTP_RESPONSE" = "302" ]; then
    log "✓ HTTP to HTTPS redirect is working ($HTTP_RESPONSE)"
else
    warning "HTTP to HTTPS redirect may not be configured (HTTP $HTTP_RESPONSE)"
fi

# Step 11: Error Log Analysis
log "Step 11: Error Log Analysis"

echo "📋 Error Log Analysis:"

# Check Laravel logs
if [ -d "storage/logs" ]; then
    LATEST_LOG=$(find storage/logs -name "laravel-*.log" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
    if [ -n "$LATEST_LOG" ] && [ -f "$LATEST_LOG" ]; then
        log "✓ Laravel log file found: $LATEST_LOG"

        # Show recent errors
        echo "Recent Laravel errors (last 20 lines):"
        tail -20 "$LATEST_LOG" | grep -E "(ERROR|CRITICAL|EMERGENCY)" | tail -10 | sed 's/^/  /' || echo "  No recent errors found"

        # Count error types
        ERROR_COUNT=$(grep -c "ERROR" "$LATEST_LOG" 2>/dev/null || echo "0")
        CRITICAL_COUNT=$(grep -c "CRITICAL" "$LATEST_LOG" 2>/dev/null || echo "0")

        info "Error count in latest log: $ERROR_COUNT errors, $CRITICAL_COUNT critical"
    else
        warning "No Laravel log files found"
    fi
else
    error "✗ Laravel logs directory missing"
fi

# Check Nginx error logs
NGINX_ERROR_LOG="/var/log/nginx/error.log"
if [ -f "$NGINX_ERROR_LOG" ]; then
    log "✓ Nginx error log found"

    echo "Recent Nginx errors (last 10 lines):"
    tail -10 "$NGINX_ERROR_LOG" | grep -E "(error|crit|alert|emerg)" | tail -5 | sed 's/^/  /' || echo "  No recent errors found"
else
    warning "Nginx error log not found at $NGINX_ERROR_LOG"
fi

# Check PHP-FPM error logs
if [ -n "$PHP_VERSION" ]; then
    PHP_FPM_LOG="/var/log/php${PHP_VERSION}-fpm.log"
    if [ -f "$PHP_FPM_LOG" ]; then
        log "✓ PHP-FPM error log found"

        echo "Recent PHP-FPM errors (last 10 lines):"
        tail -10 "$PHP_FPM_LOG" | grep -E "(ERROR|WARNING|CRITICAL)" | tail -5 | sed 's/^/  /' || echo "  No recent errors found"
    else
        warning "PHP-FPM error log not found at $PHP_FPM_LOG"
    fi
fi

# Step 12: HTTP Response Testing
log "Step 12: HTTP Response Testing"

echo "🌐 HTTP Response Testing:"

# Test different endpoints
ENDPOINTS=("/" "/bmi-calculator" "/currency-converter" "/loan-calculator" "/health")

for endpoint in "${ENDPOINTS[@]}"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost$endpoint" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
        log "✓ $endpoint responds with HTTP $HTTP_CODE"
    elif [ "$HTTP_CODE" = "500" ]; then
        error "✗ $endpoint responds with HTTP $HTTP_CODE (Internal Server Error)"
    elif [ "$HTTP_CODE" = "404" ]; then
        warning "$endpoint responds with HTTP $HTTP_CODE (Not Found)"
    else
        warning "$endpoint responds with HTTP $HTTP_CODE"
    fi
done

# Test HTTPS if available
if timeout 5 curl -s -k "https://$DOMAIN" &>/dev/null; then
    HTTPS_CODE=$(curl -s -k -o /dev/null -w "%{http_code}" "https://$DOMAIN" 2>/dev/null || echo "000")
    if [ "$HTTPS_CODE" = "200" ]; then
        log "✓ HTTPS responds with HTTP $HTTPS_CODE"
    else
        error "✗ HTTPS responds with HTTP $HTTPS_CODE"
    fi
else
    warning "HTTPS not accessible or timeout"
fi

info "✓ HTTP response testing completed"

# Step 13: FastPanel Specific Analysis
log "Step 13: FastPanel Specific Analysis"

echo "🎛️ FastPanel Configuration:"

# Check FastPanel specific paths and configurations
FASTPANEL_PATHS=("/usr/local/fastpanel" "/etc/fastpanel")
for path in "${FASTPANEL_PATHS[@]}"; do
    if [ -d "$path" ]; then
        log "✓ FastPanel directory found: $path"
    else
        warning "FastPanel directory not found: $path"
    fi
done

# Check if this is a FastPanel managed site
if [[ "$WEB_ROOT" == *"fastpanel"* ]] || [[ "$WEB_ROOT" == *"_usr"* ]]; then
    log "✓ Detected FastPanel managed website"

    # Check FastPanel user structure
    if [[ "$WEB_USER" == *"_usr" ]]; then
        log "✓ FastPanel user naming convention detected"
    fi
else
    warning "May not be a FastPanel managed website"
fi

# Step 14: Composer Dependencies Analysis
log "Step 14: Composer Dependencies Analysis"

echo "📦 Composer Dependencies:"

if [ -f "composer.json" ] && [ -f "composer.lock" ]; then
    log "✓ Composer files exist"

    # Check if vendor directory is properly populated
    if [ -d "vendor/laravel/framework" ]; then
        log "✓ Laravel framework installed in vendor"
    else
        error "✗ Laravel framework missing from vendor directory"
    fi

    # Check for common missing dependencies
    REQUIRED_PACKAGES=("laravel/framework" "guzzlehttp/guzzle" "laravel/sanctum")
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if [ -d "vendor/${package}" ]; then
            log "✓ $package installed"
        else
            error "✗ $package missing"
        fi
    done

    # Check autoload
    if [ -f "vendor/autoload.php" ]; then
        log "✓ Composer autoload file exists"
    else
        error "✗ Composer autoload file missing"
    fi

else
    error "✗ Composer files missing"
fi

# Step 15: Application Structure Validation
log "Step 15: Application Structure Validation"

echo "🏗️ Application Structure:"

# Check critical application files
CRITICAL_FILES=(
    "app/Http/Controllers/BmiController.php"
    "app/Http/Controllers/CurrencyController.php"
    "app/Http/Controllers/LoanController.php"
    "app/Services/BmiCalculatorService.php"
    "app/Services/CurrencyService.php"
    "app/Services/LoanCalculatorService.php"
    "routes/web.php"
    "routes/api.php"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        # Check for PHP syntax errors
        if php -l "$file" &>/dev/null; then
            log "✓ $file (syntax OK)"
        else
            error "✗ $file (syntax error)"
            php -l "$file" 2>&1 | head -3
        fi
    else
        error "✗ $file missing"
    fi
done

# Check view files
VIEW_FILES=(
    "resources/views/welcome.blade.php"
    "resources/views/layouts/app.blade.php"
    "resources/views/calculators/bmi/index.blade.php"
    "resources/views/calculators/currency/index.blade.php"
    "resources/views/calculators/loan/index.blade.php"
)

for file in "${VIEW_FILES[@]}"; do
    if [ -f "$file" ]; then
        log "✓ $file exists"
    else
        error "✗ $file missing"
    fi
done

# Step 16: Generate Diagnostic Report
log "Step 16: Generating Diagnostic Report"

REPORT_FILE="/tmp/besthammer_diagnostic_report_${TIMESTAMP}.txt"

cat > "$REPORT_FILE" << EOF
BestHammer NTool Platform - Diagnostic Report
=============================================
Generated: $(date)
Domain: $DOMAIN
Web Root: $WEB_ROOT
Web User: $WEB_USER

SUMMARY OF ISSUES FOUND:
========================

EOF

# Collect all errors and warnings from the diagnostic
echo "Collecting diagnostic results..."

# Check for critical issues that cause 500 errors
CRITICAL_ISSUES=()

# Check if Laravel can start
if ! sudo -u $WEB_USER php artisan --version &>/dev/null; then
    CRITICAL_ISSUES+=("Laravel artisan command fails - likely PHP syntax error or missing dependencies")
fi

# Check if vendor directory is populated
if [ ! -d "vendor/laravel/framework" ]; then
    CRITICAL_ISSUES+=("Laravel framework missing from vendor directory - run composer install")
fi

# Check if .env file exists and has APP_KEY
if [ ! -f ".env" ]; then
    CRITICAL_ISSUES+=(".env file missing - copy from .env.example and configure")
elif ! grep -q "^APP_KEY=base64:" ".env"; then
    CRITICAL_ISSUES+=("APP_KEY not set in .env - run php artisan key:generate")
fi

# Check storage permissions
if [ -d "storage" ]; then
    STORAGE_PERMS=$(stat -c '%a' "storage")
    if [ "$STORAGE_PERMS" -lt 775 ]; then
        CRITICAL_ISSUES+=("Storage directory permissions insufficient ($STORAGE_PERMS) - should be 775")
    fi
fi

# Add issues to report
if [ ${#CRITICAL_ISSUES[@]} -gt 0 ]; then
    echo "CRITICAL ISSUES (likely causing 500 errors):" >> "$REPORT_FILE"
    for issue in "${CRITICAL_ISSUES[@]}"; do
        echo "❌ $issue" >> "$REPORT_FILE"
    done
    echo >> "$REPORT_FILE"
fi

# Add fix commands
cat >> "$REPORT_FILE" << EOF
RECOMMENDED FIX COMMANDS:
========================

1. Fix file permissions:
   sudo chown -R $WEB_USER:$WEB_USER $WEB_ROOT
   sudo chmod -R 755 $WEB_ROOT
   sudo chmod -R 775 $WEB_ROOT/storage
   sudo chmod -R 775 $WEB_ROOT/bootstrap/cache

2. Install/update Composer dependencies:
   cd $WEB_ROOT
   sudo -u $WEB_USER composer install --no-dev --optimize-autoloader

3. Configure Laravel:
   cd $WEB_ROOT
   sudo -u $WEB_USER cp .env.example .env
   sudo -u $WEB_USER php artisan key:generate
   sudo -u $WEB_USER php artisan config:cache
   sudo -u $WEB_USER php artisan route:cache
   sudo -u $WEB_USER php artisan view:cache

4. Restart services:
   sudo systemctl restart nginx
   sudo systemctl restart php*-fpm

5. Check logs for specific errors:
   tail -f $WEB_ROOT/storage/logs/laravel.log
   tail -f /var/log/nginx/error.log

EOF

log "✓ Diagnostic report generated: $REPORT_FILE"

# Step 17: Final Summary
log "Step 17: Final Diagnostic Summary"

echo
echo "🎯 DIAGNOSTIC SUMMARY"
echo "===================="

if [ ${#CRITICAL_ISSUES[@]} -gt 0 ]; then
    error "Found ${#CRITICAL_ISSUES[@]} critical issues that likely cause 500 errors"
    echo
    echo "Critical Issues:"
    for issue in "${CRITICAL_ISSUES[@]}"; do
        echo "  ❌ $issue"
    done
    echo
    echo "🔧 IMMEDIATE ACTIONS REQUIRED:"
    echo "1. Run the fix commands listed in the diagnostic report"
    echo "2. Check error logs for specific error messages"
    echo "3. Test website after each fix"
    echo
else
    log "No critical issues found - 500 error may be intermittent"
    echo
    echo "🔍 NEXT STEPS:"
    echo "1. Check recent error logs for specific error messages"
    echo "2. Test individual calculator endpoints"
    echo "3. Monitor logs while accessing the website"
    echo
fi

echo "📄 Full diagnostic report: $REPORT_FILE"
echo "📋 To view the report: cat $REPORT_FILE"
echo
echo "🔧 Quick fix command:"
echo "sudo chown -R $WEB_USER:$WEB_USER $WEB_ROOT && sudo chmod -R 775 $WEB_ROOT/storage && sudo -u $WEB_USER composer install --no-dev -d $WEB_ROOT"
echo
echo "========================================================"
echo "Diagnostic completed at $(date)"
echo "========================================================"
