#!/bin/bash

# FastPanel Specific Analysis Script
# This script provides detailed analysis of FastPanel configuration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOG_FILE="fastpanel_analysis_$(date +%Y%m%d_%H%M%S).log"

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}" | tee -a "$LOG_FILE"
}

echo -e "${BLUE}FastPanel Detailed Analysis${NC}"
echo "Log file: $LOG_FILE"

print_section "FASTPANEL INSTALLATION DETECTION"

# Check FastPanel installation paths
FP_PATHS=(
    "/usr/local/fastpanel"
    "/opt/fastpanel" 
    "/var/fastpanel"
    "/home/fastpanel"
    "/usr/share/fastpanel"
)

FP_FOUND=false
for path in "${FP_PATHS[@]}"; do
    if [ -d "$path" ]; then
        print_status "FastPanel found at: $path"
        FP_FOUND=true
        FP_ROOT="$path"
        
        # List contents
        echo "Contents:" | tee -a "$LOG_FILE"
        ls -la "$path" 2>/dev/null | tee -a "$LOG_FILE"
        
        # Check for configuration files
        if [ -f "$path/config.json" ]; then
            print_status "Configuration file found: $path/config.json"
        fi
        
        if [ -f "$path/fastpanel.conf" ]; then
            print_status "Configuration file found: $path/fastpanel.conf"
        fi
    fi
done

if [ "$FP_FOUND" = false ]; then
    print_warning "FastPanel installation not found in standard locations"
    
    # Try to find FastPanel by process
    if pgrep -f "fastpanel" >/dev/null; then
        print_status "FastPanel process detected"
        ps aux | grep fastpanel | grep -v grep | tee -a "$LOG_FILE"
    fi
fi

print_section "FASTPANEL SERVICES"

# Check FastPanel related services
FP_SERVICES=(
    "fastpanel"
    "fastpanel-nginx" 
    "fastpanel-apache"
    "fastpanel-mysql"
    "fastpanel-redis"
    "fastpanel-php"
    "fastpanel-fpm"
)

for service in "${FP_SERVICES[@]}"; do
    if systemctl list-units --type=service | grep -q "$service"; then
        status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
        print_status "$service: $status"
        
        if [ "$status" = "active" ]; then
            systemctl status "$service" --no-pager -l | head -10 | tee -a "$LOG_FILE"
        fi
    fi
done

print_section "FASTPANEL WEB CONFIGURATION"

# Check for FastPanel web interface
FP_WEB_PORTS=(8080 8443 2083 2087 10000)
for port in "${FP_WEB_PORTS[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        print_status "FastPanel web interface may be running on port $port"
    fi
done

