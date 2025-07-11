#!/bin/bash

# NTool Platform Environment Diagnosis Script
# Version: 1.0
# Purpose: Comprehensive VPS environment analysis for Laravel deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="environment_diagnosis_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="diagnosis_report_$(date +%Y%m%d_%H%M%S).txt"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}" | tee -a "$LOG_FILE"
}

print_subsection() {
    echo -e "\n${PURPLE}--- $1 ---${NC}" | tee -a "$LOG_FILE"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get service status
get_service_status() {
    if systemctl is-active --quiet "$1" 2>/dev/null; then
        echo -e "${GREEN}Active${NC}"
    elif systemctl is-enabled --quiet "$1" 2>/dev/null; then
        echo -e "${YELLOW}Inactive (Enabled)${NC}"
    else
        echo -e "${RED}Not Found/Disabled${NC}"
    fi
}

# Function to check port status
check_port() {
    if netstat -tuln 2>/dev/null | grep -q ":$1 "; then
        echo -e "${GREEN}Open${NC}"
    else
        echo -e "${RED}Closed${NC}"
    fi
}

# Function to check PHP extension
check_php_extension() {
    if php -m 2>/dev/null | grep -qi "^$1$"; then
        echo -e "${GREEN}Installed${NC}"
    else
        echo -e "${RED}Missing${NC}"
    fi
}

# Start diagnosis
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                    NTool Platform                            ║
║              Environment Diagnosis Script                    ║
║                                                              ║
║  This script will analyze your VPS environment for          ║
║  Laravel 10.x deployment compatibility                      ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_status "Starting environment diagnosis..."
print_status "Log file: $LOG_FILE"
print_status "Report file: $REPORT_FILE"

# Initialize report
cat > "$REPORT_FILE" << EOF
NTool Platform Environment Diagnosis Report
Generated: $(date)
Server: $(hostname)
User: $(whoami)

EOF

print_section "SYSTEM INFORMATION"

# Basic system info
print_subsection "Operating System"
OS_INFO=$(cat /etc/os-release 2>/dev/null || echo "Unknown")
echo "OS Information:" | tee -a "$LOG_FILE"
echo "$OS_INFO" | tee -a "$LOG_FILE"
echo "$OS_INFO" >> "$REPORT_FILE"

KERNEL_VERSION=$(uname -r)
print_status "Kernel Version: $KERNEL_VERSION"
echo "Kernel: $KERNEL_VERSION" >> "$REPORT_FILE"

ARCHITECTURE=$(uname -m)
print_status "Architecture: $ARCHITECTURE"
echo "Architecture: $ARCHITECTURE" >> "$REPORT_FILE"

# System resources
print_subsection "System Resources"
TOTAL_RAM=$(free -h | awk '/^Mem:/ {print $2}')
AVAILABLE_RAM=$(free -h | awk '/^Mem:/ {print $7}')
print_status "Total RAM: $TOTAL_RAM"
print_status "Available RAM: $AVAILABLE_RAM"

DISK_USAGE=$(df -h / | awk 'NR==2 {print $3"/"$2" ("$5" used)"}')
print_status "Root Disk Usage: $DISK_USAGE"

CPU_INFO=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
print_status "CPU: $CPU_INFO"

echo -e "\nSystem Resources:" >> "$REPORT_FILE"
echo "RAM: $TOTAL_RAM (Available: $AVAILABLE_RAM)" >> "$REPORT_FILE"
echo "Disk: $DISK_USAGE" >> "$REPORT_FILE"
echo "CPU: $CPU_INFO" >> "$REPORT_FILE"

print_section "FASTPANEL DETECTION"

# Check for FastPanel
if [ -d "/usr/local/fastpanel" ] || [ -d "/opt/fastpanel" ] || command_exists "fastpanel"; then
    print_status "FastPanel detected!"
    
    # Try to get FastPanel version
    if command_exists "fastpanel"; then
        FP_VERSION=$(fastpanel --version 2>/dev/null || echo "Unknown")
        print_status "FastPanel Version: $FP_VERSION"
        echo "FastPanel Version: $FP_VERSION" >> "$REPORT_FILE"
    fi
    
    # Check FastPanel directories
    print_subsection "FastPanel Directories"
    FP_DIRS=("/usr/local/fastpanel" "/opt/fastpanel" "/var/www" "/home")
    for dir in "${FP_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            print_status "Found: $dir"
            ls -la "$dir" 2>/dev/null | head -10 | tee -a "$LOG_FILE"
        fi
    done
    
    # Check FastPanel services
    print_subsection "FastPanel Services"
    FP_SERVICES=("fastpanel" "nginx" "apache2" "mysql" "mariadb" "redis-server" "php-fpm")
    for service in "${FP_SERVICES[@]}"; do
        status=$(get_service_status "$service")
        echo -e "$service: $status" | tee -a "$LOG_FILE"
    done
    
else
    print_warning "FastPanel not detected"
    echo "FastPanel: Not detected" >> "$REPORT_FILE"
fi

print_section "WEB SERVER ANALYSIS"

# Check web servers
print_subsection "Web Server Detection"
if command_exists "nginx"; then
    NGINX_VERSION=$(nginx -v 2>&1 | cut -d/ -f2)
    print_status "Nginx Version: $NGINX_VERSION"
    echo "Nginx: $NGINX_VERSION" >> "$REPORT_FILE"
    
    # Check Nginx configuration
    print_status "Nginx Configuration:"
    nginx -T 2>/dev/null | grep -E "(server_name|root|listen)" | head -20 | tee -a "$LOG_FILE"
    
    # Check Nginx sites
    if [ -d "/etc/nginx/sites-available" ]; then
        print_status "Available Sites:"
        ls -la /etc/nginx/sites-available/ | tee -a "$LOG_FILE"
    fi
    
else
    print_warning "Nginx not found"
fi

if command_exists "apache2" || command_exists "httpd"; then
    if command_exists "apache2"; then
        APACHE_VERSION=$(apache2 -v | head -1)
    else
        APACHE_VERSION=$(httpd -v | head -1)
    fi
    print_status "Apache Version: $APACHE_VERSION"
    echo "Apache: $APACHE_VERSION" >> "$REPORT_FILE"
else
    print_warning "Apache not found"
fi

# Check ports
print_subsection "Port Status"
PORTS=(80 443 22 3306 6379 9000)
for port in "${PORTS[@]}"; do
    status=$(check_port "$port")
    echo -e "Port $port: $status" | tee -a "$LOG_FILE"
done

print_section "PHP ENVIRONMENT"

# PHP version and configuration
if command_exists "php"; then
    PHP_VERSION=$(php -v | head -1)
    print_status "PHP Version: $PHP_VERSION"
    echo "PHP: $PHP_VERSION" >> "$REPORT_FILE"
    
    # Check PHP configuration
    print_subsection "PHP Configuration"
    PHP_INI=$(php --ini | grep "Loaded Configuration File" | cut -d: -f2 | xargs)
    print_status "PHP INI: $PHP_INI"
    
    # Important PHP settings
    print_status "Important PHP Settings:"
    php -r "
    echo 'Memory Limit: ' . ini_get('memory_limit') . PHP_EOL;
    echo 'Max Execution Time: ' . ini_get('max_execution_time') . PHP_EOL;
    echo 'Upload Max Filesize: ' . ini_get('upload_max_filesize') . PHP_EOL;
    echo 'Post Max Size: ' . ini_get('post_max_size') . PHP_EOL;
    echo 'Max Input Vars: ' . ini_get('max_input_vars') . PHP_EOL;
    " | tee -a "$LOG_FILE"
    
    # Check required PHP extensions for Laravel
    print_subsection "PHP Extensions (Laravel Requirements)"
    REQUIRED_EXTENSIONS=(
        "bcmath" "ctype" "fileinfo" "json" "mbstring" "openssl" 
        "pdo" "tokenizer" "xml" "curl" "zip" "gd" "mysqli" "redis"
    )
    
    echo -e "\nPHP Extensions:" >> "$REPORT_FILE"
    for ext in "${REQUIRED_EXTENSIONS[@]}"; do
        status=$(check_php_extension "$ext")
        echo -e "$ext: $status" | tee -a "$LOG_FILE"
        echo "$ext: $status" >> "$REPORT_FILE"
    done
    
    # Check PHP-FPM
    if command_exists "php-fpm"; then
        FPM_VERSION=$(php-fpm -v | head -1)
        print_status "PHP-FPM: $FPM_VERSION"
    fi
    
else
    print_error "PHP not found!"
    echo "PHP: NOT FOUND" >> "$REPORT_FILE"
fi

print_section "DATABASE ANALYSIS"

# MySQL/MariaDB
print_subsection "MySQL/MariaDB"
if command_exists "mysql"; then
    MYSQL_VERSION=$(mysql --version)
    print_status "MySQL Version: $MYSQL_VERSION"
    echo "MySQL: $MYSQL_VERSION" >> "$REPORT_FILE"
    
    # Try to connect to MySQL
    if mysql -e "SELECT VERSION();" 2>/dev/null; then
        print_status "MySQL connection: OK"
        mysql -e "SHOW DATABASES;" 2>/dev/null | tee -a "$LOG_FILE"
    else
        print_warning "MySQL connection failed (credentials needed)"
    fi
else
    print_warning "MySQL client not found"
fi

# Check for existing databases
print_subsection "Database Files"
if [ -d "/var/lib/mysql" ]; then
    print_status "MySQL data directory found"
    ls -la /var/lib/mysql/ | head -10 | tee -a "$LOG_FILE"
fi

print_section "REDIS ANALYSIS"

if command_exists "redis-cli"; then
    REDIS_VERSION=$(redis-cli --version)
    print_status "Redis Version: $REDIS_VERSION"
    echo "Redis: $REDIS_VERSION" >> "$REPORT_FILE"
    
    # Test Redis connection
    if redis-cli ping 2>/dev/null | grep -q "PONG"; then
        print_status "Redis connection: OK"
        redis-cli info server | grep redis_version | tee -a "$LOG_FILE"
    else
        print_warning "Redis connection failed"
    fi
else
    print_warning "Redis not found"
    echo "Redis: NOT FOUND" >> "$REPORT_FILE"
fi

print_section "DEVELOPMENT TOOLS"

# Composer
print_subsection "Composer"
if command_exists "composer"; then
    COMPOSER_VERSION=$(composer --version)
    print_status "Composer: $COMPOSER_VERSION"
    echo "Composer: $COMPOSER_VERSION" >> "$REPORT_FILE"
else
    print_warning "Composer not found"
    echo "Composer: NOT FOUND" >> "$REPORT_FILE"
fi

# Node.js and npm
print_subsection "Node.js Environment"
if command_exists "node"; then
    NODE_VERSION=$(node --version)
    print_status "Node.js: $NODE_VERSION"
    echo "Node.js: $NODE_VERSION" >> "$REPORT_FILE"
else
    print_warning "Node.js not found"
    echo "Node.js: NOT FOUND" >> "$REPORT_FILE"
fi

if command_exists "npm"; then
    NPM_VERSION=$(npm --version)
    print_status "npm: $NPM_VERSION"
    echo "npm: $NPM_VERSION" >> "$REPORT_FILE"
else
    print_warning "npm not found"
fi

# Git
if command_exists "git"; then
    GIT_VERSION=$(git --version)
    print_status "Git: $GIT_VERSION"
    echo "Git: $GIT_VERSION" >> "$REPORT_FILE"
else
    print_warning "Git not found"
    echo "Git: NOT FOUND" >> "$REPORT_FILE"
fi

print_section "EXISTING WEBSITE ANALYSIS"

# Check common web directories
print_subsection "Web Directories"
WEB_DIRS=("/var/www" "/home/*/public_html" "/usr/share/nginx/html" "/var/www/html")
for dir_pattern in "${WEB_DIRS[@]}"; do
    for dir in $dir_pattern; do
        if [ -d "$dir" ]; then
            print_status "Found web directory: $dir"
            echo "Contents of $dir:" | tee -a "$LOG_FILE"
            ls -la "$dir" 2>/dev/null | head -10 | tee -a "$LOG_FILE"
            
            # Check for existing Laravel installations
            if [ -f "$dir/artisan" ]; then
                print_status "Laravel installation detected in $dir"
                if [ -f "$dir/.env" ]; then
                    print_status "Environment file found"
                fi
            fi
            
            # Check for other frameworks
            if [ -f "$dir/wp-config.php" ]; then
                print_status "WordPress installation detected in $dir"
            fi
            if [ -f "$dir/index.php" ] && grep -q "Joomla" "$dir/index.php" 2>/dev/null; then
                print_status "Joomla installation detected in $dir"
            fi
        fi
    done
done

print_section "SSL/TLS CONFIGURATION"

# Check SSL certificates
print_subsection "SSL Certificates"
SSL_DIRS=("/etc/ssl/certs" "/etc/letsencrypt/live" "/etc/nginx/ssl" "/etc/apache2/ssl")
for dir in "${SSL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        print_status "SSL directory found: $dir"
        ls -la "$dir" 2>/dev/null | head -5 | tee -a "$LOG_FILE"
    fi
done

# Check for Let's Encrypt
if command_exists "certbot"; then
    CERTBOT_VERSION=$(certbot --version)
    print_status "Certbot: $CERTBOT_VERSION"
    echo "Certbot: $CERTBOT_VERSION" >> "$REPORT_FILE"
else
    print_warning "Certbot not found"
fi

print_section "SECURITY ANALYSIS"

# Check firewall
print_subsection "Firewall Status"
if command_exists "ufw"; then
    UFW_STATUS=$(ufw status)
    print_status "UFW Status:"
    echo "$UFW_STATUS" | tee -a "$LOG_FILE"
elif command_exists "iptables"; then
    print_status "iptables rules:"
    iptables -L | head -20 | tee -a "$LOG_FILE"
else
    print_warning "No firewall detected"
fi

# Check fail2ban
if command_exists "fail2ban-client"; then
    print_status "Fail2ban detected"
    fail2ban-client status 2>/dev/null | tee -a "$LOG_FILE"
else
    print_warning "Fail2ban not found"
fi

print_section "PERFORMANCE ANALYSIS"

# Check system load
print_subsection "System Performance"
LOAD_AVERAGE=$(uptime | awk -F'load average:' '{print $2}')
print_status "Load Average: $LOAD_AVERAGE"

# Check memory usage
print_status "Memory Usage:"
free -h | tee -a "$LOG_FILE"

# Check disk I/O
if command_exists "iostat"; then
    print_status "Disk I/O:"
    iostat -x 1 1 | tee -a "$LOG_FILE"
fi

print_section "NETWORK CONFIGURATION"

# Check network interfaces
print_subsection "Network Interfaces"
ip addr show | grep -E "(inet |inet6 )" | tee -a "$LOG_FILE"

# Check DNS
print_status "DNS Configuration:"
cat /etc/resolv.conf | tee -a "$LOG_FILE"

# Test external connectivity
print_subsection "External Connectivity"
if ping -c 1 google.com >/dev/null 2>&1; then
    print_status "Internet connectivity: OK"
else
    print_warning "Internet connectivity: Failed"
fi

if ping -c 1 github.com >/dev/null 2>&1; then
    print_status "GitHub connectivity: OK"
else
    print_warning "GitHub connectivity: Failed"
fi

print_section "DIAGNOSIS SUMMARY"

# Generate summary
echo -e "\n=== DIAGNOSIS SUMMARY ===" >> "$REPORT_FILE"

# Check Laravel compatibility
echo -e "\nLaravel 10.x Compatibility:" >> "$REPORT_FILE"

# PHP version check
if command_exists "php"; then
    PHP_MAJOR=$(php -r "echo PHP_MAJOR_VERSION;")
    PHP_MINOR=$(php -r "echo PHP_MINOR_VERSION;")
    if [ "$PHP_MAJOR" -ge 8 ] && [ "$PHP_MINOR" -ge 1 ]; then
        echo "✓ PHP Version: Compatible" >> "$REPORT_FILE"
        print_status "PHP Version: Compatible (>= 8.1)"
    else
        echo "✗ PHP Version: Incompatible (requires >= 8.1)" >> "$REPORT_FILE"
        print_error "PHP Version: Incompatible (requires >= 8.1)"
    fi
else
    echo "✗ PHP: Not installed" >> "$REPORT_FILE"
    print_error "PHP: Not installed"
fi

# Required extensions check
MISSING_EXTENSIONS=()
for ext in "${REQUIRED_EXTENSIONS[@]}"; do
    if ! php -m 2>/dev/null | grep -qi "^$ext$"; then
        MISSING_EXTENSIONS+=("$ext")
    fi
done

if [ ${#MISSING_EXTENSIONS[@]} -eq 0 ]; then
    echo "✓ PHP Extensions: All required extensions installed" >> "$REPORT_FILE"
    print_status "PHP Extensions: All required extensions installed"
else
    echo "✗ PHP Extensions: Missing: ${MISSING_EXTENSIONS[*]}" >> "$REPORT_FILE"
    print_error "PHP Extensions: Missing: ${MISSING_EXTENSIONS[*]}"
fi

# Database check
if command_exists "mysql" && mysql -e "SELECT 1;" 2>/dev/null; then
    echo "✓ Database: MySQL/MariaDB accessible" >> "$REPORT_FILE"
    print_status "Database: MySQL/MariaDB accessible"
else
    echo "? Database: MySQL/MariaDB needs configuration" >> "$REPORT_FILE"
    print_warning "Database: MySQL/MariaDB needs configuration"
fi

# Web server check
if command_exists "nginx" || command_exists "apache2"; then
    echo "✓ Web Server: Available" >> "$REPORT_FILE"
    print_status "Web Server: Available"
else
    echo "✗ Web Server: Not found" >> "$REPORT_FILE"
    print_error "Web Server: Not found"
fi

# Composer check
if command_exists "composer"; then
    echo "✓ Composer: Installed" >> "$REPORT_FILE"
    print_status "Composer: Installed"
else
    echo "✗ Composer: Not installed" >> "$REPORT_FILE"
    print_error "Composer: Not installed"
fi

# Node.js check
if command_exists "node"; then
    NODE_MAJOR=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_MAJOR" -ge 16 ]; then
        echo "✓ Node.js: Compatible version" >> "$REPORT_FILE"
        print_status "Node.js: Compatible version"
    else
        echo "? Node.js: Version may be too old (recommend >= 16)" >> "$REPORT_FILE"
        print_warning "Node.js: Version may be too old (recommend >= 16)"
    fi
else
    echo "✗ Node.js: Not installed" >> "$REPORT_FILE"
    print_error "Node.js: Not installed"
fi

print_section "RECOMMENDATIONS"

echo -e "\n=== RECOMMENDATIONS ===" >> "$REPORT_FILE"

# Generate recommendations based on findings
if [ ${#MISSING_EXTENSIONS[@]} -gt 0 ]; then
    echo "1. Install missing PHP extensions: ${MISSING_EXTENSIONS[*]}" >> "$REPORT_FILE"
    print_warning "Install missing PHP extensions: ${MISSING_EXTENSIONS[*]}"
fi

if ! command_exists "composer"; then
    echo "2. Install Composer for dependency management" >> "$REPORT_FILE"
    print_warning "Install Composer for dependency management"
fi

if ! command_exists "node"; then
    echo "3. Install Node.js (>= 16) for frontend asset compilation" >> "$REPORT_FILE"
    print_warning "Install Node.js (>= 16) for frontend asset compilation"
fi

if ! command_exists "redis-cli"; then
    echo "4. Install Redis for caching and sessions" >> "$REPORT_FILE"
    print_warning "Install Redis for caching and sessions"
fi

echo "5. Backup existing website files before deployment" >> "$REPORT_FILE"
echo "6. Configure SSL certificates for HTTPS" >> "$REPORT_FILE"
echo "7. Set up proper file permissions for Laravel" >> "$REPORT_FILE"
echo "8. Configure database credentials" >> "$REPORT_FILE"

print_status "Diagnosis completed!"
print_status "Detailed report saved to: $REPORT_FILE"
print_status "Full log saved to: $LOG_FILE"

echo -e "\n${CYAN}Next Steps:${NC}"
echo "1. Review the diagnosis report: $REPORT_FILE"
echo "2. Address any compatibility issues found"
echo "3. Backup your existing website files"
echo "4. Proceed with deployment script generation"

echo -e "\n${GREEN}Diagnosis completed successfully!${NC}"
