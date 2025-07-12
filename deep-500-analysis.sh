#!/bin/bash

# Deep HTTP 500 Error Analysis Script
# This script performs comprehensive testing to find intermittent or specific 500 errors

set -e

# Configuration
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ANALYSIS_LOG="/tmp/deep_500_analysis_${TIMESTAMP}.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() { echo -e "${GREEN}✅ $1${NC}" | tee -a "$ANALYSIS_LOG"; }
warning() { echo -e "${YELLOW}⚠️ $1${NC}" | tee -a "$ANALYSIS_LOG"; }
error() { echo -e "${RED}❌ $1${NC}" | tee -a "$ANALYSIS_LOG"; }
info() { echo -e "${BLUE}ℹ️ $1${NC}" | tee -a "$ANALYSIS_LOG"; }
section() { echo -e "${PURPLE}🔍 $1${NC}" | tee -a "$ANALYSIS_LOG"; }

# Initialize log
echo "# Deep HTTP 500 Error Analysis" > "$ANALYSIS_LOG"
echo "Started: $(date)" >> "$ANALYSIS_LOG"
echo "Target: $WEB_ROOT" >> "$ANALYSIS_LOG"
echo "=========================================" >> "$ANALYSIS_LOG"

# Check root
if [[ $EUID -ne 0 ]]; then
    error "Run as root: sudo ./deep-500-analysis.sh"
    exit 1
fi

echo "🔍 Deep HTTP 500 Error Analysis"
echo "==============================="
echo "Target: $WEB_ROOT"
echo "Log: $ANALYSIS_LOG"
echo "Time: $(date)"
echo "==============================="
echo ""

cd "$WEB_ROOT" 2>/dev/null || {
    error "Cannot access web root: $WEB_ROOT"
    exit 1
}

# Function to test URL with detailed response
test_url_detailed() {
    local url="$1"
    local description="$2"
    
    echo "Testing: $description ($url)" >> "$ANALYSIS_LOG"
    
    # Get detailed response
    local response=$(curl -s -w "HTTPCODE:%{http_code}\nTIME:%{time_total}\nSIZE:%{size_download}" "$url" 2>&1)
    local http_code=$(echo "$response" | grep "HTTPCODE:" | cut -d':' -f2)
    local time_total=$(echo "$response" | grep "TIME:" | cut -d':' -f2)
    local size=$(echo "$response" | grep "SIZE:" | cut -d':' -f2)
    
    echo "  HTTP Code: $http_code" >> "$ANALYSIS_LOG"
    echo "  Time: ${time_total}s" >> "$ANALYSIS_LOG"
    echo "  Size: ${size} bytes" >> "$ANALYSIS_LOG"
    
    # Get response body for error analysis
    local body=$(curl -s "$url" 2>/dev/null | head -20)
    if [ -n "$body" ]; then
        echo "  Response preview:" >> "$ANALYSIS_LOG"
        echo "$body" | sed 's/^/    /' >> "$ANALYSIS_LOG"
    fi
    echo "" >> "$ANALYSIS_LOG"
    
    if [ "$http_code" = "500" ]; then
        error "$description: HTTP 500 ❌"
        return 1
    elif [[ "$http_code" =~ ^[23] ]]; then
        log "$description: HTTP $http_code ✅"
        return 0
    else
        warning "$description: HTTP $http_code ⚠️"
        return 2
    fi
}

# Section 1: Comprehensive URL Testing
section "Section 1: Comprehensive URL Testing"

info "Testing all possible access methods and pages..."

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null)
DOMAIN=$(hostname -f 2>/dev/null)

# Test URLs
TEST_URLS=(
    "http://localhost|Local Host"
    "http://127.0.0.1|Local IP"
)

if [ -n "$SERVER_IP" ]; then
    TEST_URLS+=("http://$SERVER_IP|Server IP")
fi

if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "localhost" ]; then
    TEST_URLS+=("http://$DOMAIN|Domain Name")
fi

# Test main pages
PAGES=("" "bmi-calculator" "currency-converter" "loan-calculator" "api/calculate-bmi")

ERROR_COUNT=0
SUCCESS_COUNT=0

for url_info in "${TEST_URLS[@]}"; do
    base_url=$(echo "$url_info" | cut -d'|' -f1)
    description=$(echo "$url_info" | cut -d'|' -f2)
    
    for page in "${PAGES[@]}"; do
        if [ -z "$page" ]; then
            full_url="$base_url"
            page_desc="Home Page"
        else
            full_url="$base_url/$page"
            page_desc="$page"
        fi
        
        if test_url_detailed "$full_url" "$description - $page_desc"; then
            ((SUCCESS_COUNT++))
        else
            ((ERROR_COUNT++))
        fi
    done
done

