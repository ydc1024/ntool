#!/bin/bash

# Comprehensive BestHammer NTool Platform Deployment Diagnostic
# This script performs a complete analysis of the deployed website
# comparing against the source ntool project structure

set -e

# Configuration
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="/tmp/besthammer_diagnostic_report_${TIMESTAMP}.txt"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() { echo -e "${GREEN}✅ $1${NC}" | tee -a "$REPORT_FILE"; }
warning() { echo -e "${YELLOW}⚠️ $1${NC}" | tee -a "$REPORT_FILE"; }
error() { echo -e "${RED}❌ $1${NC}" | tee -a "$REPORT_FILE"; }
info() { echo -e "${BLUE}ℹ️ $1${NC}" | tee -a "$REPORT_FILE"; }
section() { echo -e "${PURPLE}🔍 $1${NC}" | tee -a "$REPORT_FILE"; }

# Initialize report
echo "# BestHammer NTool Platform Deployment Diagnostic Report" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "Target: $WEB_ROOT" >> "$REPORT_FILE"
echo "=========================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Check root
if [[ $EUID -ne 0 ]]; then
    error "Run as root: sudo ./comprehensive-deployment-diagnostic.sh"
    exit 1
fi

echo "🔍 BestHammer NTool Platform Deployment Diagnostic"
echo "=================================================="
echo "Target: $WEB_ROOT"
echo "Report: $REPORT_FILE"
echo "Time: $(date)"
echo "=================================================="

# Global counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

check_result() {
    ((TOTAL_CHECKS++))
    case $1 in
        "PASS") ((PASSED_CHECKS++)) ;;
        "FAIL") ((FAILED_CHECKS++)) ;;
        "WARN") ((WARNING_CHECKS++)) ;;
    esac
}

cd "$WEB_ROOT" 2>/dev/null || {
    error "Cannot access web root: $WEB_ROOT"
    exit 1
}

# Section 1: Environment & System Check
section "Section 1: Environment & System Analysis"

# PHP Version and Extensions
info "Checking PHP environment..."
PHP_VERSION=$(php -v | head -n1 | cut -d' ' -f2 | cut -d'.' -f1,2)
echo "PHP Version: $PHP_VERSION" >> "$REPORT_FILE"

if [[ $(echo "$PHP_VERSION >= 8.1" | bc -l 2>/dev/null || echo "0") == "1" ]]; then
    log "PHP Version: $PHP_VERSION (Compatible)"
    check_result "PASS"
else
    error "PHP Version: $PHP_VERSION (Requires 8.1+)"
    check_result "FAIL"
fi

# Required PHP Extensions
REQUIRED_EXTENSIONS=(
    "mbstring" "xml" "ctype" "json" "tokenizer" "openssl" 
    "pdo" "pdo_mysql" "bcmath" "curl" "fileinfo" "gd" 
    "intl" "zip" "redis" "imagick"
)

MISSING_EXTENSIONS=()
for ext in "${REQUIRED_EXTENSIONS[@]}"; do
    if php -m | grep -q "^$ext$"; then
        log "PHP Extension: $ext ✓"
        check_result "PASS"
    else
        error "PHP Extension: $ext ✗"
        MISSING_EXTENSIONS+=("$ext")
        check_result "FAIL"
    fi
done

