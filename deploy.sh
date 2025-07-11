#!/bin/bash

# NTool Platform Deployment Script
# This script will clean old files and deploy the new website
# Author: NTool Development Team
# Version: 1.0.0

set -e  # Exit on any error

# Configuration
DOMAIN="besthammer.club"
WEB_ROOT="/var/www/html"
BACKUP_DIR="/var/backups/website"
PROJECT_NAME="ntool"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="backup_${DOMAIN}_${TIMESTAMP}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root for security reasons"
    fi
}

# Check system requirements
check_requirements() {
    log "Checking system requirements..."
    
    # Check if required commands exist
    local required_commands=("php" "composer" "npm" "mysql" "nginx")
    for cmd in "${required_commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            error "$cmd is not installed or not in PATH"
        fi
    done
    
    # Check PHP version
    local php_version=$(php -r "echo PHP_VERSION;")
    local required_php="8.1"
    if ! php -r "exit(version_compare(PHP_VERSION, '$required_php', '>=') ? 0 : 1);"; then
        error "PHP version $required_php or higher is required. Current: $php_version"
    fi
    
    log "System requirements check passed"
}

# Create backup of existing website
create_backup() {
    log "Creating backup of existing website..."
    
    # Create backup directory
    sudo mkdir -p "$BACKUP_DIR"
    
    # Backup web files
    if [ -d "$WEB_ROOT" ]; then
        info "Backing up web files to $BACKUP_DIR/$BACKUP_NAME"
        sudo tar -czf "$BACKUP_DIR/${BACKUP_NAME}_files.tar.gz" -C "$WEB_ROOT" . 2>/dev/null || true
    fi
    
    # Backup database
    info "Backing up database..."
    local db_name="besthammer_db"  # Adjust if different
    local db_user="root"
    
    read -s -p "Enter MySQL root password: " mysql_password
    echo
    
    if mysql -u"$db_user" -p"$mysql_password" -e "USE $db_name;" 2>/dev/null; then
        mysqldump -u"$db_user" -p"$mysql_password" "$db_name" > "$BACKUP_DIR/${BACKUP_NAME}_database.sql" 2>/dev/null || warning "Database backup failed"
    else
        warning "Database $db_name not found or access denied"
    fi
    
    log "Backup completed"
}

# Clean old website files
clean_old_files() {
    log "Cleaning old website files..."
    
    # List of directories to completely remove
    local dirs_to_remove=(
        "wp-admin"
        "wp-content" 
        "wp-includes"
        "node_modules"
        "vendor"
        ".git"
        "old_site"
        "backup"
        "temp"
        "cache"
    )
    
    # List of files to remove (common old website files)
    local files_to_remove=(
        "wp-config.php"
        "wp-load.php"
        "wp-blog-header.php"
        "wp-cron.php"
        "wp-links-opml.php"
        "wp-mail.php"
        "wp-settings.php"
        "wp-signup.php"
        "wp-trackback.php"
        "xmlrpc.php"
        "license.txt"
        "readme.html"
        "index.html"
        "default.html"
        "coming-soon.html"
        ".htaccess.old"
        "robots.txt.old"
    )
    
    cd "$WEB_ROOT" || error "Cannot access web root directory"
    
    # Remove old directories
    for dir in "${dirs_to_remove[@]}"; do
        if [ -d "$dir" ]; then
            info "Removing directory: $dir"
            sudo rm -rf "$dir"
        fi
    done
    
    # Remove old files
    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            info "Removing file: $file"
            sudo rm -f "$file"
        fi
    done
    
    # Remove any PHP files that don't belong to Laravel
    local old_php_files=(
        "config.php"
        "settings.php"
        "install.php"
        "setup.php"
        "admin.php"
        "login.php"
        "register.php"
    )
    
    for file in "${old_php_files[@]}"; do
        if [ -f "$file" ]; then
            info "Removing old PHP file: $file"
            sudo rm -f "$file"
        fi
    done
    
    # Clean any remaining cache or temporary files
    sudo find . -name "*.tmp" -type f -delete 2>/dev/null || true
    sudo find . -name "*.cache" -type f -delete 2>/dev/null || true
    sudo find . -name "*.log" -type f -delete 2>/dev/null || true
    sudo find . -name ".DS_Store" -type f -delete 2>/dev/null || true
    sudo find . -name "Thumbs.db" -type f -delete 2>/dev/null || true
    
    log "Old files cleaned successfully"
}