# Check FastPanel virtual hosts
if [ -d "/etc/nginx/sites-available" ]; then
    print_status "Checking Nginx sites for FastPanel configuration:"
    for site in /etc/nginx/sites-available/*; do
        if [ -f "$site" ] && grep -q "fastpanel\|panel" "$site" 2>/dev/null; then
            print_status "FastPanel-related site found: $(basename "$site")"
            echo "Configuration preview:" | tee -a "$LOG_FILE"
            head -20 "$site" | tee -a "$LOG_FILE"
        fi
    done
fi

print_section "FASTPANEL USER ACCOUNTS"

# Check for FastPanel users
if [ -f "/etc/passwd" ]; then
    print_status "Checking for FastPanel-related users:"
    grep -E "(fastpanel|panel|fp)" /etc/passwd | tee -a "$LOG_FILE"
fi

# Check user home directories for websites
print_status "Checking user home directories:"
for home_dir in /home/*; do
    if [ -d "$home_dir" ]; then
        username=$(basename "$home_dir")
        print_status "User: $username"
        
        # Check for public_html
        if [ -d "$home_dir/public_html" ]; then
            print_status "  - public_html found"
            ls -la "$home_dir/public_html" | head -5 | sed 's/^/    /' | tee -a "$LOG_FILE"
        fi
        
        # Check for domains
        if [ -d "$home_dir/domains" ]; then
            print_status "  - domains directory found"
            ls -la "$home_dir/domains" | head -5 | sed 's/^/    /' | tee -a "$LOG_FILE"
        fi
        
        # Check for www
        if [ -d "$home_dir/www" ]; then
            print_status "  - www directory found"
            ls -la "$home_dir/www" | head -5 | sed 's/^/    /' | tee -a "$LOG_FILE"
        fi
    fi
done

print_section "FASTPANEL DATABASE CONFIGURATION"

# Check for FastPanel database
if command -v mysql >/dev/null 2>&1; then
    print_status "Checking for FastPanel databases:"
    
    # Try to list databases (may require credentials)
    if mysql -e "SHOW DATABASES;" 2>/dev/null; then
        mysql -e "SHOW DATABASES;" | grep -E "(fastpanel|panel|fp)" | tee -a "$LOG_FILE"
    else
        print_warning "Cannot access MySQL without credentials"
    fi
    
    # Check MySQL configuration for FastPanel
    if [ -f "/etc/mysql/my.cnf" ]; then
        if grep -q "fastpanel\|panel" "/etc/mysql/my.cnf" 2>/dev/null; then
            print_status "FastPanel configuration found in MySQL config"
        fi
    fi
fi

print_section "FASTPANEL PHP CONFIGURATION"

# Check for FastPanel PHP configurations
PHP_DIRS=(
    "/etc/php"
    "/usr/local/php"
    "/opt/php"
)

for php_dir in "${PHP_DIRS[@]}"; do
    if [ -d "$php_dir" ]; then
        print_status "PHP directory found: $php_dir"
        
        # Look for FastPanel-specific PHP configurations
        find "$php_dir" -name "*fastpanel*" -o -name "*panel*" 2>/dev/null | while read -r file; do
            print_status "FastPanel PHP config: $file"
        done
        
        # Check PHP versions
        for version_dir in "$php_dir"/*; do
            if [ -d "$version_dir" ] && [[ $(basename "$version_dir") =~ ^[0-9]+\.[0-9]+$ ]]; then
                version=$(basename "$version_dir")
                print_status "PHP version available: $version"
                
                # Check if this version has FastPanel configuration
                if [ -f "$version_dir/fpm/pool.d/fastpanel.conf" ]; then
                    print_status "  - FastPanel FPM pool found for PHP $version"
                fi
            fi
        done
    fi
done

print_section "FASTPANEL DOMAIN CONFIGURATION"

# Check for domain configurations
DOMAIN_DIRS=(
    "/var/www"
    "/home/*/domains"
    "/home/*/public_html"
    "/usr/share/nginx/html"
)

for dir_pattern in "${DOMAIN_DIRS[@]}"; do
    for dir in $dir_pattern; do
        if [ -d "$dir" ]; then
            print_status "Domain directory: $dir"
            
            # Check for .htaccess files (Apache configuration)
            find "$dir" -name ".htaccess" -type f 2>/dev/null | while read -r htaccess; do
                print_status "  - .htaccess found: $htaccess"
                if grep -q "fastpanel\|panel" "$htaccess" 2>/dev/null; then
                    print_status "    Contains FastPanel configuration"
                fi
            done
            
            # Check for index files
            find "$dir" -maxdepth 2 -name "index.*" -type f 2>/dev/null | head -5 | while read -r index; do
                print_status "  - Index file: $index"
            done
        fi
    done
done

print_section "FASTPANEL SSL CONFIGURATION"

# Check for FastPanel SSL certificates
SSL_DIRS=(
    "/etc/ssl/fastpanel"
    "/usr/local/fastpanel/ssl"
    "/opt/fastpanel/ssl"
    "/var/fastpanel/ssl"
)

for ssl_dir in "${SSL_DIRS[@]}"; do
    if [ -d "$ssl_dir" ]; then
        print_status "FastPanel SSL directory: $ssl_dir"
        ls -la "$ssl_dir" | tee -a "$LOG_FILE"
    fi
