#!/bin/bash

# BestHammer NTool Platform - Comprehensive Source File Diagnostic
# This script performs deep analysis of all source files, dependencies, and configurations

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

log() { echo -e "${GREEN}✅ $1${NC}"; ((PASSED_CHECKS++)); ((TOTAL_CHECKS++)); }
warning() { echo -e "${YELLOW}⚠️ $1${NC}"; ((WARNING_CHECKS++)); ((TOTAL_CHECKS++)); }
error() { echo -e "${RED}❌ $1${NC}"; ((FAILED_CHECKS++)); ((TOTAL_CHECKS++)); }
info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
section() { echo -e "${PURPLE}🔍 $1${NC}"; }
detail() { echo -e "${CYAN}   → $1${NC}"; }

echo "🔍 BestHammer NTool Platform - Comprehensive Source Diagnostic"
echo "=============================================================="
echo "Web Root: $WEB_ROOT"
echo "Web User: $WEB_USER"
echo "Diagnostic Time: $(date)"
echo "=============================================================="
echo

cd "$WEB_ROOT"

# Section 1: Laravel Core Structure Analysis
section "Section 1: Laravel Core Structure Analysis"

# Check Laravel core files
LARAVEL_CORE_FILES=(
    "artisan"
    "bootstrap/app.php"
    "app/Http/Kernel.php"
    "app/Console/Kernel.php"
    "app/Exceptions/Handler.php"
    "config/app.php"
    "config/database.php"
    "config/auth.php"
    "config/cache.php"
    "routes/web.php"
    "routes/api.php"
    "routes/console.php"
    ".env"
    "composer.json"
    "composer.lock"
    "package.json"
)

info "Checking Laravel core files..."
for file in "${LARAVEL_CORE_FILES[@]}"; do
    if [ -f "$file" ]; then
        # Check file syntax for PHP files
        if [[ "$file" == *.php ]]; then
            if php -l "$file" &>/dev/null; then
                log "$file (syntax OK)"
            else
                error "$file (syntax error)"
                detail "$(php -l "$file" 2>&1 | head -2)"
            fi
        else
            log "$file (exists)"
        fi
    else
        error "$file (missing)"
    fi
done

# Section 2: BestHammer Application Controllers Analysis
section "Section 2: BestHammer Application Controllers Analysis"

CONTROLLERS=(
    "app/Http/Controllers/BmiController.php"
    "app/Http/Controllers/CurrencyController.php"
    "app/Http/Controllers/LoanController.php"
)

info "Analyzing BestHammer controllers..."
for controller in "${CONTROLLERS[@]}"; do
    if [ -f "$controller" ]; then
        # Check syntax
        if php -l "$controller" &>/dev/null; then
            log "$controller (syntax OK)"
            
            # Check for required methods
            CONTROLLER_NAME=$(basename "$controller" .php)
            case "$CONTROLLER_NAME" in
                "BmiController")
                    REQUIRED_METHODS=("index" "calculate" "history" "trends" "exportPdf" "exportExcel")
                    ;;
                "CurrencyController")
                    REQUIRED_METHODS=("index" "convert" "batchConvert" "rates")
                    ;;
                "LoanController")
                    REQUIRED_METHODS=("index" "calculate")
                    ;;
            esac
            
            for method in "${REQUIRED_METHODS[@]}"; do
                if grep -q "function $method" "$controller"; then
                    detail "✓ Method $method found"
                else
                    warning "Method $method missing in $CONTROLLER_NAME"
                fi
            done
            
            # Check for proper namespace
            if grep -q "namespace App\\Http\\Controllers;" "$controller"; then
                detail "✓ Correct namespace"
            else
                error "Incorrect or missing namespace in $controller"
            fi
            
        else
            error "$controller (syntax error)"
            detail "$(php -l "$controller" 2>&1 | head -2)"
        fi
    else
        error "$controller (missing)"
    fi
done

# Section 3: Service Classes Analysis
section "Section 3: Service Classes Analysis"

SERVICES=(
    "app/Services/BmiCalculatorService.php"
    "app/Services/CurrencyService.php"
    "app/Services/LoanCalculatorService.php"
)