# Deploy new website files
deploy_new_files() {
    log "Deploying new NTool Platform files..."
    
    local source_dir="$HOME/ntool"
    
    if [ ! -d "$source_dir" ]; then
        error "Source directory $source_dir not found"
    fi
    
    # Copy all files from ntool directory
    info "Copying files from $source_dir to $WEB_ROOT"
    sudo cp -rf "$source_dir"/* "$WEB_ROOT/"
    sudo cp -rf "$source_dir"/.[^.]* "$WEB_ROOT/" 2>/dev/null || true
    
    # Set proper ownership
    sudo chown -R www-data:www-data "$WEB_ROOT"
    
    # Set proper permissions
    sudo find "$WEB_ROOT" -type f -exec chmod 644 {} \;
    sudo find "$WEB_ROOT" -type d -exec chmod 755 {} \;
    
    # Set special permissions for Laravel
    sudo chmod -R 775 "$WEB_ROOT/storage"
    sudo chmod -R 775 "$WEB_ROOT/bootstrap/cache"
    
    log "Files deployed successfully"
}

# Configure environment
configure_environment() {
    log "Configuring environment..."
    
    cd "$WEB_ROOT" || error "Cannot access web root"
    
    # Copy environment file if it doesn't exist
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            sudo cp .env.example .env
            info "Created .env from .env.example"
        else
            error ".env.example file not found"
        fi
    fi
    
    # Generate application key
    sudo -u www-data php artisan key:generate --force
    
    # Configure database
    info "Configuring database connection..."
    read -p "Enter database name (default: ntool_db): " db_name
    db_name=${db_name:-ntool_db}
    
    read -p "Enter database username (default: ntool_user): " db_user
    db_user=${db_user:-ntool_user}
    
    read -s -p "Enter database password: " db_password
    echo
    
    # Update .env file
    sudo sed -i "s/DB_DATABASE=.*/DB_DATABASE=$db_name/" .env
    sudo sed -i "s/DB_USERNAME=.*/DB_USERNAME=$db_user/" .env
    sudo sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$db_password/" .env
    sudo sed -i "s/APP_URL=.*/APP_URL=https:\/\/$DOMAIN/" .env
    sudo sed -i "s/APP_ENV=.*/APP_ENV=production/" .env
    sudo sed -i "s/APP_DEBUG=.*/APP_DEBUG=false/" .env
    
    log "Environment configured"
}

# Install dependencies
install_dependencies() {
    log "Installing dependencies..."
    
    cd "$WEB_ROOT" || error "Cannot access web root"
    
    # Install PHP dependencies
    info "Installing Composer dependencies..."
    sudo -u www-data composer install --no-dev --optimize-autoloader --no-interaction
    
    # Install Node.js dependencies and build assets
    if [ -f "package.json" ]; then
        info "Installing NPM dependencies..."
        sudo -u www-data npm install --production
        
        info "Building production assets..."
        sudo -u www-data npm run build
    fi
    
    log "Dependencies installed successfully"
}

# Setup database
setup_database() {
    log "Setting up database..."
    
    cd "$WEB_ROOT" || error "Cannot access web root"
    
    # Create database if it doesn't exist
    local db_name=$(grep "DB_DATABASE=" .env | cut -d'=' -f2)
    local db_user=$(grep "DB_USERNAME=" .env | cut -d'=' -f2)
    local db_password=$(grep "DB_PASSWORD=" .env | cut -d'=' -f2)
    
    read -s -p "Enter MySQL root password: " mysql_root_password
    echo
    
    # Create database and user
    mysql -uroot -p"$mysql_root_password" -e "CREATE DATABASE IF NOT EXISTS $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || warning "Database creation failed"
    mysql -uroot -p"$mysql_root_password" -e "CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_password';" || warning "User creation failed"
    mysql -uroot -p"$mysql_root_password" -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';" || warning "Grant privileges failed"
    mysql -uroot -p"$mysql_root_password" -e "FLUSH PRIVILEGES;" || warning "Flush privileges failed"
    
    # Run migrations
    info "Running database migrations..."
    sudo -u www-data php artisan migrate --force
    
    # Seed database
    info "Seeding database..."
    sudo -u www-data php artisan db:seed --force
    
    log "Database setup completed"
}

