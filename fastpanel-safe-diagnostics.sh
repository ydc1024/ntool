#!/bin/bash

# FastPanel Safe Diagnostics for BestHammer NTool Platform
# Safe diagnostic script for existing FastPanel installations

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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
header() { echo -e "${PURPLE}[CHECK] $1${NC}"; }

# Global counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Safe check function (read-only operations)
safe_check() {
    local description="$1"
    local command="$2"
    local critical="$3"
    
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
echo "🔨 BestHammer NTool Platform - FastPanel Safe Diagnostics"
echo "========================================================"
echo "Target Domain: $DOMAIN"
echo "Web Root: $WEB_ROOT"
echo "Web User: $WEB_USER"
echo "Scan Time: $(date)"
echo "========================================================"
echo

# 1. System Information (Safe)
header "📊 System Information"
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 2>/dev/null || echo 'Unknown')"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}' 2>/dev/null || echo 'Unknown')"
echo

# 2. FastPanel Environment Check (Safe)
header "🎛️ FastPanel Environment Check"

# Check FastPanel installation
if [ -d '/usr/local/fastpanel' ]; then
    log "$PASS FastPanel directory found: /usr/local/fastpanel"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    
    # Check FastPanel version
    if [ -f "/usr/local/fastpanel/version" ]; then
        local fp_version=$(cat /usr/local/fastpanel/version 2>/dev/null || echo "Unknown")
        info "$INFO FastPanel version: $fp_version"
    fi
    
elif [ -f '/etc/nginx/fastpanel.conf' ]; then
    log "$PASS FastPanel nginx config found"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    warning "$WARN FastPanel installation not detected in standard locations"
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
fi

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

# Check FastPanel service (safe)
safe_check "FastPanel service status check" "systemctl status fastpanel" false

# Check FastPanel web interface (safe, no modification)
safe_check "FastPanel admin port accessible" "netstat -tuln | grep -q ':8888 '" false

echo

# 3. Web Server Check (Safe)
header "🌐 Web Server Environment"
safe_check "Nginx installed" "command -v nginx" true
safe_check "Nginx service running" "systemctl is-active --quiet nginx" true

# Check Nginx version (safe)
if command -v nginx &>/dev/null; then
    local nginx_version=$(nginx -v 2>&1 | cut -d'/' -f2 2>/dev/null || echo "Unknown")
    info "$INFO Nginx version: $nginx_version"
fi

# Check domain configuration (safe)
safe_check "Domain directory exists" "[ -d '/var/www/besthammer_c_usr' ]" true
safe_check "Web user exists" "id '$WEB_USER'" true

# Check web user info (safe)
if id "$WEB_USER" &>/dev/null; then
    local user_groups=$(groups "$WEB_USER" 2>/dev/null | cut -d':' -f2 || echo "Unknown")
    info "$INFO Web user groups:$user_groups"
    
    # Check user shell (safe)
    local user_shell=$(getent passwd "$WEB_USER" | cut -d':' -f7 2>/dev/null || echo "Unknown")
    info "$INFO Web user shell: $user_shell"
fi

echo

# 4. PHP Environment (Safe)
header "🐘 PHP Environment"
safe_check "PHP installed" "command -v php" true

if command -v php &>/dev/null; then
    local php_version=$(php -r "echo PHP_VERSION;" 2>/dev/null || echo "Unknown")
    info "$INFO PHP version: $php_version"
    
    # Check PHP version compatibility (safe)
    local php_major=$(echo $php_version | cut -d'.' -f1 2>/dev/null || echo "0")
    local php_minor=$(echo $php_version | cut -d'.' -f2 2>/dev/null || echo "0")
    
    if [ "$php_major" -ge 8 ] && [ "$php_minor" -ge 1 ]; then
        log "$PASS PHP version is compatible (8.1+)"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        error "$FAIL PHP version too old (requires 8.1+)"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    # Check critical PHP extensions (safe)
    local required_extensions=("pdo" "mysql" "mbstring" "xml" "curl" "zip" "gd")
    
    for ext in "${required_extensions[@]}"; do
        safe_check "PHP extension: $ext" "php -m | grep -q '^$ext$'" true
    done
    
    # Check PHP configuration (safe, read-only)
    local memory_limit=$(php -r "echo ini_get('memory_limit');" 2>/dev/null || echo "Unknown")
    local max_execution_time=$(php -r "echo ini_get('max_execution_time');" 2>/dev/null || echo "Unknown")
    
    info "$INFO PHP memory_limit: $memory_limit"
    info "$INFO PHP max_execution_time: $max_execution_time"