info "Analyzing service classes..."
for service in "${SERVICES[@]}"; do
    if [ -f "$service" ]; then
        if php -l "$service" &>/dev/null; then
            log "$service (syntax OK)"
            
            # Check for required methods in services
            SERVICE_NAME=$(basename "$service" .php)
            case "$SERVICE_NAME" in
                "BmiCalculatorService")
                    REQUIRED_METHODS=("calculate" "calculateIdealWeightRange" "analyzeBodyFat" "generateNutritionPlan")
                    ;;
                "CurrencyService")
                    REQUIRED_METHODS=("convert" "batchConvert" "getSupportedCurrencies" "getAllRates")
                    ;;
                "LoanCalculatorService")
                    REQUIRED_METHODS=("calculate" "generateAmortizationSchedule" "calculateScenarios")
                    ;;
            esac
            
            for method in "${REQUIRED_METHODS[@]}"; do
                if grep -q "function $method" "$service"; then
                    detail "✓ Method $method found"
                else
                    warning "Method $method missing in $SERVICE_NAME"
                fi
            done
            
            # Check namespace
            if grep -q "namespace App\\Services;" "$service"; then
                detail "✓ Correct namespace"
            else
                error "Incorrect or missing namespace in $service"
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

MODELS=(
    "app/Models/User.php"
    "app/Models/BmiRecord.php"
    "app/Models/CurrencyConversion.php"
    "app/Models/LoanCalculation.php"
)

info "Analyzing Eloquent models..."
for model in "${MODELS[@]}"; do
    if [ -f "$model" ]; then
        if php -l "$model" &>/dev/null; then
            log "$model (syntax OK)"
            
            # Check for Eloquent model structure
            if grep -q "extends.*Model\|extends.*Authenticatable" "$model"; then
                detail "✓ Extends proper base class"
            else
                warning "May not extend proper Eloquent base class"
            fi
            
            # Check for fillable property
            if grep -q "protected \$fillable" "$model"; then
                detail "✓ Has fillable property"
            else
                warning "Missing fillable property"
            fi
            
            # Check namespace
            if grep -q "namespace App\\Models;" "$model"; then
                detail "✓ Correct namespace"
            else
                error "Incorrect or missing namespace"
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

VIEW_FILES=(
    "resources/views/layouts/app.blade.php"
    "resources/views/welcome.blade.php"
    "resources/views/calculators/bmi/index.blade.php"
    "resources/views/calculators/currency/index.blade.php"
    "resources/views/calculators/loan/index.blade.php"
    "resources/views/legal/privacy.blade.php"
    "resources/views/legal/terms.blade.php"
    "resources/views/legal/cookies.blade.php"
)

info "Analyzing Blade view files..."
for view in "${VIEW_FILES[@]}"; do
    if [ -f "$view" ]; then
        log "$view (exists)"
        
        # Check for basic Blade structure
        if grep -q "@extends\|@section\|@yield" "$view"; then
            detail "✓ Contains Blade directives"
        else
            warning "May not be a proper Blade template"
        fi
        
        # Check for CSRF token in forms
        if grep -q "<form" "$view"; then
            if grep -q "@csrf\|csrf_token" "$view"; then
                detail "✓ Contains CSRF protection"
            else
                warning "Form found but no CSRF protection"
            fi
        fi
        
        # Check for XSS protection
        if grep -q "{{.*}}" "$view"; then
            detail "✓ Uses Blade escaping"
        fi
        
    else
        error "$view (missing)"
    fi
done

# Section 6: Route Configuration Analysis
section "Section 6: Route Configuration Analysis"

info "Analyzing route configurations..."

# Check web routes
if [ -f "routes/web.php" ]; then
    if php -l "routes/web.php" &>/dev/null; then
        log "routes/web.php (syntax OK)"
        
        # Check for required routes
        REQUIRED_WEB_ROUTES=("bmi-calculator" "currency-converter" "loan-calculator")
        for route in "${REQUIRED_WEB_ROUTES[@]}"; do
            if grep -q "$route" "routes/web.php"; then
                detail "✓ Route $route found"
            else
                warning "Route $route missing"
            fi
        done
        
        # Check for middleware usage
        if grep -q "middleware" "routes/web.php"; then
            detail "✓ Middleware usage found"
        fi
        
    else
        error "routes/web.php (syntax error)"
    fi
else
    error "routes/web.php (missing)"
fi

# Check API routes
if [ -f "routes/api.php" ]; then
    if php -l "routes/api.php" &>/dev/null; then
        log "routes/api.php (syntax OK)"
        
        # Check for API endpoints
        API_ENDPOINTS=("calculate-bmi" "convert-currency" "calculate-loan")
        for endpoint in "${API_ENDPOINTS[@]}"; do
            if grep -q "$endpoint" "routes/api.php"; then
                detail "✓ API endpoint $endpoint found"
            else
                warning "API endpoint $endpoint missing"
            fi
        done
        
        # Check for throttling
        if grep -q "throttle" "routes/api.php"; then
            detail "✓ Rate limiting configured"
        else
            warning "No rate limiting found"
        fi
        
    else
        error "routes/api.php (syntax error)"
    fi