if [ ${#MISSING_EXTENSIONS[@]} -gt 0 ]; then
    error "Missing PHP extensions: ${MISSING_EXTENSIONS[*]}"
    echo "Install with: apt-get install php-${MISSING_EXTENSIONS[*]// / php-}" >> "$REPORT_FILE"
fi

# Web Server Check
info "Checking web server configuration..."
if systemctl is-active --quiet nginx; then
    log "Nginx: Running"
    check_result "PASS"
    
    # Check Nginx configuration
    if nginx -t &>/dev/null; then
        log "Nginx Configuration: Valid"
        check_result "PASS"
    else
        error "Nginx Configuration: Invalid"
        check_result "FAIL"
    fi
else
    error "Nginx: Not running"
    check_result "FAIL"
fi

if systemctl is-active --quiet php*-fpm; then
    log "PHP-FPM: Running"
    check_result "PASS"
else
    error "PHP-FPM: Not running"
    check_result "FAIL"
fi

# Database Check
info "Checking database connectivity..."
if [ -f ".env" ] && grep -q "DB_DATABASE=" ".env"; then
    DB_NAME=$(grep "DB_DATABASE=" ".env" | cut -d'=' -f2)
    DB_USER=$(grep "DB_USERNAME=" ".env" | cut -d'=' -f2)
    
    if [ -f "vendor/autoload.php" ]; then
        if php artisan tinker --execute="DB::connection()->getPdo(); echo 'DB_OK';" 2>/dev/null | grep -q "DB_OK"; then
            log "Database Connection: OK ($DB_NAME)"
            check_result "PASS"
        else
            error "Database Connection: Failed"
            check_result "FAIL"
        fi
    else
        warning "Cannot test database - vendor directory missing"
        check_result "WARN"
    fi
else
    warning "Database not configured in .env"
    check_result "WARN"
fi

# Redis Check
info "Checking Redis connectivity..."
if command -v redis-cli &>/dev/null; then
    if redis-cli ping 2>/dev/null | grep -q "PONG"; then
        log "Redis: Connected"
        check_result "PASS"
    else
        warning "Redis: Not responding"
        check_result "WARN"
    fi
else
    warning "Redis: Not installed"
    check_result "WARN"
fi

# Section 2: Laravel Core Files Check
section "Section 2: Laravel Core Files Analysis"

# Critical Laravel Files
CRITICAL_FILES=(
    "artisan"
    "composer.json"
    "package.json"
    ".env"
    "bootstrap/app.php"
    "public/index.php"
    "vendor/autoload.php"
)

info "Checking critical Laravel files..."
for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        log "Critical File: $file ✓"
        check_result "PASS"
    else
        error "Critical File: $file ✗"
        check_result "FAIL"
    fi
done

# Laravel Configuration Files
CONFIG_FILES=(
    "config/app.php"
    "config/database.php"
    "config/cache.php"
    "config/services.php"
    "config/analytics.php"
    "config/cloudflare.php"
    "config/queue.php"
    "config/subscription.php"
)

info "Checking Laravel configuration files..."
for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        log "Config File: $file ✓"
        check_result "PASS"
    else
        error "Config File: $file ✗"
        check_result "FAIL"
    fi
done

# Laravel Directory Structure
LARAVEL_DIRS=(
    "app/Console/Commands"
    "app/Http/Controllers"
    "app/Http/Controllers/Api"
    "app/Http/Controllers/Admin"
    "app/Http/Middleware"
    "app/Jobs"
    "app/Models"
    "app/Policies"
    "app/Providers"
    "app/Services"
    "bootstrap/cache"
    "database/migrations"
    "database/seeders"
    "public"
    "resources/css"
    "resources/js"
    "resources/views"
    "resources/views/layouts"
    "resources/views/components"
    "routes"
    "storage/app"
    "storage/framework/cache"
    "storage/framework/sessions"
    "storage/framework/views"
    "storage/logs"
    "tests"
)

info "Checking Laravel directory structure..."
for dir in "${LARAVEL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        log "Directory: $dir ✓"
        check_result "PASS"
    else
        error "Directory: $dir ✗"
        check_result "FAIL"
    fi
done

# Section 3: NTool Core Controllers Check
section "Section 3: NTool Core Controllers Analysis"

# Core Controllers
CORE_CONTROLLERS=(
    "app/Http/Controllers/HomeController.php"
    "app/Http/Controllers/BmiController.php"
    "app/Http/Controllers/CurrencyController.php"
    "app/Http/Controllers/LoanController.php"
    "app/Http/Controllers/SubscriptionController.php"
    "app/Http/Controllers/LanguageController.php"
    "app/Http/Controllers/PrivacyController.php"
    "app/Http/Controllers/Api/ApiController.php"
    "app/Http/Controllers/Api/FeedbackController.php"
    "app/Http/Controllers/Admin/AdminController.php"
)

info "Checking core controllers..."
for controller in "${CORE_CONTROLLERS[@]}"; do
    if [ -f "$controller" ]; then
        log "Controller: $(basename $controller) ✓"
        check_result "PASS"

        # Check if controller has basic methods
        if grep -q "class.*Controller" "$controller"; then
            log "  └─ Class structure: Valid"
            check_result "PASS"
        else
            error "  └─ Class structure: Invalid"
            check_result "FAIL"
        fi
    else
        error "Controller: $(basename $controller) ✗"
        check_result "FAIL"
    fi
done

# Section 4: NTool Service Classes Check
section "Section 4: NTool Service Classes Analysis"

# Core Services
CORE_SERVICES=(
    "app/Services/BmiCalculatorService.php"
    "app/Services/CurrencyService.php"
    "app/Services/LoanCalculatorService.php"
    "app/Services/SubscriptionService.php"
    "app/Services/AnalyticsService.php"
    "app/Services/NotificationService.php"
    "app/Services/ExportService.php"
    "app/Services/LocalizationService.php"
    "app/Services/PrivacyComplianceService.php"
    "app/Services/CloudflareService.php"
    "app/Services/PWAService.php"
    "app/Services/ApiOptimizationService.php"
    "app/Services/CacheOptimizationService.php"
    "app/Services/SeoContentService.php"
    "app/Services/FeedbackService.php"
    "app/Services/NutritionService.php"
    "app/Services/LoanComparisonService.php"
    "app/Services/CurrencyComparisonService.php"
)

info "Checking service classes..."
for service in "${CORE_SERVICES[@]}"; do
    if [ -f "$service" ]; then
        log "Service: $(basename $service) ✓"
        check_result "PASS"

        # Check if service has basic structure
        if grep -q "class.*Service" "$service"; then
            log "  └─ Class structure: Valid"
            check_result "PASS"
        else
            error "  └─ Class structure: Invalid"
            check_result "FAIL"
        fi
    else
        error "Service: $(basename $service) ✗"
        check_result "FAIL"
    fi
done

# Section 5: NTool Models Check
section "Section 5: NTool Models Analysis"

# Core Models
CORE_MODELS=(
    "app/Models/User.php"
    "app/Models/BmiRecord.php"
    "app/Models/LoanCalculation.php"
    "app/Models/CurrencyRate.php"
    "app/Models/CurrencyAlert.php"
    "app/Models/SubscriptionPlan.php"
    "app/Models/UserSubscription.php"
    "app/Models/ApiUsageLog.php"
)

info "Checking model classes..."
for model in "${CORE_MODELS[@]}"; do
    if [ -f "$model" ]; then
        log "Model: $(basename $model) ✓"
        check_result "PASS"

        # Check if model extends Model
        if grep -q "extends.*Model" "$model"; then
            log "  └─ Extends Model: Valid"
            check_result "PASS"
        else
            error "  └─ Extends Model: Invalid"
            check_result "FAIL"
        fi
    else
        error "Model: $(basename $model) ✗"
        check_result "FAIL"
    fi
done

# Section 6: NTool Jobs Check
section "Section 6: NTool Background Jobs Analysis"

# Job Classes
JOB_CLASSES=(
    "app/Jobs/UpdateCurrencyRatesJob.php"
    "app/Jobs/CheckCurrencyAlertsJob.php"
    "app/Jobs/SendReminderNotificationsJob.php"
)

info "Checking job classes..."
for job in "${JOB_CLASSES[@]}"; do
    if [ -f "$job" ]; then
        log "Job: $(basename $job) ✓"
        check_result "PASS"

        # Check if job implements ShouldQueue
        if grep -q "ShouldQueue" "$job"; then
            log "  └─ Queue Interface: Valid"
            check_result "PASS"
        else
            warning "  └─ Queue Interface: Missing"
            check_result "WARN"
        fi
    else
        error "Job: $(basename $job) ✗"
        check_result "FAIL"
    fi
done

# Section 7: NTool Views Check
section "Section 7: NTool Views Analysis"

# Core Views
CORE_VIEWS=(
    "resources/views/layouts/app.blade.php"
    "resources/views/home.blade.php"
    "resources/views/bmi/calculator.blade.php"
    "resources/views/currency/converter.blade.php"
    "resources/views/loan/calculator.blade.php"
    "resources/views/loan/comparison.blade.php"
    "resources/views/subscription/plans.blade.php"
    "resources/views/components/enhanced-footer.blade.php"
    "resources/views/setup-required.blade.php"
)

info "Checking view templates..."
for view in "${CORE_VIEWS[@]}"; do
    if [ -f "$view" ]; then
        log "View: $(basename $view) ✓"
        check_result "PASS"

        # Check if view has basic Blade syntax
        if grep -q "@extends\|@section\|@yield" "$view"; then
            log "  └─ Blade syntax: Valid"
            check_result "PASS"
        else
            warning "  └─ Blade syntax: Basic HTML only"
            check_result "WARN"
        fi
    else
        error "View: $(basename $view) ✗"
        check_result "FAIL"
    fi
done

# Section 8: NTool Routes Check
section "Section 8: NTool Routes Analysis"

# Route Files
ROUTE_FILES=(
    "routes/web.php"
    "routes/api.php"
    "routes/auth.php"
)

info "Checking route files..."
for route_file in "${ROUTE_FILES[@]}"; do
    if [ -f "$route_file" ]; then
        log "Route File: $(basename $route_file) ✓"
        check_result "PASS"

        # Check route content
        if [ -s "$route_file" ]; then
            ROUTE_COUNT=$(grep -c "Route::" "$route_file" 2>/dev/null || echo "0")
            if [ "$ROUTE_COUNT" -gt 0 ]; then
                log "  └─ Routes defined: $ROUTE_COUNT"
                check_result "PASS"
            else
                warning "  └─ No routes found"
                check_result "WARN"
            fi
        else
            warning "  └─ File is empty"
            check_result "WARN"
        fi
    else
        error "Route File: $(basename $route_file) ✗"
        check_result "FAIL"
    fi
done

# Section 9: Database Migrations Check
section "Section 9: Database Migrations Analysis"

# Migration Files
MIGRATION_FILES=(
    "database/migrations/2024_01_01_000000_create_users_table.php"
    "database/migrations/2024_01_01_000001_create_loan_calculations_table.php"
    "database/migrations/2024_01_01_000002_create_bmi_records_table.php"
    "database/migrations/2024_01_01_000003_create_currency_rates_table.php"
    "database/migrations/2024_01_01_000004_create_currency_alerts_table.php"
    "database/migrations/2024_01_01_000005_create_api_usage_logs_table.php"
    "database/migrations/2024_01_02_000001_create_subscription_plans_table.php"
    "database/migrations/2024_01_02_000002_create_user_subscriptions_table.php"
    "database/migrations/2024_01_15_000001_create_feedback_table.php"
    "database/migrations/2024_01_15_000002_create_data_requests_table.php"
    "database/migrations/2024_01_15_000003_create_ccpa_opt_outs_table.php"
)

info "Checking database migrations..."
for migration in "${MIGRATION_FILES[@]}"; do
    if [ -f "$migration" ]; then
        log "Migration: $(basename $migration) ✓"
        check_result "PASS"

        # Check migration structure
        if grep -q "Schema::" "$migration"; then
            log "  └─ Schema operations: Valid"
            check_result "PASS"
        else
            error "  └─ Schema operations: Invalid"
            check_result "FAIL"
        fi
    else
        error "Migration: $(basename $migration) ✗"
        check_result "FAIL"
    fi
done

# Check if migrations have been run
if [ -f "vendor/autoload.php" ] && [ -f ".env" ]; then
    info "Checking migration status..."
    if php artisan migrate:status 2>/dev/null | grep -q "Ran"; then
        MIGRATED_COUNT=$(php artisan migrate:status 2>/dev/null | grep -c "Ran" || echo "0")
        log "Migrations run: $MIGRATED_COUNT"
        check_result "PASS"
    else
        warning "No migrations have been run"
        check_result "WARN"
    fi
fi

# Section 10: Frontend Assets Check
section "Section 10: Frontend Assets Analysis"

# Frontend Files
FRONTEND_FILES=(
    "resources/css/app.css"
    "resources/js/app.js"
    "public/build/manifest.json"
    "tailwind.config.js"
    "vite.config.js"
)

info "Checking frontend assets..."
for asset in "${FRONTEND_FILES[@]}"; do
    if [ -f "$asset" ]; then
        log "Frontend Asset: $(basename $asset) ✓"
        check_result "PASS"
    else
        error "Frontend Asset: $(basename $asset) ✗"
        check_result "FAIL"
    fi
done

# Check compiled assets
if [ -d "public/build" ]; then
    ASSET_COUNT=$(find public/build -name "*.css" -o -name "*.js" | wc -l)
    if [ "$ASSET_COUNT" -gt 0 ]; then
        log "Compiled assets: $ASSET_COUNT files"
        check_result "PASS"
    else
        warning "No compiled assets found"
        check_result "WARN"
    fi
else
    error "Build directory missing"
    check_result "FAIL"
fi

# Section 11: File Permissions Check
section "Section 11: File Permissions Analysis"

info "Checking file permissions..."

# Check ownership
OWNER=$(stat -c '%U' . 2>/dev/null || echo "unknown")
if [ "$OWNER" = "$WEB_USER" ]; then
    log "Directory ownership: $OWNER ✓"
    check_result "PASS"
else
    error "Directory ownership: $OWNER (should be $WEB_USER)"
    check_result "FAIL"
fi

# Check writable directories
WRITABLE_DIRS=("storage" "bootstrap/cache")
for dir in "${WRITABLE_DIRS[@]}"; do
    if [ -d "$dir" ] && [ -w "$dir" ]; then
        log "Writable directory: $dir ✓"
        check_result "PASS"
    else
        error "Writable directory: $dir ✗"
        check_result "FAIL"
    fi
done

# Check .env permissions
if [ -f ".env" ]; then
    ENV_PERMS=$(stat -c '%a' .env 2>/dev/null || echo "000")
    if [ "$ENV_PERMS" = "600" ] || [ "$ENV_PERMS" = "644" ]; then
        log ".env permissions: $ENV_PERMS ✓"
        check_result "PASS"
    else
        warning ".env permissions: $ENV_PERMS (should be 600 or 644)"
        check_result "WARN"
    fi
fi

# Section 12: Configuration Analysis
section "Section 12: Configuration Analysis"

info "Checking Laravel configuration..."

# Check APP_KEY
if [ -f ".env" ]; then
    if grep -q "APP_KEY=base64:" ".env"; then
        log "APP_KEY: Configured ✓"
        check_result "PASS"
    else
        error "APP_KEY: Not configured"
        check_result "FAIL"
    fi

    # Check APP_ENV
    APP_ENV=$(grep "APP_ENV=" ".env" | cut -d'=' -f2 || echo "unknown")
    log "APP_ENV: $APP_ENV"
    if [ "$APP_ENV" = "production" ]; then
        check_result "PASS"
    else
        check_result "WARN"
    fi

    # Check APP_DEBUG
    APP_DEBUG=$(grep "APP_DEBUG=" ".env" | cut -d'=' -f2 || echo "unknown")
    log "APP_DEBUG: $APP_DEBUG"
    if [ "$APP_DEBUG" = "false" ]; then
        check_result "PASS"
    else
        check_result "WARN"
    fi
else
    error ".env file missing"
    check_result "FAIL"
fi

# Section 13: Functional Testing
section "Section 13: Functional Testing"

info "Testing website functionality..."

# Test main page
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" =~ ^[23] ]]; then
    log "Main page: HTTP $HTTP_CODE ✓"
    check_result "PASS"
else
    error "Main page: HTTP $HTTP_CODE ✗"
    check_result "FAIL"
fi

# Test calculator pages
CALCULATOR_PAGES=("bmi-calculator" "currency-converter" "loan-calculator")
for page in "${CALCULATOR_PAGES[@]}"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/$page" 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE" =~ ^[23] ]]; then
        log "Calculator page /$page: HTTP $HTTP_CODE ✓"
        check_result "PASS"
    else
        error "Calculator page /$page: HTTP $HTTP_CODE ✗"
        check_result "FAIL"
    fi
