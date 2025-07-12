#!/bin/bash

# BestHammer NTool Platform - Fixed Source File Diagnostic
# This script performs comprehensive analysis with improved error handling

set -e

# Configuration
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Improved logging functions with error handling
log() { echo -e "${GREEN}✅ $1${NC}"; ((PASSED_CHECKS++)); ((TOTAL_CHECKS++)); }
warning() { echo -e "${YELLOW}⚠️ $1${NC}"; ((WARNING_CHECKS++)); ((TOTAL_CHECKS++)); }
error() { echo -e "${RED}❌ $1${NC}"; ((FAILED_CHECKS++)); ((TOTAL_CHECKS++)); }
info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
section() { echo -e "${PURPLE}🔍 $1${NC}"; }
detail() { echo -e "${CYAN}   → $1${NC}"; }

# Safe command execution
safe_exec() {
    local cmd="$1"
    local description="$2"
    
    if eval "$cmd" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Safe JSON parsing
safe_jq() {
    local file="$1"
    local query="$2"
    
    if [ -f "$file" ] && command_exists jq; then
        if jq empty "$file" 2>/dev/null; then
            jq -r "$query" "$file" 2>/dev/null || echo ""
        else
            echo ""
        fi
    else
        echo ""
    fi
}

echo "🔍 BestHammer NTool Platform - Fixed Source Diagnostic"
echo "======================================================"
echo "Web Root: $WEB_ROOT"
echo "Web User: $WEB_USER"
echo "Diagnostic Time: $(date)"
echo "======================================================"
echo

# Pre-flight checks
section "Pre-flight Environment Checks"

# Check if running as root or with sudo
if [[ $EUID -eq 0 ]]; then
    info "Running as root"
elif command_exists sudo; then
    info "Running with sudo available"
else
    warning "Not running as root and sudo not available - some checks may fail"
fi

# Check if web root exists
if [ ! -d "$WEB_ROOT" ]; then
    error "Web root directory does not exist: $WEB_ROOT"
    echo "Please verify the correct path and try again."
    exit 1
fi

cd "$WEB_ROOT" || exit 1
log "Web root directory accessible"

# Check required tools
REQUIRED_TOOLS=("php" "mysql" "curl")
OPTIONAL_TOOLS=("jq" "composer" "npm")

for tool in "${REQUIRED_TOOLS[@]}"; do
    if command_exists "$tool"; then
        detail "✓ $tool available"
    else
        error "$tool not available - some checks will be skipped"
    fi
done

for tool in "${OPTIONAL_TOOLS[@]}"; do
    if command_exists "$tool"; then
        detail "✓ $tool available"
    else
        warning "$tool not available - related checks will be limited"
    fi
done

# Section 1: Laravel Core Structure Analysis
section "Section 1: Laravel Core Structure Analysis"

# Define Laravel core files array
declare -a LARAVEL_CORE_FILES=(
    "artisan"
    "bootstrap/app.php"
    "app/Http/Kernel.php"
    "app/Console/Kernel.php"
    "app/Exceptions/Handler.php"
    "config/app.php"
    "config/database.php"
    "routes/web.php"
    "routes/api.php"
    ".env"
    "composer.json"
)

info "Checking Laravel core files..."
for file in "${LARAVEL_CORE_FILES[@]}"; do
    if [ -f "$file" ]; then
        # Check file syntax for PHP files
        if [[ "$file" == *.php ]]; then
            if command_exists php && safe_exec "php -l '$file'" "PHP syntax check"; then
                log "$file (syntax OK)"
            else
                error "$file (syntax error)"
                if command_exists php; then
                    detail "$(php -l "$file" 2>&1 | head -2 | tail -1)"
                fi
            fi
        else
            log "$file (exists)"
        fi
    else
        error "$file (missing)"
    fi
done

# Section 2: Application Controllers Analysis
section "Section 2: Application Controllers Analysis"

declare -a CONTROLLERS=(
    "app/Http/Controllers/BmiController.php"
    "app/Http/Controllers/CurrencyController.php"
    "app/Http/Controllers/LoanController.php"
)

info "Analyzing BestHammer controllers..."
for controller in "${CONTROLLERS[@]}"; do
    if [ -f "$controller" ]; then
        # Check syntax
        if command_exists php && safe_exec "php -l '$controller'" "Controller syntax check"; then
            log "$controller (syntax OK)"
            
            # Check for required methods based on controller name
            CONTROLLER_NAME=$(basename "$controller" .php)
            declare -a REQUIRED_METHODS=()
            
            case "$CONTROLLER_NAME" in
                "BmiController")
                    REQUIRED_METHODS=("index" "calculate")
                    ;;
                "CurrencyController")
                    REQUIRED_METHODS=("index" "convert")
                    ;;
                "LoanController")
                    REQUIRED_METHODS=("index" "calculate")
                    ;;
            esac
            
            for method in "${REQUIRED_METHODS[@]}"; do
                if grep -q "function $method" "$controller" 2>/dev/null; then
                    detail "✓ Method $method found"
                else
                    warning "Method $method missing in $CONTROLLER_NAME"
                fi
            done
            
            # Check for proper namespace
            if grep -q "namespace App\\\\Http\\\\Controllers;" "$controller" 2>/dev/null; then
                detail "✓ Correct namespace"
            else
                warning "Namespace may be incorrect in $controller"
            fi
            
        else
            error "$controller (syntax error)"
        fi
    else
        error "$controller (missing)"
    fi