done

# Check for Let's Encrypt integration
if [ -d "/etc/letsencrypt/live" ]; then
    print_status "Let's Encrypt certificates:"
    ls -la /etc/letsencrypt/live/ | tee -a "$LOG_FILE"
fi

print_section "FASTPANEL BACKUP CONFIGURATION"

# Check for FastPanel backup directories
BACKUP_DIRS=(
    "/var/backups/fastpanel"
    "/home/backups"
    "/backup"
    "/usr/local/fastpanel/backups"
)

for backup_dir in "${BACKUP_DIRS[@]}"; do
    if [ -d "$backup_dir" ]; then
        print_status "Backup directory found: $backup_dir"
        ls -la "$backup_dir" | head -10 | tee -a "$LOG_FILE"
    fi
done

print_section "FASTPANEL LOG FILES"

# Check for FastPanel log files
LOG_DIRS=(
    "/var/log/fastpanel"
    "/usr/local/fastpanel/logs"
    "/opt/fastpanel/logs"
    "/var/log"
)

for log_dir in "${LOG_DIRS[@]}"; do
    if [ -d "$log_dir" ]; then
        find "$log_dir" -name "*fastpanel*" -o -name "*panel*" 2>/dev/null | while read -r logfile; do
            print_status "FastPanel log file: $logfile"
            if [ -f "$logfile" ]; then
                echo "Recent entries:" | tee -a "$LOG_FILE"
                tail -5 "$logfile" 2>/dev/null | sed 's/^/  /' | tee -a "$LOG_FILE"
            fi
        done
    fi
done

print_section "FASTPANEL CRON JOBS"

# Check for FastPanel cron jobs
print_status "Checking cron jobs for FastPanel:"
crontab -l 2>/dev/null | grep -i "fastpanel\|panel" | tee -a "$LOG_FILE" || print_warning "No user crontab or no FastPanel entries"

# Check system cron
if [ -d "/etc/cron.d" ]; then
    find /etc/cron.d -name "*fastpanel*" -o -name "*panel*" 2>/dev/null | while read -r cronfile; do
        print_status "System cron file: $cronfile"
        cat "$cronfile" | tee -a "$LOG_FILE"
    done
fi

print_section "FASTPANEL NETWORK CONFIGURATION"

# Check for FastPanel network bindings
print_status "Network connections related to FastPanel:"
netstat -tuln 2>/dev/null | grep -E "(8080|8443|2083|2087|10000)" | tee -a "$LOG_FILE"

# Check for FastPanel processes and their ports
print_status "FastPanel processes:"
ps aux | grep -i fastpanel | grep -v grep | tee -a "$LOG_FILE"

print_section "ANALYSIS SUMMARY"

echo "FastPanel Analysis Summary:" | tee -a "$LOG_FILE"
echo "=========================" | tee -a "$LOG_FILE"

if [ "$FP_FOUND" = true ]; then
    echo "✓ FastPanel installation detected" | tee -a "$LOG_FILE"
    echo "✓ Installation path: $FP_ROOT" | tee -a "$LOG_FILE"
else
    echo "? FastPanel installation not clearly detected" | tee -a "$LOG_FILE"
fi

# Count active services
ACTIVE_SERVICES=$(systemctl list-units --type=service --state=active | grep -c "fastpanel" || echo "0")
echo "✓ Active FastPanel services: $ACTIVE_SERVICES" | tee -a "$LOG_FILE"

# Count domains/sites
DOMAIN_COUNT=$(find /var/www /home/*/public_html /home/*/domains -maxdepth 1 -type d 2>/dev/null | wc -l)
echo "✓ Potential website directories found: $DOMAIN_COUNT" | tee -a "$LOG_FILE"

print_status "FastPanel analysis completed!"
print_status "Log saved to: $LOG_FILE"

echo -e "\n${GREEN}FastPanel analysis completed!${NC}"
echo "Review the log file for detailed information: $LOG_FILE"