done

# Test API endpoints
API_ENDPOINTS=("api/calculate-bmi" "api/convert-currency" "api/calculate-loan")
for endpoint in "${API_ENDPOINTS[@]}"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost/$endpoint" 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE" =~ ^[234] ]]; then
        log "API endpoint /$endpoint: HTTP $HTTP_CODE ✓"
        check_result "PASS"
    else
        error "API endpoint /$endpoint: HTTP $HTTP_CODE ✗"
        check_result "FAIL"
    fi
done

# Section 14: Laravel Artisan Commands Test
section "Section 14: Laravel Artisan Commands Test"

if [ -f "vendor/autoload.php" ] && [ -f "artisan" ]; then
    info "Testing Laravel Artisan commands..."

    # Test artisan
    if php artisan --version &>/dev/null; then
        LARAVEL_VERSION=$(php artisan --version 2>/dev/null)
        log "Laravel Artisan: $LARAVEL_VERSION ✓"
        check_result "PASS"
    else
        error "Laravel Artisan: Failed"
        check_result "FAIL"
    fi

    # Test route list
    if php artisan route:list &>/dev/null; then
        ROUTE_COUNT=$(php artisan route:list --json 2>/dev/null | jq length 2>/dev/null || echo "unknown")
        log "Routes registered: $ROUTE_COUNT"
        check_result "PASS"
    else
        error "Route listing failed"
        check_result "FAIL"
    fi

    # Test config cache
    if php artisan config:cache &>/dev/null; then
        log "Config cache: Working ✓"
        check_result "PASS"
    else
        error "Config cache: Failed"
        check_result "FAIL"
    fi