done

# Section 3: Service Classes Analysis
section "Section 3: Service Classes Analysis"

declare -a SERVICES=(
    "app/Services/BmiCalculatorService.php"
    "app/Services/CurrencyService.php"
    "app/Services/LoanCalculatorService.php"
)

info "Analyzing service classes..."
for service in "${SERVICES[@]}"; do
    if [ -f "$service" ]; then
        if command_exists php && safe_exec "php -l '$service'" "Service syntax check"; then
            log "$service (syntax OK)"
            
            # Check for calculate method (common to all services)
            if grep -q "function calculate" "$service" 2>/dev/null; then
                detail "✓ Calculate method found"
            else
                warning "Calculate method missing in $(basename "$service")"
            fi
            
            # Check namespace
            if grep -q "namespace App\\\\Services;" "$service" 2>/dev/null; then
                detail "✓ Correct namespace"
            else
                warning "Namespace may be incorrect in $service"
            fi
            
        else
            error "$service (syntax error)"
        fi
    else
        error "$service (missing)"
    fi
done

# Section 4: Models Analysis
section "Section 4: Models Analysis"

declare -a MODELS=(
    "app/Models/User.php"
    "app/Models/BmiRecord.php"
    "app/Models/CurrencyConversion.php"
    "app/Models/LoanCalculation.php"
)

info "Analyzing Eloquent models..."
for model in "${MODELS[@]}"; do
    if [ -f "$model" ]; then
        if command_exists php && safe_exec "php -l '$model'" "Model syntax check"; then
            log "$model (syntax OK)"
            
            # Check for Eloquent model structure
            if grep -q "extends.*Model\\|extends.*Authenticatable" "$model" 2>/dev/null; then
                detail "✓ Extends proper base class"
            else
                warning "May not extend proper Eloquent base class"
            fi
            
            # Check for fillable property
            if grep -q "protected.*fillable" "$model" 2>/dev/null; then
                detail "✓ Has fillable property"
            else
                warning "Missing fillable property"
            fi
            
        else
            error "$model (syntax error)"
        fi
    else
        error "$model (missing)"
    fi
done

# Section 5: View Files Analysis
section "Section 5: View Files Analysis"

declare -a VIEW_FILES=(
    "resources/views/layouts/app.blade.php"
    "resources/views/welcome.blade.php"
    "resources/views/calculators/bmi/index.blade.php"
    "resources/views/calculators/currency/index.blade.php"
    "resources/views/calculators/loan/index.blade.php"
)

info "Analyzing Blade view files..."
for view in "${VIEW_FILES[@]}"; do
    if [ -f "$view" ]; then
        log "$view (exists)"
        
        # Check for basic Blade structure
        if grep -q "@extends\\|@section\\|@yield" "$view" 2>/dev/null; then
            detail "✓ Contains Blade directives"
        else
            warning "May not be a proper Blade template"
        fi
        
        # Check for CSRF token in forms
        if grep -q "<form" "$view" 2>/dev/null; then
            if grep -q "@csrf\\|csrf_token" "$view" 2>/dev/null; then
                detail "✓ Contains CSRF protection"
            else
                warning "Form found but no CSRF protection"
            fi
        fi
        
    else
        error "$view (missing)"
    fi