echo ""
info "URL Testing Summary: $SUCCESS_COUNT success, $ERROR_COUNT errors"

# Section 2: Real-time Error Log Monitoring
section "Section 2: Real-time Error Log Monitoring"

info "Monitoring error logs during live testing..."

# Start log monitoring in background
LOG_MONITOR_PID=""
if [ -f "storage/logs/laravel.log" ]; then
    tail -f "storage/logs/laravel.log" > "/tmp/laravel_monitor_${TIMESTAMP}.log" &
    LOG_MONITOR_PID=$!
    info "Started Laravel log monitoring (PID: $LOG_MONITOR_PID)"
fi

# Perform stress testing
info "Performing stress testing to trigger errors..."

# Test with multiple concurrent requests
for i in {1..10}; do
    curl -s "http://localhost" > /dev/null &
    curl -s "http://localhost/bmi-calculator" > /dev/null &
    curl -s "http://localhost/currency-converter" > /dev/null &
done

wait
sleep 2

# Stop log monitoring
if [ -n "$LOG_MONITOR_PID" ]; then
    kill $LOG_MONITOR_PID 2>/dev/null || true
    
    # Check for new errors
    if [ -f "/tmp/laravel_monitor_${TIMESTAMP}.log" ]; then
        NEW_ERRORS=$(wc -l < "/tmp/laravel_monitor_${TIMESTAMP}.log")
        if [ "$NEW_ERRORS" -gt 0 ]; then
            error "Found $NEW_ERRORS new log entries during testing"
            echo "=== NEW LOG ENTRIES ===" >> "$ANALYSIS_LOG"
            cat "/tmp/laravel_monitor_${TIMESTAMP}.log" >> "$ANALYSIS_LOG"
        else
            log "No new errors in Laravel log during testing"
        fi
        rm -f "/tmp/laravel_monitor_${TIMESTAMP}.log"
    fi
fi

# Section 3: API Endpoint Testing
section "Section 3: API Endpoint Testing"

info "Testing API endpoints with actual data..."

# Test BMI API
BMI_RESPONSE=$(curl -s -w "HTTPCODE:%{http_code}" -X POST "http://localhost/api/calculate-bmi" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "height_cm=175&weight_kg=70&age=30&gender=male&activity_level=moderately_active" 2>/dev/null)

BMI_CODE=$(echo "$BMI_RESPONSE" | grep "HTTPCODE:" | cut -d':' -f2)
if [ "$BMI_CODE" = "500" ]; then
    error "BMI API: HTTP 500 ❌"
    echo "BMI API Error Response:" >> "$ANALYSIS_LOG"
    echo "$BMI_RESPONSE" >> "$ANALYSIS_LOG"
elif [[ "$BMI_CODE" =~ ^[23] ]]; then
    log "BMI API: HTTP $BMI_CODE ✅"
else
    warning "BMI API: HTTP $BMI_CODE ⚠️"
fi

# Test Currency API
CURRENCY_RESPONSE=$(curl -s -w "HTTPCODE:%{http_code}" -X POST "http://localhost/api/convert-currency" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "amount=100&from=USD&to=EUR" 2>/dev/null)

CURRENCY_CODE=$(echo "$CURRENCY_RESPONSE" | grep "HTTPCODE:" | cut -d':' -f2)
if [ "$CURRENCY_CODE" = "500" ]; then
    error "Currency API: HTTP 500 ❌"
    echo "Currency API Error Response:" >> "$ANALYSIS_LOG"
    echo "$CURRENCY_RESPONSE" >> "$ANALYSIS_LOG"
elif [[ "$CURRENCY_CODE" =~ ^[23] ]]; then
    log "Currency API: HTTP $CURRENCY_CODE ✅"
else
    warning "Currency API: HTTP $CURRENCY_CODE ⚠️"
fi

# Section 4: Laravel Internal Testing
section "Section 4: Laravel Internal Testing"

info "Testing Laravel internal components..."

if [ -f "vendor/autoload.php" ] && [ -f "artisan" ]; then
    # Test Artisan commands
    info "Testing Artisan commands..."
    
    ARTISAN_TESTS=(
        "route:list|Route List"
        "config:show app|Config Show"
        "tinker --execute='echo \"Laravel OK\";'|Tinker Test"
    )
    
    for test_info in "${ARTISAN_TESTS[@]}"; do
        command=$(echo "$test_info" | cut -d'|' -f1)
        description=$(echo "$test_info" | cut -d'|' -f2)
        
        if php artisan $command &>/dev/null; then
            log "$description: Working ✅"
        else
            error "$description: Failed ❌"
            echo "Artisan Error for '$command':" >> "$ANALYSIS_LOG"
            php artisan $command 2>&1 >> "$ANALYSIS_LOG"
        fi
    done
else
    warning "Cannot test Laravel - missing vendor or artisan"