else
    error "routes/api.php (missing)"
fi

# Section 7: Middleware Analysis
section "Section 7: Middleware Analysis"

MIDDLEWARE_FILES=(
    "app/Http/Middleware/TrustProxies.php"
    "app/Http/Middleware/PreventRequestsDuringMaintenance.php"
    "app/Http/Middleware/TrimStrings.php"
    "app/Http/Middleware/EncryptCookies.php"
    "app/Http/Middleware/VerifyCsrfToken.php"
    "app/Http/Middleware/Authenticate.php"
    "app/Http/Middleware/RedirectIfAuthenticated.php"
    "app/Http/Middleware/ValidateSignature.php"
)

info "Analyzing middleware files..."
for middleware in "${MIDDLEWARE_FILES[@]}"; do
    if [ -f "$middleware" ]; then
        if php -l "$middleware" &>/dev/null; then
            log "$middleware (syntax OK)"
            
            # Check for handle method
            if grep -q "function handle" "$middleware"; then
                detail "✓ Handle method found"
            else
                warning "Handle method missing"
            fi
            
        else
            error "$middleware (syntax error)"
        fi
    else
        error "$middleware (missing)"
    fi
done

info "✓ Core structure analysis completed"

# Section 8: Composer Dependencies Analysis
section "Section 8: Composer Dependencies Analysis"

info "Analyzing Composer configuration and dependencies..."

# Check composer.json structure
if [ -f "composer.json" ]; then
    if jq empty composer.json 2>/dev/null; then
        log "composer.json (valid JSON)"

        # Check required sections
        REQUIRED_SECTIONS=("name" "require" "autoload")
        for section in "${REQUIRED_SECTIONS[@]}"; do
            if jq -e ".$section" composer.json >/dev/null 2>&1; then
                detail "✓ Section '$section' found"
            else
                error "Section '$section' missing"
            fi
        done

        # Check Laravel framework version
        LARAVEL_VERSION=$(jq -r '.require["laravel/framework"] // empty' composer.json)
        if [ -n "$LARAVEL_VERSION" ]; then
            detail "✓ Laravel framework: $LARAVEL_VERSION"
            if [[ "$LARAVEL_VERSION" == ^10.* ]]; then
                detail "✓ Laravel 10 compatible version"
            elif [[ "$LARAVEL_VERSION" == ^11.* ]]; then
                warning "Laravel 11 version may need compatibility adjustments"
            fi
        else
            error "Laravel framework not specified"
        fi

        # Check critical dependencies
        CRITICAL_DEPS=("guzzlehttp/guzzle" "laravel/sanctum" "laravel/tinker")
        for dep in "${CRITICAL_DEPS[@]}"; do
            if jq -e ".require[\"$dep\"]" composer.json >/dev/null 2>&1; then
                VERSION=$(jq -r ".require[\"$dep\"]" composer.json)
                detail "✓ $dep: $VERSION"
            else
                warning "$dep not found in dependencies"
            fi
        done

    else
        error "composer.json (invalid JSON)"
    fi
else
    error "composer.json (missing)"
fi

# Check composer.lock
if [ -f "composer.lock" ]; then
    if jq empty composer.lock 2>/dev/null; then
        log "composer.lock (valid JSON)"

        # Check if packages are actually installed
        INSTALLED_PACKAGES=$(jq -r '.packages[].name' composer.lock 2>/dev/null | wc -l)
        detail "✓ $INSTALLED_PACKAGES packages locked"

    else
        error "composer.lock (invalid JSON)"
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
        if php -r "require 'vendor/autoload.php'; echo 'Autoload OK';" &>/dev/null; then
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

        # Check Laravel version
        if [ -f "vendor/laravel/framework/composer.json" ]; then
            INSTALLED_LARAVEL=$(jq -r '.version' vendor/laravel/framework/composer.json 2>/dev/null)
            detail "✓ Installed Laravel version: $INSTALLED_LARAVEL"
        fi
    else
        error "Laravel framework not installed"
    fi

    # Check critical packages
    CRITICAL_PACKAGES=("illuminate/foundation" "illuminate/console" "illuminate/container" "guzzlehttp/guzzle")
    for package in "${CRITICAL_PACKAGES[@]}"; do
        PACKAGE_PATH="vendor/${package}"
        if [ -d "$PACKAGE_PATH" ]; then
            detail "✓ $package installed"
        else
            error "$package not installed"
        fi
    done

else
    error "vendor directory missing - run composer install"
fi

# Section 9: NPM Dependencies Analysis
section "Section 9: NPM Dependencies Analysis"

info "Analyzing NPM configuration and dependencies..."