done

info "✓ Basic structure analysis completed"

# Section 6: Composer Dependencies Analysis
section "Section 6: Composer Dependencies Analysis"

info "Analyzing Composer configuration and dependencies..."

# Check composer.json structure
if [ -f "composer.json" ]; then
    if command_exists jq && safe_exec "jq empty composer.json" "JSON validation"; then
        log "composer.json (valid JSON)"

        # Check Laravel framework version
        LARAVEL_VERSION=$(safe_jq "composer.json" '.require["laravel/framework"] // empty')
        if [ -n "$LARAVEL_VERSION" ]; then
            detail "✓ Laravel framework: $LARAVEL_VERSION"
        else
            warning "Laravel framework not specified in composer.json"
        fi

        # Check critical dependencies
        declare -a CRITICAL_DEPS=("guzzlehttp/guzzle" "laravel/sanctum")
        for dep in "${CRITICAL_DEPS[@]}"; do
            DEP_VERSION=$(safe_jq "composer.json" ".require[\"$dep\"] // empty")
            if [ -n "$DEP_VERSION" ]; then
                detail "✓ $dep: $DEP_VERSION"
            else
                warning "$dep not found in dependencies"
            fi
        done

    elif command_exists jq; then
        error "composer.json (invalid JSON)"
    else
        warning "composer.json exists but jq not available for validation"
        log "composer.json (exists - cannot validate without jq)"
    fi
else
    error "composer.json (missing)"
fi

# Check composer.lock
if [ -f "composer.lock" ]; then
    if command_exists jq && safe_exec "jq empty composer.lock" "Lock file validation"; then
        log "composer.lock (valid JSON)"

        # Count installed packages
        if command_exists jq; then
            INSTALLED_PACKAGES=$(safe_jq "composer.lock" '.packages | length')
            if [ -n "$INSTALLED_PACKAGES" ] && [ "$INSTALLED_PACKAGES" -gt 0 ]; then
                detail "✓ $INSTALLED_PACKAGES packages locked"
            fi
        fi

    else
        warning "composer.lock exists but may be invalid"
    fi
else
    warning "composer.lock (missing - run composer install)"
fi

# Check vendor directory
if [ -d "vendor" ]; then
    log "vendor directory (exists)"

    # Check autoload file
    if [ -f "vendor/autoload.php" ]; then
        detail "✓ Autoload file exists"

        # Test autoload functionality
        if command_exists php && safe_exec "php -r \"require 'vendor/autoload.php'; echo 'OK';\"" "Autoload test"; then
            detail "✓ Autoload works"
        else
            error "Autoload has issues"
        fi
    else
        error "vendor/autoload.php missing"
    fi

    # Check Laravel framework installation
    if [ -d "vendor/laravel/framework" ]; then
        detail "✓ Laravel framework installed"
    else
        error "Laravel framework not installed in vendor"
    fi

    # Check critical packages
    declare -a CRITICAL_PACKAGES=("illuminate/foundation" "illuminate/console" "guzzlehttp/guzzle")
    for package in "${CRITICAL_PACKAGES[@]}"; do
        PACKAGE_PATH="vendor/${package}"
        if [ -d "$PACKAGE_PATH" ]; then
            detail "✓ $package installed"
        else
            warning "$package not installed"
        fi
    done

else
    error "vendor directory missing - run composer install"
fi

# Section 7: Environment Configuration Analysis
section "Section 7: Environment Configuration Analysis"

info "Analyzing environment configuration..."