fi

# Section 5: Server Configuration Analysis
section "Section 5: Server Configuration Analysis"

info "Analyzing server configuration..."

# Check PHP-FPM configuration
PHP_FPM_CONF=$(find /etc/php*/fpm/pool.d/ -name "*.conf" 2>/dev/null | head -1)
if [ -n "$PHP_FPM_CONF" ]; then
    info "PHP-FPM Config: $PHP_FPM_CONF"
    
    # Check important settings
    if grep -q "pm.max_children" "$PHP_FPM_CONF"; then
        MAX_CHILDREN=$(grep "pm.max_children" "$PHP_FPM_CONF" | awk '{print $3}')
        info "Max Children: $MAX_CHILDREN"
    fi
    
    if grep -q "request_terminate_timeout" "$PHP_FPM_CONF"; then
        TIMEOUT=$(grep "request_terminate_timeout" "$PHP_FPM_CONF" | awk '{print $3}')
        info "Request Timeout: $TIMEOUT"
    fi
fi

# Check Nginx configuration
NGINX_CONF="/etc/nginx/sites-available/default"
if [ -f "$NGINX_CONF" ]; then
    info "Nginx Config: $NGINX_CONF"
    
    # Check for common issues
    if grep -q "fastcgi_pass" "$NGINX_CONF"; then
        FASTCGI_PASS=$(grep "fastcgi_pass" "$NGINX_CONF" | head -1 | awk '{print $2}' | sed 's/;//')
        info "FastCGI Pass: $FASTCGI_PASS"
    fi
fi

# Section 6: Resource Usage Analysis
section "Section 6: Resource Usage Analysis"

info "Checking system resources..."

# Memory usage
MEMORY_INFO=$(free -h | awk '/^Mem:/ {printf "Total: %s, Used: %s, Free: %s", $2, $3, $4}')
info "Memory: $MEMORY_INFO"

# Disk usage
DISK_INFO=$(df -h "$WEB_ROOT" | awk 'NR==2 {printf "Used: %s, Available: %s, Usage: %s", $3, $4, $5}')
info "Disk: $DISK_INFO"

# PHP Memory limit
PHP_MEMORY=$(php -r "echo ini_get('memory_limit');")
info "PHP Memory Limit: $PHP_MEMORY"

# Check for recent PHP errors
if [ -f "/var/log/php*-fpm.log" ]; then
    RECENT_PHP_ERRORS=$(find /var/log -name "php*-fpm.log" -exec tail -20 {} \; | grep -c "ERROR\|FATAL" 2>/dev/null || echo "0")
    if [ "$RECENT_PHP_ERRORS" -gt 0 ]; then
        error "Found $RECENT_PHP_ERRORS recent PHP-FPM errors"
    else
        log "No recent PHP-FPM errors"
    fi
fi

# Section 7: External Access Testing
section "Section 7: External Access Testing"

info "Testing external access patterns..."

# Test with different User-Agents
USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36|Browser"
    "curl/7.68.0|Curl"
    "BestHammer-Monitor/1.0|Custom"
)

for ua_info in "${USER_AGENTS[@]}"; do
    user_agent=$(echo "$ua_info" | cut -d'|' -f1)
    description=$(echo "$ua_info" | cut -d'|' -f2)

    RESPONSE=$(curl -s -w "HTTPCODE:%{http_code}" -H "User-Agent: $user_agent" "http://localhost" 2>/dev/null)
    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTPCODE:" | cut -d':' -f2)

    if [ "$HTTP_CODE" = "500" ]; then
        error "User-Agent $description: HTTP 500 ❌"
    elif [[ "$HTTP_CODE" =~ ^[23] ]]; then
        log "User-Agent $description: HTTP $HTTP_CODE ✅"
    else
        warning "User-Agent $description: HTTP $HTTP_CODE ⚠️"
    fi
done

# Section 8: Database Connection Testing
section "Section 8: Database Connection Testing"