else
    warning "Cannot test Artisan - vendor or artisan missing"
    check_result "WARN"
fi

# Section 15: Security Analysis
section "Section 15: Security Analysis"

info "Checking security configuration..."

# Check for sensitive files
SENSITIVE_FILES=(".env.example" "composer.lock" "package-lock.json")
for file in "${SENSITIVE_FILES[@]}"; do
    if [ -f "public/$file" ]; then
        error "Security Risk: $file exposed in public directory"
        check_result "FAIL"
    else
        log "Security Check: $file not in public ✓"
        check_result "PASS"
    fi
done

# Check directory listing
if curl -s "http://localhost/storage/" | grep -q "Index of"; then
    error "Security Risk: Directory listing enabled"
    check_result "FAIL"
else
    log "Security Check: Directory listing disabled ✓"
    check_result "PASS"
fi

# Final Report Generation
section "Final Diagnostic Report"

echo "" >> "$REPORT_FILE"
echo "=========================================" >> "$REPORT_FILE"
echo "DIAGNOSTIC SUMMARY" >> "$REPORT_FILE"
echo "=========================================" >> "$REPORT_FILE"
echo "Total Checks: $TOTAL_CHECKS" >> "$REPORT_FILE"
echo "Passed: $PASSED_CHECKS" >> "$REPORT_FILE"
echo "Failed: $FAILED_CHECKS" >> "$REPORT_FILE"
echo "Warnings: $WARNING_CHECKS" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Calculate success rate
if [ $TOTAL_CHECKS -gt 0 ]; then
    SUCCESS_RATE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