# Check .env file
if [ -f ".env" ]; then
    log ".env file (exists)"

    # Check critical environment variables
    declare -a CRITICAL_ENV_VARS=(
        "APP_NAME"
        "APP_ENV"
        "APP_KEY"
        "APP_DEBUG"
        "APP_URL"
        "DB_CONNECTION"
        "DB_HOST"
        "DB_DATABASE"
        "DB_USERNAME"
    )

    for var in "${CRITICAL_ENV_VARS[@]}"; do
        if grep -q "^$var=" ".env" 2>/dev/null; then
            VALUE=$(grep "^$var=" ".env" | cut -d'=' -f2- | tr -d '"' 2>/dev/null || echo "")
            if [ -n "$VALUE" ]; then
                if [ "$var" = "APP_KEY" ]; then
                    if [[ $VALUE == base64:* ]]; then
                        detail "✓ $var (properly encoded)"
                    else
                        error "$var (not base64 encoded)"
                    fi
                elif [ "$var" = "DB_PASSWORD" ]; then
                    detail "✓ $var (set)"
                else
                    detail "✓ $var = $VALUE"
                fi
            else
                error "$var is empty"
            fi
        else
            error "$var not found in .env"
        fi
    done

else
    error ".env file missing"
fi

# Check .env.example
if [ -f ".env.example" ]; then
    log ".env.example (exists)"
else
    warning ".env.example missing"
fi

# Section 8: Database Configuration Analysis
section "Section 8: Database Configuration Analysis"

info "Analyzing database configuration..."

