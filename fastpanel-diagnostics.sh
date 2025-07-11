#!/bin/bash

# FastPanel Environment Diagnostics for BestHammer NTool Platform
# Comprehensive system check for deployment readiness

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Status indicators
PASS="✅"
FAIL="❌"
WARN="⚠️"
INFO="ℹ️"

log() { echo -e "${GREEN}[PASS] $1${NC}"; }
warning() { echo -e "${YELLOW}[WARN] $1${NC}"; }
error() { echo -e "${RED}[FAIL] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }
header() { echo -e "${PURPLE}[DIAG] $1${NC}"; }

# Global counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Check function wrapper
check() {
    local description="$1"
    local command="$2"
    local critical="$3"  # true/false
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if eval "$command" &>/dev/null; then
        log "$PASS $description"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        if [ "$critical" = "true" ]; then
            error "$FAIL $description (CRITICAL)"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        else
            warning "$WARN $description"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
        fi
        return 1
    fi
}

# Configuration
DOMAIN="besthammer.club"
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"

# Banner
echo
echo "🔨 BestHammer NTool Platform - FastPanel Environment Diagnostics"
echo "================================================================"
echo "Target Domain: $DOMAIN"
echo "Web Root: $WEB_ROOT"
echo "Web User: $WEB_USER"
echo "Scan Time: $(date)"
echo "================================================================"
echo

# 1. System Information
header "📊 System Information"
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Uptime: $(uptime -p)"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo

# 2. FastPanel Detection
header "🎛️ FastPanel Environment Check"
check "FastPanel installation detected" "[ -d '/usr/local/fastpanel' ] || [ -f '/etc/nginx/fastpanel.conf' ]" true
check "FastPanel service running" "systemctl is-active --quiet fastpanel" false
check "FastPanel web interface accessible" "curl -s -o /dev/null -w '%{http_code}' http://localhost:8888 | grep -q '200\|302\|401'" false

# Check FastPanel version
if [ -f "/usr/local/fastpanel/version" ]; then
    local fp_version=$(cat /usr/local/fastpanel/version)
    info "$INFO FastPanel version: $fp_version"
else
    warning "$WARN FastPanel version not detected"
fi

echo

# 3. Web Server Check
header "🌐 Web Server Environment"
check "Nginx installed" "command -v nginx" true
check "Nginx service running" "systemctl is-active --quiet nginx" true
check "Nginx configuration valid" "nginx -t" true

# Check Nginx version
if command -v nginx &>/dev/null; then
    local nginx_version=$(nginx -v 2>&1 | cut -d'/' -f2)
    info "$INFO Nginx version: $nginx_version"
fi

# Check if domain is configured
check "Domain directory exists" "[ -d '/var/www/besthammer_c_usr' ]" true
check "Web root directory exists" "[ -d '$WEB_ROOT' ] || mkdir -p '$WEB_ROOT'" false
check "Web user exists" "id '$WEB_USER'" true

# Check web user permissions
if id "$WEB_USER" &>/dev/null; then
    local user_groups=$(groups "$WEB_USER" | cut -d':' -f2)
    info "$INFO Web user groups:$user_groups"
fi

echo

# 4. PHP Environment
header "🐘 PHP Environment"
check "PHP installed" "command -v php" true

if command -v php &>/dev/null; then
    local php_version=$(php -r "echo PHP_VERSION;")
    local php_major=$(echo $php_version | cut -d'.' -f1)
    local php_minor=$(echo $php_version | cut -d'.' -f2)
    
    info "$INFO PHP version: $php_version"
    
    # Check PHP version compatibility
    if [ "$php_major" -ge 8 ] && [ "$php_minor" -ge 1 ]; then
        log "$PASS PHP version is compatible (8.1+)"
    else
        error "$FAIL PHP version too old (requires 8.1+)"
    fi
    
    # Check PHP extensions
    local required_extensions=("pdo" "mysql" "mbstring" "xml" "curl" "zip" "gd" "intl" "bcmath" "ctype" "fileinfo" "tokenizer" "json" "openssl")
    
    for ext in "${required_extensions[@]}"; do
        check "PHP extension: $ext" "php -m | grep -q '^$ext$'" true
    done
    
    # Check PHP configuration
    local memory_limit=$(php -r "echo ini_get('memory_limit');")
    local max_execution_time=$(php -r "echo ini_get('max_execution_time');")
    local upload_max_filesize=$(php -r "echo ini_get('upload_max_filesize');")
    
    info "$INFO PHP memory_limit: $memory_limit"
    info "$INFO PHP max_execution_time: $max_execution_time"
    info "$INFO PHP upload_max_filesize: $upload_max_filesize"
    
    # Check if memory limit is sufficient
    local memory_mb=$(echo $memory_limit | sed 's/M//')
    if [ "$memory_mb" -ge 256 ]; then
        log "$PASS PHP memory limit is sufficient"
    else
        warning "$WARN PHP memory limit may be too low (recommended: 256M+)"
    fi
fi

# Check PHP-FPM
check "PHP-FPM service running" "systemctl is-active --quiet php*-fpm" true

echo

# 5. Database Environment
header "🗄️ Database Environment"
check "MySQL server installed" "command -v mysql" true
check "MySQL service running" "systemctl is-active --quiet mysql" true

if command -v mysql &>/dev/null; then
    # Try to get MySQL version
    if systemctl is-active --quiet mysql; then
        local mysql_version=$(mysql --version | awk '{print $5}' | cut -d',' -f1)
        info "$INFO MySQL version: $mysql_version"
        
        # Check if we can connect (without password)
        if mysql -e "SELECT 1;" &>/dev/null; then
            log "$PASS MySQL connection available (no password)"
        else
            info "$INFO MySQL requires authentication (normal)"
        fi
        
        # Check MySQL configuration
        local mysql_config="/etc/mysql/mysql.conf.d/mysqld.cnf"
        if [ -f "$mysql_config" ]; then
            info "$INFO MySQL config file: $mysql_config"
        fi
    else
        error "$FAIL MySQL service not running"
    fi
fi

echo

# 6. Node.js and NPM Environment
header "📦 Node.js Environment"
check "Node.js installed" "command -v node" true
check "NPM installed" "command -v npm" true

if command -v node &>/dev/null; then
    local node_version=$(node --version)
    local npm_version=$(npm --version)
    
    info "$INFO Node.js version: $node_version"
    info "$INFO NPM version: $npm_version"
    
    # Check Node.js version compatibility
    local node_major=$(echo $node_version | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$node_major" -ge 16 ]; then
        log "$PASS Node.js version is compatible (16+)"
    else
        warning "$WARN Node.js version may be too old (recommended: 16+)"
    fi
fi

echo

# 7. Composer Environment
header "🎼 Composer Environment"
check "Composer installed" "command -v composer" true

if command -v composer &>/dev/null; then
    local composer_version=$(composer --version | awk '{print $3}')
    info "$INFO Composer version: $composer_version"
    
    # Check if composer is up to date
    if composer self-update --dry-run 2>&1 | grep -q "You are already using the latest version"; then
        log "$PASS Composer is up to date"
    else
        warning "$WARN Composer update available"
    fi
fi

echo

# 8. Redis Environment (Optional)
header "🔴 Redis Environment (Optional)"
check "Redis server installed" "command -v redis-server" false
check "Redis service running" "systemctl is-active --quiet redis" false

if command -v redis-server &>/dev/null; then
    local redis_version=$(redis-server --version | awk '{print $3}' | cut -d'=' -f2)
    info "$INFO Redis version: $redis_version"
    
    # Test Redis connection
    if redis-cli ping &>/dev/null; then
        log "$PASS Redis connection successful"
    else
        warning "$WARN Redis connection failed"
    fi
fi

echo

# 9. SSL/TLS Environment
header "🔒 SSL/TLS Environment"
check "OpenSSL installed" "command -v openssl" true

if command -v openssl &>/dev/null; then
    local openssl_version=$(openssl version | awk '{print $2}')
    info "$INFO OpenSSL version: $openssl_version"
fi

# Check for existing SSL certificates
local ssl_cert_path="/etc/letsencrypt/live/$DOMAIN"
check "Let's Encrypt certificate exists" "[ -f '$ssl_cert_path/fullchain.pem' ]" false

# Check SSL certificate validity
if [ -f "$ssl_cert_path/fullchain.pem" ]; then
    local cert_expiry=$(openssl x509 -enddate -noout -in "$ssl_cert_path/fullchain.pem" | cut -d'=' -f2)
    info "$INFO SSL certificate expires: $cert_expiry"
fi

echo

# 10. System Resources
header "💾 System Resources"

# Memory check
local total_mem=$(free -m | awk 'NR==2{printf "%.0f", $2}')
local available_mem=$(free -m | awk 'NR==2{printf "%.0f", $7}')
local mem_usage=$(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')

info "$INFO Total memory: ${total_mem}MB"
info "$INFO Available memory: ${available_mem}MB"
info "$INFO Memory usage: $mem_usage"

if [ "$total_mem" -ge 1024 ]; then
    log "$PASS Sufficient memory (1GB+)"
else
    warning "$WARN Low memory (recommended: 1GB+)"
fi

# Disk space check
local disk_usage=$(df -h "$WEB_ROOT" 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//')
local disk_available=$(df -h "$WEB_ROOT" 2>/dev/null | awk 'NR==2 {print $4}')

info "$INFO Disk usage: ${disk_usage}%"
info "$INFO Available space: $disk_available"

if [ "$disk_usage" -lt 80 ]; then
    log "$PASS Sufficient disk space"
else
    warning "$WARN High disk usage (${disk_usage}%)"
fi

# CPU check
local cpu_cores=$(nproc)
local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')

info "$INFO CPU cores: $cpu_cores"
info "$INFO Current load: $load_avg"

echo

# 11. Network Connectivity
header "🌐 Network Connectivity"
check "Internet connectivity" "ping -c 1 google.com" true
check "DNS resolution working" "nslookup $DOMAIN" false
check "HTTP port 80 accessible" "netstat -tuln | grep -q ':80 '" true
check "HTTPS port 443 accessible" "netstat -tuln | grep -q ':443 '" true

echo

# 12. Security Environment
header "🛡️ Security Environment"
check "UFW firewall installed" "command -v ufw" false
check "Fail2ban installed" "command -v fail2ban-client" false

# Check firewall status
if command -v ufw &>/dev/null; then
    local ufw_status=$(ufw status | head -1 | awk '{print $2}')
    info "$INFO UFW status: $ufw_status"
fi

# Check for security updates
if command -v apt &>/dev/null; then
    local security_updates=$(apt list --upgradable 2>/dev/null | grep -c security || echo "0")
    if [ "$security_updates" -eq 0 ]; then
        log "$PASS No pending security updates"
    else
        warning "$WARN $security_updates pending security updates"
    fi
fi

echo

# 13. FastPanel Specific Checks
header "🎛️ FastPanel Specific Configuration"

# Check FastPanel database
check "FastPanel database accessible" "mysql -e 'USE fastpanel;'" false

# Check FastPanel user permissions
if id "$WEB_USER" &>/dev/null; then
    check "Web user can access web root" "sudo -u $WEB_USER test -w '$WEB_ROOT'" false
    check "Web user can execute PHP" "sudo -u $WEB_USER php --version" true
fi

# Check FastPanel nginx configuration
local fp_nginx_conf="/etc/nginx/fastpanel.conf"
check "FastPanel nginx config exists" "[ -f '$fp_nginx_conf' ]" false

echo

# 14. Deployment Readiness Summary
header "📋 Deployment Readiness Summary"

echo "Total Checks: $TOTAL_CHECKS"
echo "Passed: $PASSED_CHECKS ($PASS)"
echo "Warnings: $WARNING_CHECKS ($WARN)"
echo "Failed: $FAILED_CHECKS ($FAIL)"
echo

# Calculate readiness score
local readiness_score=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))

if [ "$readiness_score" -ge 90 ]; then
    log "🎉 EXCELLENT: System is ready for deployment ($readiness_score%)"
    echo "✅ You can proceed with deployment using ./root-deploy.sh"
elif [ "$readiness_score" -ge 75 ]; then
    warning "⚠️ GOOD: System is mostly ready ($readiness_score%)"
    echo "⚠️ Review warnings before deployment"
elif [ "$readiness_score" -ge 60 ]; then
    warning "⚠️ FAIR: System needs attention ($readiness_score%)"
    echo "⚠️ Fix critical issues before deployment"
else
    error "❌ POOR: System not ready for deployment ($readiness_score%)"
    echo "❌ Fix critical issues before proceeding"
fi

echo

# 15. Recommendations
header "💡 Recommendations"

if [ "$FAILED_CHECKS" -gt 0 ]; then
    echo "Critical Issues to Fix:"
    echo "• Review failed checks above"
    echo "• Ensure all required services are running"
    echo "• Install missing dependencies"
fi

if [ "$WARNING_CHECKS" -gt 0 ]; then
    echo "Improvements to Consider:"
    echo "• Review warning items above"
    echo "• Update software to latest versions"
    echo "• Optimize system resources"
fi

echo "Pre-deployment Steps:"
echo "1. Fix any critical issues identified above"
echo "2. Ensure MySQL root password is available"
echo "3. Backup existing website data"
echo "4. Run deployment: ./root-deploy.sh"
echo

echo "Post-deployment Verification:"
echo "1. Test website: https://$DOMAIN"
echo "2. Test calculators: /loan-calculator, /bmi-calculator, /currency-converter"
echo "3. Check SSL certificate"
echo "4. Monitor error logs"
echo

# Save diagnostic report
local report_file="/tmp/fastpanel-diagnostics-$(date +%Y%m%d_%H%M%S).txt"
{
    echo "FastPanel Diagnostics Report"
    echo "Generated: $(date)"
    echo "Domain: $DOMAIN"
    echo "Readiness Score: $readiness_score%"
    echo "Passed: $PASSED_CHECKS, Warnings: $WARNING_CHECKS, Failed: $FAILED_CHECKS"
} > "$report_file"

info "📄 Diagnostic report saved: $report_file"

echo
echo "================================================================"
echo "FastPanel Environment Diagnostics Completed"
echo "================================================================"