else
    SUCCESS_RATE=0
fi

echo "Success Rate: $SUCCESS_RATE%" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Recommendations
echo "RECOMMENDATIONS:" >> "$REPORT_FILE"
echo "=================" >> "$REPORT_FILE"

if [ $FAILED_CHECKS -gt 0 ]; then
    echo "❌ $FAILED_CHECKS critical issues found - immediate attention required" >> "$REPORT_FILE"
fi

if [ $WARNING_CHECKS -gt 0 ]; then
    echo "⚠️ $WARNING_CHECKS warnings found - review recommended" >> "$REPORT_FILE"
fi

if [ $SUCCESS_RATE -ge 90 ]; then
    echo "✅ Deployment is in excellent condition ($SUCCESS_RATE%)" >> "$REPORT_FILE"
elif [ $SUCCESS_RATE -ge 75 ]; then
    echo "✅ Deployment is in good condition ($SUCCESS_RATE%)" >> "$REPORT_FILE"
elif [ $SUCCESS_RATE -ge 50 ]; then
    echo "⚠️ Deployment needs improvement ($SUCCESS_RATE%)" >> "$REPORT_FILE"
else
    echo "❌ Deployment has serious issues ($SUCCESS_RATE%)" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo "Report generated: $(date)" >> "$REPORT_FILE"

