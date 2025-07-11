#!/bin/bash

# Pre-deployment Check Script for NTool Platform
# This script checks system requirements and prepares for deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DOMAIN="besthammer.club"
WEB_ROOT="/var/www/html"
REQUIRED_PHP_VERSION="8.1"
REQUIRED_MYSQL_VERSION="8.0"
REQUIRED_NGINX_VERSION="1.18"

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

check_system_info() {
    log "System Information Check"
    echo "=========================="
    
    info "OS: $(lsb_release -d | cut -f2)"
    info "Kernel: $(uname -r)"
    info "Architecture: $(uname -m)"
    info "Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
    info "Disk Space: $(df -h / | tail -1 | awk '{print $4}') available"
    info "CPU Cores: $(nproc)"
    echo
}

check_php() {
    log "Checking PHP installation..."
    
    if command -v php &> /dev/null; then
        local php_version=$(php -r "echo PHP_VERSION;")
        info "✓ PHP version: $php_version"
        
        if php -r "exit(version_compare(PHP_VERSION, '$REQUIRED_PHP_VERSION', '>=') ? 0 : 1);"; then
            info "✓ PHP version meets requirements"
        else
            error "✗ PHP version $REQUIRED_PHP_VERSION or higher required"
            return 1
        fi
        
        # Check required PHP extensions
        local required_extensions=(
            "bcmath" "ctype" "fileinfo" "json" "mbstring" "openssl"
            "pdo" "pdo_mysql" "tokenizer" "xml" "curl" "zip" "gd"
            "intl" "redis"
        )
        
        local missing_extensions=()
        for ext in "${required_extensions[@]}"; do
            if php -m | grep -q "^$ext$"; then
                info "✓ PHP extension: $ext"
            else
                missing_extensions+=("$ext")
                warning "✗ Missing PHP extension: $ext"
            fi
        done
        
        if [ ${#missing_extensions[@]} -gt 0 ]; then
            error "Missing PHP extensions: ${missing_extensions[*]}"
            info "Install with: sudo apt install php-${missing_extensions[*]// / php-}"
            return 1
        fi
        
    else
        error "✗ PHP is not installed"
        return 1
    fi
}

check_composer() {
    log "Checking Composer..."
    
    if command -v composer &> /dev/null; then
        local composer_version=$(composer --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        info "✓ Composer version: $composer_version"
    else
        error "✗ Composer is not installed"
        info "Install with: curl -sS https://getcomposer.org/installer | php && sudo mv composer.phar /usr/local/bin/composer"
        return 1
    fi
}

check_nodejs() {
    log "Checking Node.js and NPM..."
    
    if command -v node &> /dev/null; then
        local node_version=$(node --version)
        info "✓ Node.js version: $node_version"
        
        if command -v npm &> /dev/null; then
            local npm_version=$(npm --version)
            info "✓ NPM version: $npm_version"
        else
            error "✗ NPM is not installed"
            return 1
        fi
    else
        error "✗ Node.js is not installed"
        info "Install with: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs"
        return 1
    fi
}

check_mysql() {
    log "Checking MySQL/MariaDB..."
    
    if command -v mysql &> /dev/null; then
        local mysql_version=$(mysql --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        info "✓ MySQL version: $mysql_version"
        
        # Test MySQL connection
        read -s -p "Enter MySQL root password to test connection: " mysql_password
        echo
        
        if mysql -uroot -p"$mysql_password" -e "SELECT 1;" &> /dev/null; then
            info "✓ MySQL connection successful"
        else
            error "✗ MySQL connection failed"
            return 1
        fi
    else
        error "✗ MySQL is not installed"
        return 1
    fi
}

check_nginx() {
    log "Checking Nginx..."
    
    if command -v nginx &> /dev/null; then
        local nginx_version=$(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+')
        info "✓ Nginx version: $nginx_version"
        
        if systemctl is-active --quiet nginx; then
            info "✓ Nginx is running"
        else
            warning "Nginx is not running"
            info "Start with: sudo systemctl start nginx"
        fi
        
        if systemctl is-enabled --quiet nginx; then
            info "✓ Nginx is enabled"
        else
            warning "Nginx is not enabled"
            info "Enable with: sudo systemctl enable nginx"
        fi
    else
        error "✗ Nginx is not installed"
        return 1
    fi
}

check_redis() {
    log "Checking Redis..."
    
    if command -v redis-server &> /dev/null; then
        local redis_version=$(redis-server --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        info "✓ Redis version: $redis_version"
        
        if systemctl is-active --quiet redis-server || systemctl is-active --quiet redis; then
            info "✓ Redis is running"
        else
            warning "Redis is not running"
            info "Start with: sudo systemctl start redis-server"
        fi
    else
        warning "Redis is not installed (optional but recommended)"
        info "Install with: sudo apt install redis-server"
    fi
}

check_ssl() {
    log "Checking SSL certificates..."
    
    local cert_path="/etc/ssl/certs/$DOMAIN.crt"
    local key_path="/etc/ssl/private/$DOMAIN.key"
    
    if [ -f "$cert_path" ] && [ -f "$key_path" ]; then
        info "✓ SSL certificates found"
        
        # Check certificate expiry
        local expiry_date=$(openssl x509 -enddate -noout -in "$cert_path" | cut -d= -f2)
        local expiry_timestamp=$(date -d "$expiry_date" +%s)
        local current_timestamp=$(date +%s)
        local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
        
        if [ $days_until_expiry -gt 30 ]; then
            info "✓ SSL certificate valid for $days_until_expiry days"
        else
            warning "SSL certificate expires in $days_until_expiry days"
        fi
    else
        warning "SSL certificates not found"
        info "Consider using Let's Encrypt: sudo certbot --nginx -d $DOMAIN"
    fi
}

check_firewall() {
    log "Checking firewall configuration..."
    
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            info "✓ UFW firewall is active"
            
            # Check required ports
            local required_ports=("22" "80" "443")
            for port in "${required_ports[@]}"; do
                if ufw status | grep -q "$port"; then
                    info "✓ Port $port is allowed"
                else
                    warning "Port $port may not be allowed"
                fi
            done
        else
            warning "UFW firewall is not active"
        fi
    else
        warning "UFW firewall is not installed"
    fi
}

check_disk_space() {
    log "Checking disk space..."
    
    local available_space=$(df / | tail -1 | awk '{print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    
    if [ $available_gb -gt 5 ]; then
        info "✓ Available disk space: ${available_gb}GB"
    else
        warning "Low disk space: ${available_gb}GB available"
        info "Consider cleaning up or expanding disk space"
    fi
}

check_permissions() {
    log "Checking directory permissions..."
    
    if [ -d "$WEB_ROOT" ]; then
        local owner=$(stat -c '%U:%G' "$WEB_ROOT")
        info "Web root owner: $owner"
        
        if [ -w "$WEB_ROOT" ]; then
            info "✓ Web root is writable"
        else
            warning "Web root is not writable"
        fi
    else
        info "Web root directory will be created during deployment"
    fi
}

check_existing_files() {
    log "Checking existing website files..."
    
    if [ -d "$WEB_ROOT" ]; then
        local file_count=$(find "$WEB_ROOT" -type f | wc -l)
        info "Found $file_count files in web root"
        
        # Check for common CMS files
        local cms_files=("wp-config.php" "index.html" "default.html")
        local found_cms=false
        
        for file in "${cms_files[@]}"; do
            if [ -f "$WEB_ROOT/$file" ]; then
                warning "Found existing file: $file"
                found_cms=true
            fi
        done
        
        if $found_cms; then
            warning "Existing website files detected - they will be backed up and removed"
        fi
    else
        info "No existing files found"
    fi
}

check_ntool_source() {
    log "Checking NTool source files..."
    
    local source_dir="$HOME/ntool"
    
    if [ -d "$source_dir" ]; then
        info "✓ NTool source directory found: $source_dir"
        
        # Check for required files
        local required_files=("composer.json" "package.json" "artisan" ".env.example")
        for file in "${required_files[@]}"; do
            if [ -f "$source_dir/$file" ]; then
                info "✓ Found: $file"
            else
                error "✗ Missing: $file"
                return 1
            fi
        done
        
        # Check directory size
        local dir_size=$(du -sh "$source_dir" | cut -f1)
        info "Source directory size: $dir_size"
        
    else
        error "✗ NTool source directory not found: $source_dir"
        info "Please ensure the ntool directory exists in your home folder"
        return 1
    fi
}

generate_report() {
    log "Generating deployment readiness report..."
    
    echo
    echo "=================================="
    echo "DEPLOYMENT READINESS REPORT"
    echo "=================================="
    echo "Domain: $DOMAIN"
    echo "Web Root: $WEB_ROOT"
    echo "Timestamp: $(date)"
    echo
    
    if [ $overall_status -eq 0 ]; then
        echo -e "${GREEN}✓ SYSTEM IS READY FOR DEPLOYMENT${NC}"
        echo
        echo "Next steps:"
        echo "1. Run: chmod +x deploy.sh"
        echo "2. Run: ./deploy.sh"
        echo "3. Monitor the deployment process"
    else
        echo -e "${RED}✗ SYSTEM IS NOT READY FOR DEPLOYMENT${NC}"
        echo
        echo "Please fix the issues above before proceeding with deployment."
    fi
    echo
}

main() {
    log "Starting pre-deployment check for NTool Platform..."
    echo
    
    overall_status=0
    
    check_system_info
    
    # Run all checks
    check_php || overall_status=1
    check_composer || overall_status=1
    check_nodejs || overall_status=1
    check_mysql || overall_status=1
    check_nginx || overall_status=1
    check_redis  # Optional, don't fail on this
    check_ssl    # Optional, don't fail on this
    check_firewall  # Optional, don't fail on this
    check_disk_space || overall_status=1
    check_permissions || overall_status=1
    check_existing_files
    check_ntool_source || overall_status=1
    
    generate_report
    
    exit $overall_status
}

main "$@"