# Check package.json
if [ -f "package.json" ]; then
    if jq empty package.json 2>/dev/null; then
        log "package.json (valid JSON)"

        # Check required sections
        if jq -e '.scripts' package.json >/dev/null 2>&1; then
            detail "✓ Scripts section found"

            # Check for build scripts
            BUILD_SCRIPTS=("dev" "build" "watch")
            for script in "${BUILD_SCRIPTS[@]}"; do
                if jq -e ".scripts[\"$script\"]" package.json >/dev/null 2>&1; then
                    detail "✓ Script '$script' found"
                else
                    warning "Script '$script' missing"
                fi
            done
        else
            warning "Scripts section missing"
        fi

        # Check dependencies
        if jq -e '.dependencies' package.json >/dev/null 2>&1; then
            DEPS_COUNT=$(jq '.dependencies | length' package.json)
            detail "✓ $DEPS_COUNT runtime dependencies"
        fi

        if jq -e '.devDependencies' package.json >/dev/null 2>&1; then
            DEV_DEPS_COUNT=$(jq '.devDependencies | length' package.json)
            detail "✓ $DEV_DEPS_COUNT development dependencies"
        fi

    else
        error "package.json (invalid JSON)"
    fi
else
    warning "package.json (missing)"
fi

# Check node_modules
if [ -d "node_modules" ]; then
    log "node_modules directory (exists)"
    NODE_MODULES_COUNT=$(find node_modules -maxdepth 1 -type d | wc -l)
    detail "✓ $((NODE_MODULES_COUNT-1)) packages installed"
else
    warning "node_modules directory missing - run npm install"
fi

# Section 10: Environment Configuration Analysis
section "Section 10: Environment Configuration Analysis"

info "Analyzing environment configuration..."

# Check .env file
if [ -f ".env" ]; then
    log ".env file (exists)"

    # Check critical environment variables
    CRITICAL_ENV_VARS=(
        "APP_NAME"
        "APP_ENV"
        "APP_KEY"
        "APP_DEBUG"
        "APP_URL"
        "DB_CONNECTION"
        "DB_HOST"
        "DB_DATABASE"
        "DB_USERNAME"
        "DB_PASSWORD"
    )

    for var in "${CRITICAL_ENV_VARS[@]}"; do
        if grep -q "^$var=" ".env"; then
            VALUE=$(grep "^$var=" ".env" | cut -d'=' -f2- | tr -d '"')
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
            error "$var not found"
        fi
    done

    # Check for production settings
    APP_ENV=$(grep "^APP_ENV=" ".env" | cut -d'=' -f2 | tr -d '"')
    if [ "$APP_ENV" = "production" ]; then
        detail "✓ Production environment"

        # Check debug setting
        APP_DEBUG=$(grep "^APP_DEBUG=" ".env" | cut -d'=' -f2 | tr -d '"')
        if [ "$APP_DEBUG" = "false" ]; then
            detail "✓ Debug disabled for production"
        else
            warning "Debug should be disabled in production"
        fi
    fi

else
    error ".env file missing"
fi

# Check .env.example
if [ -f ".env.example" ]; then
    log ".env.example (exists)"
else
    warning ".env.example missing"
fi

# Section 11: Database Configuration Analysis
section "Section 11: Database Configuration Analysis"

info "Analyzing database configuration and connectivity..."

# Test database connection if credentials are available
if [ -f ".env" ]; then
    DB_HOST=$(grep "^DB_HOST=" ".env" | cut -d'=' -f2 | tr -d '"')
    DB_DATABASE=$(grep "^DB_DATABASE=" ".env" | cut -d'=' -f2 | tr -d '"')
    DB_USERNAME=$(grep "^DB_USERNAME=" ".env" | cut -d'=' -f2 | tr -d '"')
    DB_PASSWORD=$(grep "^DB_PASSWORD=" ".env" | cut -d'=' -f2 | tr -d '"')

    if [ -n "$DB_HOST" ] && [ -n "$DB_DATABASE" ] && [ -n "$DB_USERNAME" ]; then
        if command -v mysql &>/dev/null; then
            if mysql -h"$DB_HOST" -u"$DB_USERNAME" -p"$DB_PASSWORD" -e "USE $DB_DATABASE;" 2>/dev/null; then
                log "Database connection (successful)"

                # Check for tables
                TABLE_COUNT=$(mysql -h"$DB_HOST" -u"$DB_USERNAME" -p"$DB_PASSWORD" -D"$DB_DATABASE" -e "SHOW TABLES;" 2>/dev/null | wc -l)
                if [ "$TABLE_COUNT" -gt 1 ]; then
                    detail "✓ Database has $((TABLE_COUNT-1)) tables"

                    # Check for specific tables
                    EXPECTED_TABLES=("users" "bmi_records" "currency_conversions" "loan_calculations")
                    for table in "${EXPECTED_TABLES[@]}"; do
                        if mysql -h"$DB_HOST" -u"$DB_USERNAME" -p"$DB_PASSWORD" -D"$DB_DATABASE" -e "DESCRIBE $table;" &>/dev/null; then
                            detail "✓ Table '$table' exists"
                        else
                            warning "Table '$table' missing"
                        fi
                    done
                else
                    warning "Database is empty - migrations may need to be run"
                fi
            else
                error "Database connection failed"
            fi
        else
            warning "MySQL client not available for testing"
        fi
    else
        warning "Database configuration incomplete"
    fi
