#!/bin/bash

# BestHammer NTool Platform - Debug Version Source Diagnostic
# This version includes detailed debugging to identify where the script stops

set -e

# Enable debug mode
set -x

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

# Debug logging function
debug() {
    echo -e "${CYAN}[DEBUG] $1${NC}" >&2
}

# Improved logging functions with debug
log() { 
    debug "Entering log function with: $1"
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED_CHECKS++))
    ((TOTAL_CHECKS++))
    debug "Counters updated: PASSED=$PASSED_CHECKS, TOTAL=$TOTAL_CHECKS"
}

warning() { 
    debug "Entering warning function with: $1"
    echo -e "${YELLOW}⚠️ $1${NC}"
    ((WARNING_CHECKS++))
    ((TOTAL_CHECKS++))
    debug "Counters updated: WARNING=$WARNING_CHECKS, TOTAL=$TOTAL_CHECKS"
}

error() { 
    debug "Entering error function with: $1"
    echo -e "${RED}❌ $1${NC}"
    ((FAILED_CHECKS++))
    ((TOTAL_CHECKS++))
    debug "Counters updated: FAILED=$FAILED_CHECKS, TOTAL=$TOTAL_CHECKS"
}

info() { 
    debug "Entering info function with: $1"
    echo -e "${BLUE}ℹ️ $1${NC}"
}

section() { 
    debug "Entering section function with: $1"
    echo -e "${PURPLE}🔍 $1${NC}"
}

detail() { 
    debug "Entering detail function with: $1"
    echo -e "${CYAN}   → $1${NC}"
}

# Safe command execution with timeout
safe_exec() {
    local cmd="$1"
    local description="$2"
    
    debug "Executing safe_exec with cmd: $cmd, description: $description"
    
    # Use timeout to prevent hanging
    if timeout 10s bash -c "$cmd" &>/dev/null; then
        debug "Command succeeded: $cmd"
        return 0
    else
        debug "Command failed or timed out: $cmd"
        return 1
    fi
}

# Check if command exists with timeout
command_exists() {
    local tool="$1"
    debug "Checking if command exists: $tool"
    
    # Use timeout to prevent hanging
    if timeout 5s command -v "$tool" >/dev/null 2>&1; then
        debug "Command exists: $tool"
        return 0
    else
        debug "Command does not exist or timed out: $tool"
        return 1
    fi
}

echo "🔍 BestHammer NTool Platform - Debug Source Diagnostic"
echo "======================================================"
echo "Web Root: $WEB_ROOT"
echo "Web User: $WEB_USER"
echo "Diagnostic Time: $(date)"
echo "Debug Mode: ENABLED"
echo "======================================================"
echo

debug "Starting pre-flight checks"

# Pre-flight checks
section "Pre-flight Environment Checks"

debug "Checking if running as root"
# Check if running as root or with sudo
if [[ $EUID -eq 0 ]]; then
    info "Running as root"
    debug "Confirmed running as root"
elif command_exists sudo; then
    info "Running with sudo available"
    debug "Sudo is available"
else
    warning "Not running as root and sudo not available - some checks may fail"
    debug "No root or sudo access"
fi

debug "Checking web root directory"
# Check if web root exists
if [ ! -d "$WEB_ROOT" ]; then
    error "Web root directory does not exist: $WEB_ROOT"
    echo "Please verify the correct path and try again."
    exit 1
fi

debug "Changing to web root directory"
cd "$WEB_ROOT" || exit 1
log "Web root directory accessible"

debug "Starting tool availability checks"

# Check required tools with explicit array declaration
debug "Declaring REQUIRED_TOOLS array"
REQUIRED_TOOLS=("php" "mysql" "curl")
debug "REQUIRED_TOOLS array declared with ${#REQUIRED_TOOLS[@]} elements"

debug "Declaring OPTIONAL_TOOLS array"
OPTIONAL_TOOLS=("jq" "composer" "npm")
debug "OPTIONAL_TOOLS array declared with ${#OPTIONAL_TOOLS[@]} elements"

debug "Starting required tools check loop"
for i in "${!REQUIRED_TOOLS[@]}"; do
    tool="${REQUIRED_TOOLS[$i]}"
    debug "Checking required tool $((i+1))/${#REQUIRED_TOOLS[@]}: $tool"
    
    if command_exists "$tool"; then
        detail "✓ $tool available"
        debug "Tool $tool is available"
    else
        error "$tool not available - some checks will be skipped"
        debug "Tool $tool is not available"
    fi
done

debug "Required tools check completed"

debug "Starting optional tools check loop"
for i in "${!OPTIONAL_TOOLS[@]}"; do
    tool="${OPTIONAL_TOOLS[$i]}"
    debug "Checking optional tool $((i+1))/${#OPTIONAL_TOOLS[@]}: $tool"
    
    if command_exists "$tool"; then
        detail "✓ $tool available"
        debug "Tool $tool is available"
    else
        warning "$tool not available - related checks will be limited"
        debug "Tool $tool is not available"
    fi
done

debug "Optional tools check completed"

debug "Pre-flight checks completed successfully"

# Section 1: Laravel Core Structure Analysis
section "Section 1: Laravel Core Structure Analysis"

debug "Starting Laravel core structure analysis"

# Define Laravel core files array with explicit declaration
debug "Declaring LARAVEL_CORE_FILES array"
LARAVEL_CORE_FILES=(
    "artisan"
    "bootstrap/app.php"
    "app/Http/Kernel.php"
    "config/app.php"
    "routes/web.php"
    "routes/api.php"
    ".env"
    "composer.json"
)
debug "LARAVEL_CORE_FILES array declared with ${#LARAVEL_CORE_FILES[@]} elements"