fi

# Check PHP-FPM (safe)
safe_check "PHP-FPM service running" "systemctl is-active --quiet php*-fpm" true

echo

# 5. Database Environment (Safe)
header "🗄️ Database Environment"
safe_check "MySQL server installed" "command -v mysql" true
safe_check "MySQL service running" "systemctl is-active --quiet mysql" true

if command -v mysql &>/dev/null && systemctl is-active --quiet mysql; then
    # Try to get MySQL version (safe)
    local mysql_version=$(mysql --version 2>/dev/null | awk '{print $5}' | cut -d',' -f1 || echo "Unknown")
    info "$INFO MySQL version: $mysql_version"
    
    # Check MySQL process (safe)
    if pgrep mysqld &>/dev/null; then
        log "$PASS MySQL process running"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        warning "$WARN MySQL process not found"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
fi

echo

# 6. Node.js Environment (Safe)
header "📦 Node.js Environment"
safe_check "Node.js installed" "command -v node" true
safe_check "NPM installed" "command -v npm" true

if command -v node &>/dev/null; then
    local node_version=$(node --version 2>/dev/null || echo "Unknown")
    local npm_version=$(npm --version 2>/dev/null || echo "Unknown")
    
    info "$INFO Node.js version: $node_version"
    info "$INFO NPM version: $npm_version"
fi

echo

# 7. Composer Environment (Safe)
header "🎼 Composer Environment"
safe_check "Composer installed" "command -v composer" true

if command -v composer &>/dev/null; then
    local composer_version=$(composer --version 2>/dev/null | awk '{print $3}' || echo "Unknown")
    info "$INFO Composer version: $composer_version"
fi

echo

# 8. System Resources (Safe)
header "💾 System Resources"

# Memory check (safe)
if command -v free &>/dev/null; then
    local total_mem=$(free -m | awk 'NR==2{printf "%.0f", $2}' 2>/dev/null || echo "0")
    local available_mem=$(free -m | awk 'NR==2{printf "%.0f", $7}' 2>/dev/null || echo "0")
    local mem_usage=$(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}' 2>/dev/null || echo "Unknown")
    
    info "$INFO Total memory: ${total_mem}MB"
    info "$INFO Available memory: ${available_mem}MB"
    info "$INFO Memory usage: $mem_usage"
    
    if [ "$total_mem" -ge 1024 ]; then
        log "$PASS Sufficient memory (1GB+)"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        warning "$WARN Low memory (recommended: 1GB+)"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
fi