fi

# Check migration files
if [ -d "database/migrations" ]; then
    MIGRATION_COUNT=$(find database/migrations -name "*.php" | wc -l)
    if [ "$MIGRATION_COUNT" -gt 0 ]; then
        log "Migration files ($MIGRATION_COUNT found)"
        detail "✓ $MIGRATION_COUNT migration files"
    else
        warning "No migration files found"
    fi
else
    warning "database/migrations directory missing"
fi

info "✓ Dependencies and configuration analysis completed"

# Section 12: Functional Module Integration Analysis
section "Section 12: Functional Module Integration Analysis"

info "Analyzing functional module integration and data flow..."

# Check Controller-Service integration
info "Checking Controller-Service integration..."

CONTROLLER_SERVICE_PAIRS=(
    "BmiController:BmiCalculatorService"
    "CurrencyController:CurrencyService"
    "LoanController:LoanCalculatorService"
)

for pair in "${CONTROLLER_SERVICE_PAIRS[@]}"; do
    CONTROLLER=$(echo "$pair" | cut -d':' -f1)
    SERVICE=$(echo "$pair" | cut -d':' -f2)

    CONTROLLER_FILE="app/Http/Controllers/${CONTROLLER}.php"
    SERVICE_FILE="app/Services/${SERVICE}.php"

    if [ -f "$CONTROLLER_FILE" ] && [ -f "$SERVICE_FILE" ]; then
        # Check if controller uses service
        if grep -q "$SERVICE" "$CONTROLLER_FILE"; then
            log "$CONTROLLER ↔ $SERVICE (integrated)"
            detail "✓ Controller uses service class"
        else
            warning "$CONTROLLER does not use $SERVICE"
        fi

        # Check dependency injection
        if grep -q "__construct.*$SERVICE" "$CONTROLLER_FILE"; then
            detail "✓ Proper dependency injection"
        else
            warning "No dependency injection found"
        fi
    fi
done

# Check Model-Controller integration
info "Checking Model-Controller integration..."

MODEL_CONTROLLER_PAIRS=(
    "BmiRecord:BmiController"
    "CurrencyConversion:CurrencyController"
    "LoanCalculation:LoanController"
)

for pair in "${MODEL_CONTROLLER_PAIRS[@]}"; do
    MODEL=$(echo "$pair" | cut -d':' -f1)
    CONTROLLER=$(echo "$pair" | cut -d':' -f2)

    MODEL_FILE="app/Models/${MODEL}.php"
    CONTROLLER_FILE="app/Http/Controllers/${CONTROLLER}.php"

    if [ -f "$MODEL_FILE" ] && [ -f "$CONTROLLER_FILE" ]; then
        if grep -q "$MODEL" "$CONTROLLER_FILE"; then
            log "$MODEL ↔ $CONTROLLER (integrated)"
            detail "✓ Controller uses model"
        else
            warning "$CONTROLLER does not use $MODEL model"
        fi
    fi
done

# Check Route-Controller integration
info "Checking Route-Controller integration..."

ROUTE_FILES=("routes/web.php" "routes/api.php")
CONTROLLERS=("BmiController" "CurrencyController" "LoanController")

for route_file in "${ROUTE_FILES[@]}"; do
    if [ -f "$route_file" ]; then
        for controller in "${CONTROLLERS[@]}"; do
            if grep -q "$controller" "$route_file"; then
                detail "✓ $controller referenced in $(basename "$route_file")"
            else
                warning "$controller not referenced in $(basename "$route_file")"
            fi
        done
    fi
done

# Section 13: API Endpoint Completeness Check
section "Section 13: API Endpoint Completeness Check"

info "Analyzing API endpoint completeness..."

# Expected API endpoints
EXPECTED_ENDPOINTS=(
    "POST:/api/calculate-bmi"
    "POST:/api/convert-currency"
    "POST:/api/calculate-loan"
    "GET:/api/currency-rates"
    "POST:/api/batch-convert-currency"
    "GET:/api/bmi/trends"
)