if [ -f ".env" ] && grep -q "DB_DATABASE=" ".env"; then
    info "Testing database connectivity..."

    DB_TEST_RESULT=$(php -r "
        try {
            require_once 'vendor/autoload.php';
            \$app = require_once 'bootstrap/app.php';
            \$pdo = DB::connection()->getPdo();
            echo 'DB_CONNECTION_OK';
        } catch (Exception \$e) {
            echo 'DB_ERROR: ' . \$e->getMessage();
        }
    " 2>&1)

    if echo "$DB_TEST_RESULT" | grep -q "DB_CONNECTION_OK"; then
        log "Database connection: Working ✅"
    else
        error "Database connection: Failed ❌"
        echo "Database Error: $DB_TEST_RESULT" >> "$ANALYSIS_LOG"
    fi
else
    warning "Database not configured - skipping DB tests"
fi

# Section 9: Analysis Summary and Recommendations
section "Section 9: Analysis Summary and Recommendations"

echo "" >> "$ANALYSIS_LOG"
echo "=========================================" >> "$ANALYSIS_LOG"
echo "ANALYSIS SUMMARY" >> "$ANALYSIS_LOG"
echo "=========================================" >> "$ANALYSIS_LOG"
echo "Total URL Tests: $((SUCCESS_COUNT + ERROR_COUNT))" >> "$ANALYSIS_LOG"
echo "Successful: $SUCCESS_COUNT" >> "$ANALYSIS_LOG"
echo "Errors: $ERROR_COUNT" >> "$ANALYSIS_LOG"
echo "" >> "$ANALYSIS_LOG"

# Generate recommendations
echo "RECOMMENDATIONS:" >> "$ANALYSIS_LOG"
echo "=================" >> "$ANALYSIS_LOG"

if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "❌ HTTP 500 errors detected in $ERROR_COUNT tests" >> "$ANALYSIS_LOG"
    echo "• Check Laravel error logs: tail -f $WEB_ROOT/storage/logs/laravel.log" >> "$ANALYSIS_LOG"
    echo "• Review specific failing endpoints" >> "$ANALYSIS_LOG"
    echo "• Check database connectivity if DB errors found" >> "$ANALYSIS_LOG"
elif [ "$SUCCESS_COUNT" -gt 0 ] && [ "$ERROR_COUNT" -eq 0 ]; then
    echo "✅ No HTTP 500 errors found in comprehensive testing" >> "$ANALYSIS_LOG"
    echo "• The 500 error may be intermittent or external" >> "$ANALYSIS_LOG"
    echo "• Consider monitoring logs for future occurrences" >> "$ANALYSIS_LOG"
    echo "• Check browser cache or DNS issues if still experiencing problems" >> "$ANALYSIS_LOG"
else
    echo "⚠️ Unable to complete comprehensive testing" >> "$ANALYSIS_LOG"
    echo "• Check basic connectivity and server status" >> "$ANALYSIS_LOG"
fi

echo "" >> "$ANALYSIS_LOG"
echo "Analysis completed: $(date)" >> "$ANALYSIS_LOG"

# Display final summary
echo ""
echo "=================================================="
echo "🎯 DEEP ANALYSIS RESULTS"
echo "=================================================="
echo "📊 URL Tests: $SUCCESS_COUNT success, $ERROR_COUNT errors"

if [ "$ERROR_COUNT" -gt 0 ]; then
    error "🚨 HTTP 500 errors found in $ERROR_COUNT tests"
    echo ""
    echo "🔍 500 Error Sources Identified:"
    echo "• Check the detailed log for specific failing URLs"
    echo "• Review Laravel error logs for root causes"
    echo "• API endpoints may have specific issues"
    echo ""
    echo "🔧 Immediate Actions:"
    echo "1. Review Laravel logs: tail -f $WEB_ROOT/storage/logs/laravel.log"
    echo "2. Check failing endpoints identified in the analysis"
    echo "3. Verify database connectivity if DB errors found"
    echo "4. Monitor PHP-FPM logs: tail -f /var/log/php*-fpm.log"

elif [ "$SUCCESS_COUNT" -gt 0 ]; then
    log "✅ No HTTP 500 errors detected in comprehensive testing"
    echo ""
    echo "🤔 Possible Explanations for Original 500 Error:"
    echo "• Intermittent error that has been resolved"
    echo "• External access issue (DNS, firewall, CDN)"
    echo "• Browser caching showing old error"
    echo "• Specific user session or cookie issue"
    echo ""
    echo "💡 Recommendations:"
    echo "1. Clear browser cache and try again"
    echo "2. Test from different devices/networks"
    echo "3. Monitor logs for future occurrences"
    echo "4. Set up log monitoring for early detection"

else
    warning "⚠️ Unable to complete comprehensive analysis"
    echo ""
    echo "🔍 Basic connectivity issues detected"
    echo "• Web server may not be responding properly"
    echo "• Check service status and configuration"
fi

echo ""
echo "📄 Detailed Analysis: $ANALYSIS_LOG"
echo "📁 Web Root: $WEB_ROOT"
echo ""

# Provide specific next steps
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "🚨 CRITICAL: HTTP 500 errors confirmed"
    echo "Run this to monitor live errors:"
    echo "tail -f $WEB_ROOT/storage/logs/laravel.log"
elif [ "$SUCCESS_COUNT" -gt 0 ]; then
    echo "✅ GOOD NEWS: No current 500 errors detected"
    echo "Your website appears to be working correctly now."
else
    echo "🔧 NEEDS ATTENTION: Basic connectivity issues"
    echo "Check web server status and configuration."
fi

echo ""
echo "=================================================="