info "Checking Laravel core files..."

debug "Starting core files check loop"
for i in "${!LARAVEL_CORE_FILES[@]}"; do
    file="${LARAVEL_CORE_FILES[$i]}"
    debug "Checking core file $((i+1))/${#LARAVEL_CORE_FILES[@]}: $file"
    
    if [ -f "$file" ]; then
        debug "File exists: $file"
        
        # Check file syntax for PHP files
        if [[ "$file" == *.php ]]; then
            debug "Checking PHP syntax for: $file"
            
            if command_exists php && safe_exec "php -l '$file'" "PHP syntax check"; then
                log "$file (syntax OK)"
                debug "PHP syntax OK for: $file"
            else
                error "$file (syntax error)"
                debug "PHP syntax error for: $file"
                
                if command_exists php; then
                    debug "Getting detailed syntax error for: $file"
                    ERROR_OUTPUT=$(php -l "$file" 2>&1 | head -2 | tail -1)
                    detail "$ERROR_OUTPUT"
                    debug "Error output: $ERROR_OUTPUT"
                fi
            fi
        else
            log "$file (exists)"
            debug "Non-PHP file exists: $file"
        fi
    else
        error "$file (missing)"
        debug "File missing: $file"
    fi
done

debug "Core files check completed"

# Section 2: Quick Application Files Check
section "Section 2: Quick Application Files Check"

debug "Starting application files check"

# Check controllers
debug "Checking controllers directory"
if [ -d "app/Http/Controllers" ]; then
    CONTROLLER_COUNT=$(find app/Http/Controllers -name "*.php" 2>/dev/null | wc -l)
    log "Controllers directory exists ($CONTROLLER_COUNT PHP files found)"
    debug "Found $CONTROLLER_COUNT controller files"
else
    error "Controllers directory missing"
    debug "Controllers directory does not exist"
fi

# Check services
debug "Checking services directory"
if [ -d "app/Services" ]; then
    SERVICE_COUNT=$(find app/Services -name "*.php" 2>/dev/null | wc -l)
    log "Services directory exists ($SERVICE_COUNT PHP files found)"
    debug "Found $SERVICE_COUNT service files"
else
    error "Services directory missing"
    debug "Services directory does not exist"
fi

# Check models
debug "Checking models directory"
if [ -d "app/Models" ]; then
    MODEL_COUNT=$(find app/Models -name "*.php" 2>/dev/null | wc -l)
    log "Models directory exists ($MODEL_COUNT PHP files found)"
    debug "Found $MODEL_COUNT model files"
else
    error "Models directory missing"
    debug "Models directory does not exist"
fi

debug "Application files check completed"

# Section 3: Basic Dependency Check
section "Section 3: Basic Dependency Check"

debug "Starting dependency check"

# Check vendor directory
debug "Checking vendor directory"
if [ -d "vendor" ]; then
    log "vendor directory (exists)"
    debug "Vendor directory exists"
    
    # Check autoload file
    debug "Checking autoload file"
    if [ -f "vendor/autoload.php" ]; then
        detail "✓ Autoload file exists"
        debug "Autoload file exists"
        
        # Test autoload functionality
        debug "Testing autoload functionality"
        if command_exists php && safe_exec "php -r \"require 'vendor/autoload.php'; echo 'OK';\"" "Autoload test"; then
            detail "✓ Autoload works"
            debug "Autoload test passed"
        else
            error "Autoload has issues"
            debug "Autoload test failed"
        fi
    else
        error "vendor/autoload.php missing"
        debug "Autoload file missing"
    fi
else
    error "vendor directory missing - run composer install"
    debug "Vendor directory does not exist"
fi

debug "Dependency check completed"

# Quick Summary
section "Quick Diagnostic Summary"

debug "Generating quick summary"

echo
echo "🎯 QUICK DIAGNOSTIC SUMMARY"
echo "==========================="
echo "Total Checks: $TOTAL_CHECKS"
echo "✅ Passed: $PASSED_CHECKS"
echo "⚠️ Warnings: $WARNING_CHECKS"
echo "❌ Failed: $FAILED_CHECKS"

if [ "$TOTAL_CHECKS" -gt 0 ]; then
    SUCCESS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    echo "Success Rate: ${SUCCESS_RATE}%"
    debug "Success rate calculated: $SUCCESS_RATE%"
else
    echo "Success Rate: 0%"
    debug "No checks performed"
fi

echo
echo "🔧 IMMEDIATE RECOMMENDATIONS:"
echo "============================="

if [ "$FAILED_CHECKS" -gt 5 ]; then
    echo "❌ HIGH PRIORITY: Many critical issues found"
    echo "   → Run Laravel compatibility fix script"
    echo "   → Install missing dependencies with: composer install"
    debug "High priority issues detected"
elif [ "$FAILED_CHECKS" -gt 2 ]; then
    echo "⚠️ MEDIUM PRIORITY: Some issues found"
    echo "   → Address missing files"
    echo "   → Check configuration"
    debug "Medium priority issues detected"
elif [ "$FAILED_CHECKS" -gt 0 ]; then
    echo "ℹ️ LOW PRIORITY: Minor issues found"
    echo "   → Review and fix remaining issues"
    debug "Low priority issues detected"
else
    echo "🎉 NO CRITICAL ISSUES: Basic structure is complete"
    echo "   → Run full diagnostic for detailed analysis"
    debug "No critical issues found"
fi

echo
echo "================================================================"
echo "Debug diagnostic completed at $(date)"
echo "================================================================"

debug "Script completed successfully"