# Configure web server
configure_webserver() {
    log "Configuring web server..."
    
    # Create Nginx configuration
    local nginx_config="/etc/nginx/sites-available/$DOMAIN"
    
    sudo tee "$nginx_config" > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;
    
    root $WEB_ROOT/public;
    index index.php index.html;
    
    # SSL Configuration (adjust paths as needed)
    ssl_certificate /etc/ssl/certs/$DOMAIN.crt;
    ssl_certificate_key /etc/ssl/private/$DOMAIN.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }
    
    location ~ /\.(?!well-known).* {
        deny all;
    }
    
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
    
    # Enable site
    sudo ln -sf "$nginx_config" "/etc/nginx/sites-enabled/$DOMAIN"
    
    # Remove default site if exists
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Test Nginx configuration
    sudo nginx -t || error "Nginx configuration test failed"
    
    # Reload Nginx
    sudo systemctl reload nginx
    
    log "Web server configured successfully"
}

# Optimize Laravel
optimize_laravel() {
    log "Optimizing Laravel application..."
    
    cd "$WEB_ROOT" || error "Cannot access web root"
    
    # Clear all caches
    sudo -u www-data php artisan config:clear
    sudo -u www-data php artisan route:clear
    sudo -u www-data php artisan view:clear
    sudo -u www-data php artisan cache:clear
    
    # Cache configurations for production
    sudo -u www-data php artisan config:cache
    sudo -u www-data php artisan route:cache
    sudo -u www-data php artisan view:cache
    
    # Create storage link
    sudo -u www-data php artisan storage:link
    
    log "Laravel optimization completed"
}

# Setup cron jobs
setup_cron() {
    log "Setting up cron jobs..."
    
    # Add Laravel scheduler to crontab
    local cron_entry="* * * * * cd $WEB_ROOT && php artisan schedule:run >> /dev/null 2>&1"
    
    # Check if cron entry already exists
    if ! sudo -u www-data crontab -l 2>/dev/null | grep -q "artisan schedule:run"; then
        (sudo -u www-data crontab -l 2>/dev/null; echo "$cron_entry") | sudo -u www-data crontab -
        info "Cron job added for Laravel scheduler"
    else
        info "Cron job already exists"
    fi
    
    log "Cron jobs configured"
}

# Final checks
final_checks() {
    log "Performing final checks..."
    
    cd "$WEB_ROOT" || error "Cannot access web root"
    
    # Check if application is accessible
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost" | grep -q "200\|301\|302"; then
        info "✓ Application is accessible"
    else
        warning "Application may not be accessible"
    fi
    
    # Check file permissions
    if [ -w "storage" ] && [ -w "bootstrap/cache" ]; then
        info "✓ File permissions are correct"
    else
        warning "File permissions may need adjustment"
    fi
    
    # Check database connection
    if sudo -u www-data php artisan migrate:status > /dev/null 2>&1; then
        info "✓ Database connection is working"
    else
        warning "Database connection may have issues"
    fi
    
    log "Final checks completed"
}

# Main deployment function
main() {
    log "Starting NTool Platform deployment..."
    
    check_root
    check_requirements
    
    echo
    warning "This script will:"
    warning "1. Backup existing website and database"
    warning "2. Remove old website files"
    warning "3. Deploy new NTool Platform"
    warning "4. Configure environment and database"
    warning "5. Setup web server configuration"
    echo
    
    read -p "Do you want to continue? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        info "Deployment cancelled"
        exit 0
    fi
    
    create_backup
    clean_old_files
    deploy_new_files
    configure_environment
    install_dependencies
    setup_database
    configure_webserver
    optimize_laravel
    setup_cron
    final_checks
    
    log "🎉 NTool Platform deployment completed successfully!"
    info "Website URL: https://$DOMAIN"
    info "Backup location: $BACKUP_DIR/$BACKUP_NAME"
    info "Please test all functionality and check logs for any issues"
}

# Run main function
main "$@"