# Disk space check (safe)
if [ -d "$WEB_ROOT" ]; then
    local disk_usage=$(df -h "$WEB_ROOT" 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//' || echo "0")
    local disk_available=$(df -h "$WEB_ROOT" 2>/dev/null | awk 'NR==2 {print $4}' || echo "Unknown")
    
    info "$INFO Disk usage: ${disk_usage}%"
    info "$INFO Available space: $disk_available"
    
    if [ "$disk_usage" -lt 80 ]; then
        log "$PASS Sufficient disk space"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        warning "$WARN High disk usage (${disk_usage}%)"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
fi

echo

# 9. Network Connectivity (Safe)
header "🌐 Network Connectivity"
safe_check "Internet connectivity" "ping -c 1 -W 5 8.8.8.8" false
safe_check "DNS resolution working" "nslookup $DOMAIN" false
safe_check "HTTP port 80 accessible" "netstat -tuln | grep -q ':80 '" true
safe_check "HTTPS port 443 accessible" "netstat -tuln | grep -q ':443 '" true

echo

# 10. FastPanel Specific Checks (Safe)
header "🎛️ FastPanel Specific Configuration"

if [ -d '/usr/local/fastpanel' ] || [ -f '/etc/nginx/fastpanel.conf' ]; then
    info "$INFO Running FastPanel-specific checks..."
    
    # Check FastPanel nginx configuration (safe)
    local fp_nginx_conf="/etc/nginx/fastpanel.conf"
    safe_check "FastPanel nginx config exists" "[ -f '$fp_nginx_conf' ]" false
    
    # Check web user permissions (safe, read-only)
    if id "$WEB_USER" &>/dev/null; then
        if [ -d "$WEB_ROOT" ]; then
            safe_check "Web user can read web root" "sudo -u $WEB_USER test -r '$WEB_ROOT'" false
            safe_check "Web user can write to web root" "sudo -u $WEB_USER test -w '$WEB_ROOT'" false
        else
            info "$INFO Web root doesn't exist yet (will be created during deployment)"
        fi
        
        safe_check "Web user can execute PHP" "sudo -u $WEB_USER php --version" true
    fi
    
    # Check FastPanel processes (safe)
    safe_check "FastPanel processes running" "pgrep -f fastpanel" false
    
else
    info "$INFO Not a FastPanel server - using standard checks"
fi

echo

# 11. Deployment Readiness Summary
header "📋 Deployment Readiness Summary"

echo "Total Checks: $TOTAL_CHECKS"
echo "Passed: $PASSED_CHECKS ($PASS)"
echo "Warnings: $WARNING_CHECKS ($WARN)"
echo "Failed: $FAILED_CHECKS ($FAIL)"
echo

# Calculate readiness score
if [ "$TOTAL_CHECKS" -gt 0 ]; then
    local readiness_score=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
else
    local readiness_score=0
fi

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

# 12. Safe Recommendations
header "💡 Safe Recommendations"

if [ "$FAILED_CHECKS" -gt 0 ]; then
    echo "Critical Issues to Address:"
    echo "• Install missing required software"
    echo "• Start required services"
    echo "• Check user permissions"
fi

if [ "$WARNING_CHECKS" -gt 0 ]; then
    echo "Improvements to Consider:"
    echo "• Review warning items above"
    echo "• Optimize system resources if needed"
    echo "• Update software versions"
fi

echo "Pre-deployment Checklist:"
echo "1. Ensure MySQL root password is available"
echo "2. Backup existing website data (if any)"
echo "3. Run deployment: ./root-deploy.sh"
echo "4. Test website functionality after deployment"
echo

echo "FastPanel Safety Notes:"
echo "• This diagnostic script only performs read-only checks"
echo "• No FastPanel configurations are modified"
echo "• No services are restarted or stopped"
echo "• Safe to run on production FastPanel servers"
echo

# Save diagnostic report (safe location)
local report_file="/tmp/fastpanel-safe-diagnostics-$(date +%Y%m%d_%H%M%S).txt"
{
    echo "FastPanel Safe Diagnostics Report"
    echo "================================="
    echo "Generated: $(date)"
    echo "Domain: $DOMAIN"
    echo "Readiness Score: $readiness_score%"
    echo "Passed: $PASSED_CHECKS, Warnings: $WARNING_CHECKS, Failed: $FAILED_CHECKS"
    echo "FastPanel Status: $([ -d '/usr/local/fastpanel' ] && echo 'Detected' || echo 'Not Detected')"
} > "$report_file"

info "📄 Safe diagnostic report saved: $report_file"

echo
echo "========================================================"
echo "FastPanel Safe Environment Diagnostics Completed"
echo "========================================================"
