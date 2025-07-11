#!/bin/bash

# BestHammer NTool Platform Complete Deployment Script
# This script performs complete cleanup and deployment with package extraction

set -e

# Configuration
DOMAIN="besthammer.club"
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
BACKUP_DIR="/var/backups/website"
PROJECT_NAME="ntool"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="backup_${DOMAIN}_${TIMESTAMP}"
TEMP_EXTRACT_DIR="/tmp/ntool_deploy_${TIMESTAMP}"
PACKAGE_FILE=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Detect FastPanel user
detect_web_user() {
    if [ -d "/usr/local/fastpanel" ] || [ -f "/etc/nginx/fastpanel.conf" ]; then
        if id "besthammer_c_usr" &>/dev/null; then
            echo "besthammer_c_usr"
            return 0
        fi
        local domain_user=$(echo "$DOMAIN" | sed 's/\./_/g')
        if id "$domain_user" &>/dev/null; then
            echo "$domain_user"
            return 0
        fi
    fi
    echo "www-data"
}

WEB_USER=$(detect_web_user)

# Function to find package file
find_package_file() {
    log "Looking for NTool package file..."
    
    # Look for package files in current directory
    local package_files=($(ls -1 ntool-*.tar.gz 2>/dev/null | sort -r))
    
    if [ ${#package_files[@]} -eq 0 ]; then
        error "No NTool package file found. Please ensure ntool-*.tar.gz exists in current directory."
    fi
    
    if [ ${#package_files[@]} -eq 1 ]; then
        PACKAGE_FILE="${package_files[0]}"
        info "Found package: $PACKAGE_FILE"
    else
        echo "Multiple package files found:"
        for i in "${!package_files[@]}"; do
            echo "$((i+1)). ${package_files[$i]}"
        done
        
        read -p "Select package to deploy (1-${#package_files[@]}): " selection
        
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#package_files[@]}" ]; then
            error "Invalid selection"
        fi
        
        PACKAGE_FILE="${package_files[$((selection-1))]}"
        info "Selected package: $PACKAGE_FILE"
    fi
}

# Complete backup function
create_complete_backup() {
    log "Creating complete backup of existing website..."
    
    # Create backup directory
    sudo mkdir -p "$BACKUP_DIR"
    
    # Backup website files if they exist
    if [ -d "$WEB_ROOT" ] && [ "$(ls -A $WEB_ROOT 2>/dev/null)" ]; then
        info "Backing up website files..."
        sudo tar -czf "${BACKUP_DIR}/${BACKUP_NAME}_files.tar.gz" -C "$WEB_ROOT" . 2>/dev/null || true
        
        local file_count=$(find "$WEB_ROOT" -type f 2>/dev/null | wc -l)
        info "Backed up $file_count files"
    else
        info "No existing website files to backup"
    fi
    
    # Backup database
    backup_database
    
    log "Backup completed: ${BACKUP_NAME}"
}

# Database backup function
backup_database() {
    log "Backing up database..."
    
    read -s -p "Enter MySQL root password (or press Enter to skip database backup): " mysql_password
    echo
    
    if [ -n "$mysql_password" ]; then
        local databases=("besthammer_db" "ntool_db" "${DOMAIN//./_}")
        
        for db_name in "${databases[@]}"; do
            if mysql -uroot -p"$mysql_password" -e "USE $db_name;" 2>/dev/null; then
                info "Backing up database: $db_name"
                mysqldump -uroot -p"$mysql_password" "$db_name" > "${BACKUP_DIR}/${BACKUP_NAME}_${db_name}.sql" 2>/dev/null || true
                break
            fi
        done
    else
        warning "Database backup skipped"
    fi
}

# Complete cleanup function
perform_complete_cleanup() {
    log "Performing complete cleanup of web directory..."
    
    if [ ! -d "$WEB_ROOT" ]; then
        info "Web root doesn't exist, creating: $WEB_ROOT"
        sudo mkdir -p "$WEB_ROOT"
        return 0
    fi
    
    # List what will be removed
    local file_count=$(find "$WEB_ROOT" -type f 2>/dev/null | wc -l)
    local dir_count=$(find "$WEB_ROOT" -mindepth 1 -type d 2>/dev/null | wc -l)
    
    if [ $file_count -eq 0 ] && [ $dir_count -eq 0 ]; then
        info "Web root is already empty"
        return 0
    fi
    
    warning "This will remove $file_count files and $dir_count directories from $WEB_ROOT"
    
    # Show some examples of what will be removed
    info "Examples of files that will be removed:"
    find "$WEB_ROOT" -type f 2>/dev/null | head -10 | while read file; do
        echo "  - ${file#$WEB_ROOT/}"
    done
    
    if [ $file_count -gt 10 ]; then
        echo "  ... and $((file_count - 10)) more files"
    fi
    
    echo
    read -p "Continue with complete cleanup? (type 'yes' to confirm): " confirm
    
    if [ "$confirm" != "yes" ]; then
        error "Cleanup cancelled by user"
    fi
    
    # Perform the cleanup
    info "Removing all files and directories..."
    
    # Remove all contents but preserve the directory
    sudo find "$WEB_ROOT" -mindepth 1 -delete 2>/dev/null || {
        # Fallback method
        sudo rm -rf "$WEB_ROOT"/*
        sudo rm -rf "$WEB_ROOT"/.[^.]*
    }
    
    log "Complete cleanup finished"
}

# Extract package function
extract_package() {
    log "Extracting NTool package..."
    
    # Create temporary extraction directory
    mkdir -p "$TEMP_EXTRACT_DIR"
    
    # Extract package
    info "Extracting $PACKAGE_FILE..."
    tar -xzf "$PACKAGE_FILE" -C "$TEMP_EXTRACT_DIR"
    
    # Find the extracted directory
    local extracted_dir=$(find "$TEMP_EXTRACT_DIR" -maxdepth 1 -type d -name "ntool-*" | head -1)
    
    if [ -z "$extracted_dir" ]; then
        error "Could not find extracted ntool directory"
    fi
    
    info "Package extracted to: $extracted_dir"
    
    # Copy all files to web root
    log "Copying files to web root..."
    sudo cp -r "$extracted_dir"/* "$WEB_ROOT/"
    sudo cp -r "$extracted_dir"/.[^.]* "$WEB_ROOT/" 2>/dev/null || true
    
    # Cleanup temp directory
    rm -rf "$TEMP_EXTRACT_DIR"
    
    log "Files copied successfully"
}

# Set proper permissions
set_permissions() {
    log "Setting proper file permissions..."
    
    # Set ownership
    sudo chown -R $WEB_USER:$WEB_USER "$WEB_ROOT"
    
    # Set file permissions
    sudo find "$WEB_ROOT" -type f -exec chmod 644 {} \;
    sudo find "$WEB_ROOT" -type d -exec chmod 755 {} \;
    
    # Set special permissions for Laravel
    if [ -f "$WEB_ROOT/artisan" ]; then
        sudo chmod +x "$WEB_ROOT/artisan"
    fi
    
    if [ -d "$WEB_ROOT/storage" ]; then
        sudo chmod -R 775 "$WEB_ROOT/storage"
    fi
    
    if [ -d "$WEB_ROOT/bootstrap/cache" ]; then
        sudo chmod -R 775 "$WEB_ROOT/bootstrap/cache"
    fi
    
    log "Permissions set successfully"
}

# Install dependencies
install_dependencies() {
    log "Installing project dependencies..."
    
    cd "$WEB_ROOT"
    
    # Install Composer dependencies
    if [ -f "composer.json" ]; then
        info "Installing Composer dependencies..."
        sudo -u $WEB_USER composer install --no-dev --optimize-autoloader --no-interaction
    fi
    
    # Install NPM dependencies and build assets
    if [ -f "package.json" ]; then
        info "Installing NPM dependencies..."
        sudo -u $WEB_USER npm install --production
        
        info "Building production assets..."
        sudo -u $WEB_USER npm run build 2>/dev/null || sudo -u $WEB_USER npm run production 2>/dev/null || true
    fi
    
    log "Dependencies installed successfully"
}

# Configure environment
configure_environment() {
    log "Configuring environment..."
    
    cd "$WEB_ROOT"
    
    # Copy .env.example to .env if .env doesn't exist
    if [ ! -f ".env" ] && [ -f ".env.example" ]; then
        sudo -u $WEB_USER cp ".env.example" ".env"
        info "Created .env from .env.example"
    fi
    
    # Generate application key
    if [ -f ".env" ] && [ -f "artisan" ]; then
        sudo -u $WEB_USER php artisan key:generate --force
        info "Application key generated"
    fi
    
    # Update .env with production settings
    if [ -f ".env" ]; then
        sudo -u $WEB_USER sed -i "s|APP_ENV=.*|APP_ENV=production|g" ".env"
        sudo -u $WEB_USER sed -i "s|APP_DEBUG=.*|APP_DEBUG=false|g" ".env"
        sudo -u $WEB_USER sed -i "s|APP_URL=.*|APP_URL=https://$DOMAIN|g" ".env"
        info "Environment configured for production"
    fi
    
    log "Environment configuration completed"
}

# Setup database
setup_database() {
    log "Setting up database..."
    
    cd "$WEB_ROOT"
    
    if [ ! -f "artisan" ]; then
        warning "Laravel artisan not found, skipping database setup"
        return 0
    fi
    
    read -s -p "Enter MySQL root password for database setup (or press Enter to skip): " mysql_password
    echo
    
    if [ -z "$mysql_password" ]; then
        warning "Database setup skipped"
        return 0
    fi
    
    # Create database and user
    local db_name="besthammer_db"
    local db_user="besthammer_user"
    local db_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    info "Creating database: $db_name"
    mysql -uroot -p"$mysql_password" -e "CREATE DATABASE IF NOT EXISTS $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || true
    mysql -uroot -p"$mysql_password" -e "CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_password';" 2>/dev/null || true
    mysql -uroot -p"$mysql_password" -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';" 2>/dev/null || true
    mysql -uroot -p"$mysql_password" -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    
    # Update .env with database credentials
    if [ -f ".env" ]; then
        sudo -u $WEB_USER sed -i "s|DB_DATABASE=.*|DB_DATABASE=$db_name|g" ".env"
        sudo -u $WEB_USER sed -i "s|DB_USERNAME=.*|DB_USERNAME=$db_user|g" ".env"
        sudo -u $WEB_USER sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$db_password|g" ".env"
        info "Database credentials updated in .env"
    fi
    
    # Run migrations
    info "Running database migrations..."
    sudo -u $WEB_USER php artisan migrate --force
    
    # Seed database
    info "Seeding database..."
    sudo -u $WEB_USER php artisan db:seed --force 2>/dev/null || true
    
    log "Database setup completed"
}

# Optimize Laravel
optimize_laravel() {
    log "Optimizing Laravel application..."
    
    cd "$WEB_ROOT"
    
    if [ ! -f "artisan" ]; then
        warning "Laravel artisan not found, skipping optimization"
        return 0
    fi
    
    # Clear all caches
    sudo -u $WEB_USER php artisan config:clear
    sudo -u $WEB_USER php artisan route:clear
    sudo -u $WEB_USER php artisan view:clear
    sudo -u $WEB_USER php artisan cache:clear
    
    # Cache configurations for production
    sudo -u $WEB_USER php artisan config:cache
    sudo -u $WEB_USER php artisan route:cache
    sudo -u $WEB_USER php artisan view:cache
    
    # Create storage link
    sudo -u $WEB_USER php artisan storage:link 2>/dev/null || true
    
    log "Laravel optimization completed"
}

# Main deployment function
main() {
    log "🚀 Starting BestHammer NTool Platform deployment..."
    echo
    
    # Check if running as non-root
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root for security reasons"
    fi
    
    # Display configuration
    info "Deployment Configuration:"
    info "Domain: $DOMAIN"
    info "Web Root: $WEB_ROOT"
    info "Web User: $WEB_USER"
    info "Backup Directory: $BACKUP_DIR"
    echo
    
    warning "This deployment will:"
    warning "1. Create a complete backup of existing website"
    warning "2. COMPLETELY REMOVE all files from web directory"
    warning "3. Extract and deploy new NTool platform"
    warning "4. Configure environment and database"
    warning "5. Set up all dependencies and optimizations"
    echo
    
    read -p "Do you want to proceed with the deployment? (type 'yes' to confirm): " confirm
    if [ "$confirm" != "yes" ]; then
        info "Deployment cancelled by user"
        exit 0
    fi
    
    # Find package file
    find_package_file
    
    # Execute deployment steps
    create_complete_backup
    perform_complete_cleanup
    extract_package
    set_permissions
    install_dependencies
    configure_environment
    setup_database
    optimize_laravel
    
    log "🎉 BestHammer NTool Platform deployment completed successfully!"
    echo
    info "Website URL: https://$DOMAIN"
    info "Backup created: ${BACKUP_NAME}"
    info "Web User: $WEB_USER"
    echo
    info "Next steps:"
    info "1. Configure your domain DNS if needed"
    info "2. Set up SSL certificate if not already done"
    info "3. Test all calculator functions"
    info "4. Review privacy and compliance settings"
    echo
    info "For troubleshooting, check:"
    info "- Nginx error logs: sudo tail -f /var/log/nginx/error.log"
    info "- Laravel logs: sudo tail -f $WEB_ROOT/storage/logs/laravel.log"
    info "- PHP-FPM logs: sudo tail -f /var/log/php*-fpm.log"
}

# Handle script interruption
trap 'error "Deployment interrupted! Check system state and consider running rollback if needed."' INT TERM

main "$@"