# Display final summary
echo ""
echo "=================================================="
echo "🎯 DIAGNOSTIC COMPLETED"
echo "=================================================="
echo "📊 Total Checks: $TOTAL_CHECKS"
echo "✅ Passed: $PASSED_CHECKS"
echo "❌ Failed: $FAILED_CHECKS"
echo "⚠️ Warnings: $WARNING_CHECKS"
echo "📈 Success Rate: $SUCCESS_RATE%"
echo ""
echo "📄 Full Report: $REPORT_FILE"
echo ""

if [ $SUCCESS_RATE -ge 90 ]; then
    log "🎉 Deployment is in excellent condition!"
elif [ $SUCCESS_RATE -ge 75 ]; then
    log "✅ Deployment is in good condition"
elif [ $SUCCESS_RATE -ge 50 ]; then
    warning "⚠️ Deployment needs improvement"
else
    error "❌ Deployment has serious issues"
fi

echo ""
echo "🔧 Next Steps:"
if [ $FAILED_CHECKS -gt 0 ]; then
    echo "1. Review failed checks in the report"
    echo "2. Run emergency-fix-deployment.sh if needed"
    echo "3. Re-run this diagnostic after fixes"
fi
echo "4. Monitor error logs: tail -f storage/logs/laravel.log"
echo "5. Check web server logs: tail -f /var/log/nginx/error.log"
echo ""
echo "=================================================="