if [ -f "routes/api.php" ]; then
    for endpoint in "${EXPECTED_ENDPOINTS[@]}"; do
        METHOD=$(echo "$endpoint" | cut -d':' -f1)
        PATH=$(echo "$endpoint" | cut -d':' -f2)
        ROUTE_PATTERN=$(echo "$PATH" | sed 's/\/api\///')

        if grep -q "$ROUTE_PATTERN" "routes/api.php"; then
            log "API endpoint $endpoint (found)"
        else
            warning "API endpoint $endpoint (missing)"
        fi
    done
fi

# Section 14: Security Configuration Analysis
section "Section 14: Security Configuration Analysis"

info "Analyzing security configurations..."

# Check CSRF protection
if [ -f "app/Http/Middleware/VerifyCsrfToken.php" ]; then
    log "CSRF protection middleware (exists)"

    # Check if it's properly configured in Kernel
    if [ -f "app/Http/Kernel.php" ]; then
        if grep -q "VerifyCsrfToken" "app/Http/Kernel.php"; then
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
    if grep -q "throttle" "routes/api.php"; then
        log "API rate limiting (configured)"

        # Check throttle configuration
        THROTTLE_CONFIG=$(grep "throttle" "routes/api.php" | head -1)
        detail "✓ Configuration: $THROTTLE_CONFIG"
    else
        warning "No API rate limiting found"
    fi
fi