# Test database connection if credentials are available and mysql is available
if [ -f ".env" ] && command_exists mysql; then
    DB_HOST=$(grep "^DB_HOST=" ".env" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")
    DB_DATABASE=$(grep "^DB_DATABASE=" ".env" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")
    DB_USERNAME=$(grep "^DB_USERNAME=" ".env" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")
    DB_PASSWORD=$(grep "^DB_PASSWORD=" ".env" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")

    if [ -n "$DB_HOST" ] && [ -n "$DB_DATABASE" ] && [ -n "$DB_USERNAME" ]; then
        if safe_exec "mysql -h'$DB_HOST' -u'$DB_USERNAME' -p'$DB_PASSWORD' -e 'USE $DB_DATABASE;'" "Database connection test"; then
            log "Database connection (successful)"

            # Check for tables
            TABLE_COUNT=$(mysql -h"$DB_HOST" -u"$DB_USERNAME" -p"$DB_PASSWORD" -D"$DB_DATABASE" -e "SHOW TABLES;" 2>/dev/null | wc -l || echo "0")
            if [ "$TABLE_COUNT" -gt 1 ]; then
                detail "✓ Database has $((TABLE_COUNT-1)) tables"
            else
                warning "Database is empty - migrations may need to be run"
            fi
        else
            error "Database connection failed"
        fi
    else
        warning "Database configuration incomplete"
    fi
elif ! command_exists mysql; then
    warning "MySQL client not available for database testing"
else
    warning "Cannot test database - .env file missing"
fi

# Check migration files
if [ -d "database/migrations" ]; then
    MIGRATION_COUNT=$(find database/migrations -name "*.php" 2>/dev/null | wc -l || echo "0")
    if [ "$MIGRATION_COUNT" -gt 0 ]; then
        log "Migration files ($MIGRATION_COUNT found)"
    else
        warning "No migration files found"
    fi
else
    warning "database/migrations directory missing"
fi

# Section 9: Route Configuration Analysis
section "Section 9: Route Configuration Analysis"

info "Analyzing route configurations..."

# Check web routes
if [ -f "routes/web.php" ]; then
    if command_exists php && safe_exec "php -l 'routes/web.php'" "Web routes syntax"; then
        log "routes/web.php (syntax OK)"

        # Check for required routes
        declare -a REQUIRED_WEB_ROUTES=("bmi-calculator" "currency-converter" "loan-calculator")
        for route in "${REQUIRED_WEB_ROUTES[@]}"; do
            if grep -q "$route" "routes/web.php" 2>/dev/null; then
                detail "✓ Route $route found"
            else
                warning "Route $route missing"
            fi
        done

    else
        error "routes/web.php (syntax error)"
    fi
else
    error "routes/web.php (missing)"
fi

# Check API routes
if [ -f "routes/api.php" ]; then
    if command_exists php && safe_exec "php -l 'routes/api.php'" "API routes syntax"; then
        log "routes/api.php (syntax OK)"

        # Check for API endpoints
        declare -a API_ENDPOINTS=("calculate-bmi" "convert-currency" "calculate-loan")
        for endpoint in "${API_ENDPOINTS[@]}"; do
            if grep -q "$endpoint" "routes/api.php" 2>/dev/null; then
                detail "✓ API endpoint $endpoint found"
            else
                warning "API endpoint $endpoint missing"
            fi
        done

    else
        error "routes/api.php (syntax error)"
    fi
else
    error "routes/api.php (missing)"
fi

info "✓ Configuration analysis completed"

# Section 10: Security Configuration Analysis
section "Section 10: Security Configuration Analysis"

info "Analyzing security configurations..."

# Check CSRF protection
if [ -f "app/Http/Middleware/VerifyCsrfToken.php" ]; then
    log "CSRF protection middleware (exists)"

    # Check if it's properly configured in Kernel
    if [ -f "app/Http/Kernel.php" ]; then
        if grep -q "VerifyCsrfToken" "app/Http/Kernel.php" 2>/dev/null; then
            detail "✓ CSRF middleware registered"
        else
            warning "CSRF middleware not registered in Kernel"
        fi
    fi
else
    error "CSRF protection middleware missing"
fi

# Check authentication middleware
if [ -f "app/Http/Middleware/Authenticate.php" ]; then
    log "Authentication middleware (exists)"
else
    warning "Authentication middleware missing"
fi

# Check for rate limiting in routes
if [ -f "routes/api.php" ]; then
    if grep -q "throttle" "routes/api.php" 2>/dev/null; then
        log "API rate limiting (configured)"
    else
        warning "No API rate limiting found"
    fi
fi

# Check for input validation in controllers
CONTROLLERS_WITH_VALIDATION=0
for controller in app/Http/Controllers/*.php; do
    if [ -f "$controller" ]; then
        if grep -q "validate\\|Validator::" "$controller" 2>/dev/null; then
            ((CONTROLLERS_WITH_VALIDATION++))
        fi
    fi
done

if [ "$CONTROLLERS_WITH_VALIDATION" -gt 0 ]; then
    log "Input validation ($CONTROLLERS_WITH_VALIDATION controllers have validation)"
else
    warning "No input validation found in controllers"
fi

# Section 11: Performance and Error Handling Analysis
section "Section 11: Performance and Error Handling Analysis"

info "Analyzing performance and error handling..."

# Check for caching in services
SERVICES_WITH_CACHING=0
for service in app/Services/*.php; do
    if [ -f "$service" ]; then
        if grep -q "Cache::\\|cache(" "$service" 2>/dev/null; then
            ((SERVICES_WITH_CACHING++))
        fi
    fi
done

if [ "$SERVICES_WITH_CACHING" -gt 0 ]; then
    log "Service caching ($SERVICES_WITH_CACHING services use caching)"
else
    warning "No caching found in services"
fi

# Check Laravel optimization files
declare -a OPTIMIZATION_FILES=(
    "bootstrap/cache/config.php"
    "bootstrap/cache/routes.php"
    "bootstrap/cache/packages.php"
    "bootstrap/cache/services.php"
)

OPTIMIZED_COUNT=0
for opt_file in "${OPTIMIZATION_FILES[@]}"; do
    if [ -f "$opt_file" ]; then
        ((OPTIMIZED_COUNT++))
    fi
done

if [ "$OPTIMIZED_COUNT" -gt 0 ]; then
    log "Laravel optimization ($OPTIMIZED_COUNT optimization files found)"
else
    warning "No Laravel optimization files found - run artisan optimize"
fi

# Check exception handler
if [ -f "app/Exceptions/Handler.php" ]; then
    log "Exception handler (exists)"

    if grep -q "function register\\|function report" "app/Exceptions/Handler.php" 2>/dev/null; then
        detail "✓ Has error handling methods"
    else
        warning "Exception handler may be incomplete"
    fi
else
    error "Exception handler missing"
fi

# Check for try-catch blocks in controllers
CONTROLLERS_WITH_ERROR_HANDLING=0
for controller in app/Http/Controllers/*.php; do
    if [ -f "$controller" ]; then
        if grep -q "try\\s*{.*catch" "$controller" 2>/dev/null; then
            ((CONTROLLERS_WITH_ERROR_HANDLING++))
        fi
    fi
done

if [ "$CONTROLLERS_WITH_ERROR_HANDLING" -gt 0 ]; then
    log "Controller error handling ($CONTROLLERS_WITH_ERROR_HANDLING controllers have try-catch)"
else
    warning "No try-catch blocks found in controllers"
fi

# Check log directory
if [ -d "storage/logs" ]; then
    log "Log directory (exists)"

    LOG_FILES=$(find storage/logs -name "*.log" 2>/dev/null | wc -l || echo "0")
    if [ "$LOG_FILES" -gt 0 ]; then
        detail "✓ $LOG_FILES log files found"
    else
        detail "No log files yet"
    fi
else
    error "Log directory missing"
fi

# Section 12: Completeness Score Calculation
section "Section 12: Completeness Score Calculation"

info "Calculating overall completeness score..."

# Calculate scores with safe arithmetic
TOTAL_POSSIBLE_SCORE=100
CURRENT_SCORE=0

# Avoid division by zero
if [ "$TOTAL_CHECKS" -gt 0 ]; then
    # Core files score (40 points)
    CORE_FILES_FOUND=0
    for file in "${LARAVEL_CORE_FILES[@]}"; do
        if [ -f "$file" ]; then
            ((CORE_FILES_FOUND++))
        fi
    done

    CORE_FILES_TOTAL=${#LARAVEL_CORE_FILES[@]}
    if [ "$CORE_FILES_TOTAL" -gt 0 ]; then
        CORE_FILES_SCORE=$((CORE_FILES_FOUND * 40 / CORE_FILES_TOTAL))
        CURRENT_SCORE=$((CURRENT_SCORE + CORE_FILES_SCORE))
    fi

    # Application files score (30 points)
    APP_FILES_FOUND=0
    for controller in "${CONTROLLERS[@]}"; do
        if [ -f "$controller" ]; then
            ((APP_FILES_FOUND++))
        fi
    done

    for service in "${SERVICES[@]}"; do
        if [ -f "$service" ]; then
            ((APP_FILES_FOUND++))
        fi
    done

    APP_FILES_TOTAL=$((${#CONTROLLERS[@]} + ${#SERVICES[@]}))
    if [ "$APP_FILES_TOTAL" -gt 0 ]; then
        APP_FILES_SCORE=$((APP_FILES_FOUND * 30 / APP_FILES_TOTAL))
        CURRENT_SCORE=$((CURRENT_SCORE + APP_FILES_SCORE))
    fi

    # Dependencies score (20 points)
    DEPS_SCORE=0
    if [ -d "vendor" ] && [ -f "vendor/autoload.php" ]; then
        DEPS_SCORE=$((DEPS_SCORE + 10))
    fi
    if [ -f "composer.lock" ]; then
        DEPS_SCORE=$((DEPS_SCORE + 5))
    fi
    if [ -d "vendor/laravel/framework" ]; then
        DEPS_SCORE=$((DEPS_SCORE + 5))
    fi
    CURRENT_SCORE=$((CURRENT_SCORE + DEPS_SCORE))

    # Configuration score (10 points)
    CONFIG_SCORE=0
    if [ -f ".env" ]; then
        CONFIG_SCORE=$((CONFIG_SCORE + 5))
    fi
    if grep -q "^APP_KEY=base64:" ".env" 2>/dev/null; then
        CONFIG_SCORE=$((CONFIG_SCORE + 5))
    fi
    CURRENT_SCORE=$((CURRENT_SCORE + CONFIG_SCORE))

    # Calculate success rate
    SUCCESS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
else
    SUCCESS_RATE=0
fi

# Generate report
REPORT_FILE="/tmp/besthammer_source_diagnostic_fixed_${TIMESTAMP}.txt"

cat > "$REPORT_FILE" << EOF
BestHammer NTool Platform - Fixed Source Diagnostic Report
=========================================================
Generated: $(date)
Web Root: $WEB_ROOT
Web User: $WEB_USER

OVERALL COMPLETENESS SCORE: ${CURRENT_SCORE}/100
============================================

ANALYSIS STATISTICS:
===================
Total Checks Performed: $TOTAL_CHECKS
✅ Passed: $PASSED_CHECKS
⚠️ Warnings: $WARNING_CHECKS
❌ Failed: $FAILED_CHECKS

Success Rate: ${SUCCESS_RATE}%

SCORE BREAKDOWN:
===============
- Core Laravel Files: Found $CORE_FILES_FOUND of ${#LARAVEL_CORE_FILES[@]}
- Application Files: Found $APP_FILES_FOUND of $APP_FILES_TOTAL
- Dependencies: $([ -d "vendor" ] && echo "Installed" || echo "Missing")
- Configuration: $([ -f ".env" ] && echo "Present" || echo "Missing")

RECOMMENDATIONS:
===============
EOF

# Add recommendations based on score
if [ "$CURRENT_SCORE" -ge 80 ]; then
    cat >> "$REPORT_FILE" << EOF
🎉 EXCELLENT: Your application is well-structured and nearly complete.
- Address any remaining warnings
- Run performance optimization
- Conduct thorough testing
EOF
elif [ "$CURRENT_SCORE" -ge 60 ]; then
    cat >> "$REPORT_FILE" << EOF
✅ GOOD: Your application is mostly complete with some improvements needed.
- Fix missing files and configurations
- Implement proper error handling
- Add input validation where missing
EOF
elif [ "$CURRENT_SCORE" -ge 40 ]; then
    cat >> "$REPORT_FILE" << EOF
⚠️ NEEDS WORK: Significant gaps need attention.
- Install missing dependencies: composer install
- Create missing core files
- Configure environment variables
- Implement security measures
EOF
else
    cat >> "$REPORT_FILE" << EOF
❌ CRITICAL: Major work required.
- Many essential files are missing
- Dependencies not installed
- Configuration incomplete
- Run Laravel setup scripts
EOF
fi

cat >> "$REPORT_FILE" << EOF

NEXT STEPS:
==========
1. Address critical issues (❌) first
2. Review and fix warnings (⚠️)
3. Install dependencies if missing
4. Configure environment properly
5. Test all functionality

Report generated at: $(date)
=========================================================
EOF

# Final Summary
section "Final Summary and Recommendations"

echo
echo "🎯 FIXED DIAGNOSTIC SUMMARY"
echo "==========================="
echo
echo "📊 OVERALL COMPLETENESS SCORE: ${CURRENT_SCORE}/100"
echo

# Color-coded score display
if [ "$CURRENT_SCORE" -ge 80 ]; then
    echo -e "${GREEN}🎉 EXCELLENT (80-100): Application is well-structured${NC}"
elif [ "$CURRENT_SCORE" -ge 60 ]; then
    echo -e "${GREEN}✅ GOOD (60-79): Application is mostly complete${NC}"
elif [ "$CURRENT_SCORE" -ge 40 ]; then
    echo -e "${YELLOW}⚠️ NEEDS WORK (40-59): Significant improvements needed${NC}"
else
    echo -e "${RED}❌ CRITICAL (0-39): Major work required${NC}"
fi

echo
echo "📈 ANALYSIS STATISTICS:"
echo "======================"
echo "Total Checks: $TOTAL_CHECKS"
echo "✅ Passed: $PASSED_CHECKS (${SUCCESS_RATE}%)"
echo "⚠️ Warnings: $WARNING_CHECKS"
echo "❌ Failed: $FAILED_CHECKS"

echo
echo "📄 DETAILED REPORT: $REPORT_FILE"
echo "📋 To view full report: cat $REPORT_FILE"

echo
echo "🔧 RECOMMENDED NEXT STEPS:"
echo "========================="

if [ "$FAILED_CHECKS" -gt 10 ]; then
    echo "1. Run: sudo ./fix-laravel-compatibility-safe.sh"
    echo "2. Install dependencies: composer install"
    echo "3. Configure environment: cp .env.example .env"
    echo "4. Generate app key: php artisan key:generate"
elif [ "$FAILED_CHECKS" -gt 5 ]; then
    echo "1. Address missing files and configurations"
    echo "2. Fix syntax errors in existing files"
    echo "3. Install any missing dependencies"
elif [ "$FAILED_CHECKS" -gt 0 ]; then
    echo "1. Review and fix remaining issues"
    echo "2. Test all functionality"
    echo "3. Optimize performance"
else
    echo "1. All checks passed - application is ready"
    echo "2. Consider performance optimization"
    echo "3. Conduct thorough testing"
fi

echo
echo "================================================================"
echo "Fixed source diagnostic completed at $(date)"
echo "================================================================"