# Check for input validation
CONTROLLERS_WITH_VALIDATION=0
for controller in app/Http/Controllers/*.php; do
    if [ -f "$controller" ]; then
        if grep -q "validate\|Validator::" "$controller"; then
            ((CONTROLLERS_WITH_VALIDATION++))
        fi
    fi
done

if [ "$CONTROLLERS_WITH_VALIDATION" -gt 0 ]; then
    log "Input validation ($CONTROLLERS_WITH_VALIDATION controllers have validation)"
else
    warning "No input validation found in controllers"
fi

# Section 15: Performance and Caching Analysis
section "Section 15: Performance and Caching Analysis"

info "Analyzing performance and caching configurations..."

# Check for caching in services
SERVICES_WITH_CACHING=0
for service in app/Services/*.php; do
    if [ -f "$service" ]; then
        if grep -q "Cache::\|cache(" "$service"; then
            ((SERVICES_WITH_CACHING++))
            detail "✓ $(basename "$service") uses caching"
        fi
    fi
done

if [ "$SERVICES_WITH_CACHING" -gt 0 ]; then
    log "Service caching ($SERVICES_WITH_CACHING services use caching)"
else
    warning "No caching found in services"
fi

# Check Laravel optimization files
OPTIMIZATION_FILES=(
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
    detail "✓ $OPTIMIZED_COUNT cached files"
else
    warning "No Laravel optimization files found - run artisan optimize"
fi

# Section 16: Error Handling Analysis
section "Section 16: Error Handling Analysis"

info "Analyzing error handling implementation..."

# Check exception handler
if [ -f "app/Exceptions/Handler.php" ]; then
    log "Exception handler (exists)"

    if grep -q "function register\|function report" "app/Exceptions/Handler.php"; then
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
        if grep -q "try\s*{.*catch" "$controller"; then
            ((CONTROLLERS_WITH_ERROR_HANDLING++))
        fi
    fi
done

if [ "$CONTROLLERS_WITH_ERROR_HANDLING" -gt 0 ]; then
    log "Controller error handling ($CONTROLLERS_WITH_ERROR_HANDLING controllers have try-catch)"
else
    warning "No try-catch blocks found in controllers"
fi

# Check logging configuration
if [ -f "config/logging.php" ]; then
    log "Logging configuration (exists)"
else
    warning "Logging configuration missing"
fi

# Check log directory
if [ -d "storage/logs" ]; then
    log "Log directory (exists)"

    LOG_FILES=$(find storage/logs -name "*.log" | wc -l)
    if [ "$LOG_FILES" -gt 0 ]; then
        detail "✓ $LOG_FILES log files found"
    else
        detail "No log files yet"
    fi
else
    error "Log directory missing"
fi

info "✓ Functional integration analysis completed"

# Section 17: File Integrity and Completeness Score
section "Section 17: File Integrity and Completeness Score"

info "Calculating overall completeness score..."

# Calculate scores
TOTAL_POSSIBLE_SCORE=100
CURRENT_SCORE=0

# Core files score (25 points)
CORE_FILES_SCORE=0
CORE_FILES_TOTAL=17
CORE_FILES_FOUND=0

for file in "${LARAVEL_CORE_FILES[@]}"; do
    if [ -f "$file" ]; then
        ((CORE_FILES_FOUND++))
    fi
done

CORE_FILES_SCORE=$((CORE_FILES_FOUND * 25 / CORE_FILES_TOTAL))
CURRENT_SCORE=$((CURRENT_SCORE + CORE_FILES_SCORE))

# Application files score (30 points)
APP_FILES_SCORE=0
APP_FILES_TOTAL=9  # 3 controllers + 3 services + 3 models
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

for model in "${MODELS[@]}"; do
    if [ -f "$model" ]; then
        ((APP_FILES_FOUND++))
    fi
done

APP_FILES_SCORE=$((APP_FILES_FOUND * 30 / APP_FILES_TOTAL))
CURRENT_SCORE=$((CURRENT_SCORE + APP_FILES_SCORE))

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

# Configuration score (15 points)
CONFIG_SCORE=0
if [ -f ".env" ]; then
    CONFIG_SCORE=$((CONFIG_SCORE + 5))
fi
if grep -q "^APP_KEY=base64:" ".env" 2>/dev/null; then
    CONFIG_SCORE=$((CONFIG_SCORE + 5))
fi
if [ -f "config/app.php" ] && [ -f "config/database.php" ]; then
    CONFIG_SCORE=$((CONFIG_SCORE + 5))
fi

CURRENT_SCORE=$((CURRENT_SCORE + CONFIG_SCORE))

# Integration score (10 points)
INTEGRATION_SCORE=0
if [ "$CONTROLLERS_WITH_ERROR_HANDLING" -gt 0 ]; then
    INTEGRATION_SCORE=$((INTEGRATION_SCORE + 3))
fi
if [ "$SERVICES_WITH_CACHING" -gt 0 ]; then
    INTEGRATION_SCORE=$((INTEGRATION_SCORE + 3))
fi
if [ "$CONTROLLERS_WITH_VALIDATION" -gt 0 ]; then
    INTEGRATION_SCORE=$((INTEGRATION_SCORE + 4))
fi

CURRENT_SCORE=$((CURRENT_SCORE + INTEGRATION_SCORE))

# Generate detailed report
REPORT_FILE="/tmp/besthammer_source_diagnostic_report_${TIMESTAMP}.txt"

cat > "$REPORT_FILE" << EOF
BestHammer NTool Platform - Comprehensive Source Diagnostic Report
================================================================
Generated: $(date)
Web Root: $WEB_ROOT
Web User: $WEB_USER

OVERALL COMPLETENESS SCORE: ${CURRENT_SCORE}/100
============================================

Score Breakdown:
- Core Laravel Files: ${CORE_FILES_SCORE}/25 (${CORE_FILES_FOUND}/${CORE_FILES_TOTAL} files)
- Application Files: ${APP_FILES_SCORE}/30 (${APP_FILES_FOUND}/${APP_FILES_TOTAL} files)
- Dependencies: ${DEPS_SCORE}/20
- Configuration: ${CONFIG_SCORE}/15
- Integration: ${INTEGRATION_SCORE}/10

DETAILED ANALYSIS SUMMARY:
=========================

Total Checks Performed: $TOTAL_CHECKS
✅ Passed: $PASSED_CHECKS
⚠️  Warnings: $WARNING_CHECKS
❌ Failed: $FAILED_CHECKS

Success Rate: $(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))%

CRITICAL ISSUES FOUND:
=====================
EOF

# Add critical issues to report
if [ "$FAILED_CHECKS" -gt 0 ]; then
    echo "The following critical issues were found:" >> "$REPORT_FILE"
    echo >> "$REPORT_FILE"

    # Check for missing core files
    for file in "${LARAVEL_CORE_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            echo "❌ Missing core file: $file" >> "$REPORT_FILE"
        fi
    done

    # Check for missing application files
    for controller in "${CONTROLLERS[@]}"; do
        if [ ! -f "$controller" ]; then
            echo "❌ Missing controller: $controller" >> "$REPORT_FILE"
        fi
    done

    for service in "${SERVICES[@]}"; do
        if [ ! -f "$service" ]; then
            echo "❌ Missing service: $service" >> "$REPORT_FILE"
        fi
    done

else
    echo "No critical issues found!" >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" << EOF

RECOMMENDATIONS:
===============
EOF

# Generate recommendations based on score
if [ "$CURRENT_SCORE" -ge 90 ]; then
    cat >> "$REPORT_FILE" << EOF
🎉 EXCELLENT: Your application is nearly complete and well-structured.
- Minor optimizations may be needed
- Consider running performance tests
- Ensure all features are thoroughly tested
EOF
elif [ "$CURRENT_SCORE" -ge 75 ]; then
    cat >> "$REPORT_FILE" << EOF
✅ GOOD: Your application is mostly complete with some areas for improvement.
- Address any missing files or configurations
- Implement missing error handling or validation
- Optimize caching and performance
EOF
elif [ "$CURRENT_SCORE" -ge 50 ]; then
    cat >> "$REPORT_FILE" << EOF
⚠️ NEEDS WORK: Your application has significant gaps that need attention.
- Install missing dependencies: composer install
- Create missing application files
- Configure environment variables properly
- Implement proper error handling and validation
EOF
else
    cat >> "$REPORT_FILE" << EOF
❌ CRITICAL: Your application is incomplete and needs major work.
- Many core files are missing
- Dependencies are not installed
- Configuration is incomplete
- Consider running the Laravel compatibility fix script
EOF
fi

cat >> "$REPORT_FILE" << EOF

NEXT STEPS:
==========
1. Address all critical issues (❌) first
2. Review and fix warnings (⚠️)
3. Run composer install if dependencies are missing
4. Configure .env file properly
5. Run Laravel optimization commands:
   - php artisan config:cache
   - php artisan route:cache
   - php artisan view:cache
6. Test all functionality thoroughly

DETAILED LOG:
============
For detailed analysis, review the console output above.

Report generated at: $(date)
================================================================
EOF

# Section 18: Final Summary and Recommendations
section "Section 18: Final Summary and Recommendations"

echo
echo "🎯 COMPREHENSIVE DIAGNOSTIC SUMMARY"
echo "==================================="
echo
echo "📊 OVERALL COMPLETENESS SCORE: ${CURRENT_SCORE}/100"
echo

# Color-coded score display
if [ "$CURRENT_SCORE" -ge 90 ]; then
    echo -e "${GREEN}🎉 EXCELLENT (90-100): Application is nearly complete${NC}"
elif [ "$CURRENT_SCORE" -ge 75 ]; then
    echo -e "${GREEN}✅ GOOD (75-89): Application is mostly complete${NC}"
elif [ "$CURRENT_SCORE" -ge 50 ]; then
    echo -e "${YELLOW}⚠️ NEEDS WORK (50-74): Significant gaps need attention${NC}"
else
    echo -e "${RED}❌ CRITICAL (0-49): Major work required${NC}"
fi

echo
echo "📈 ANALYSIS STATISTICS:"
echo "======================"
echo "Total Checks: $TOTAL_CHECKS"
echo "✅ Passed: $PASSED_CHECKS ($(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))%)"
echo "⚠️ Warnings: $WARNING_CHECKS ($(( (WARNING_CHECKS * 100) / TOTAL_CHECKS ))%)"
echo "❌ Failed: $FAILED_CHECKS ($(( (FAILED_CHECKS * 100) / TOTAL_CHECKS ))%)"

echo
echo "🔧 IMMEDIATE ACTIONS REQUIRED:"
echo "=============================="

if [ "$FAILED_CHECKS" -gt 10 ]; then
    echo "❌ HIGH PRIORITY: $FAILED_CHECKS critical issues found"
    echo "   → Run Laravel compatibility fix script"
    echo "   → Install missing dependencies"
    echo "   → Create missing core files"
elif [ "$FAILED_CHECKS" -gt 5 ]; then
    echo "⚠️ MEDIUM PRIORITY: $FAILED_CHECKS issues found"
    echo "   → Address missing files"
    echo "   → Fix configuration issues"
elif [ "$FAILED_CHECKS" -gt 0 ]; then
    echo "ℹ️ LOW PRIORITY: $FAILED_CHECKS minor issues found"
    echo "   → Review and fix remaining issues"
else
    echo "🎉 NO CRITICAL ISSUES: Application structure is complete"
    echo "   → Focus on testing and optimization"
fi

echo
echo "📄 DETAILED REPORT: $REPORT_FILE"
echo "📋 To view full report: cat $REPORT_FILE"
echo
echo "🔧 RECOMMENDED NEXT STEPS:"
echo "========================="

if [ "$CURRENT_SCORE" -lt 75 ]; then
    echo "1. Run: sudo ./fix-laravel-compatibility-safe.sh"
    echo "2. Install dependencies: composer install"
    echo "3. Configure environment: cp .env.example .env && php artisan key:generate"
    echo "4. Re-run this diagnostic script"
else
    echo "1. Address any remaining warnings"
    echo "2. Test all calculator functions"
    echo "3. Run performance optimization"
    echo "4. Deploy to production"
fi

echo
echo "================================================================"
echo "Comprehensive source diagnostic completed at $(date)"
echo "================================================================"
