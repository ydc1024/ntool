#!/bin/bash

# BestHammer NTool Platform Root User Deployment Script
# This script is designed to run as root user with proper privilege handling

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

# Root user privilege management
check_root_privileges() {
    log "Checking root privileges..."

    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Use: sudo ./root-deploy.sh"
    fi

    info "✓ Running as root user"
    info "✓ Web user detected: $WEB_USER"

    # Verify web user exists
    if ! id "$WEB_USER" &>/dev/null; then
        error "Web user '$WEB_USER' does not exist. Please create it first."
    fi

    info "✓ Web user '$WEB_USER' exists"
}

# Pre-deployment environment check
check_deployment_environment() {
    log "Checking deployment environment..."

    # Check current directory contents
    info "Current directory: $(pwd)"
    info "Directory contents:"
    ls -la | head -10

    # Check for source files
    local has_source_files=false
    if [ -f "composer.json" ] && [ -d "app" ] && [ -f "artisan" ]; then
        has_source_files=true
        info "✓ Laravel source files detected"
    fi

    # Check for package files
    local package_count=$(ls -1 ntool-*.tar.gz 2>/dev/null | wc -l)
    info "Package files found: $package_count"

    # Check for packaging script
    if [ -f "package-ntool.sh" ]; then
        info "✓ Packaging script available"
    else
        warning "Packaging script not found"
    fi

    # Check essential commands
    local missing_commands=()
    for cmd in tar gzip find php mysql composer npm; do
        if ! command -v $cmd &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    if [ ${#missing_commands[@]} -gt 0 ]; then
        warning "Missing commands: ${missing_commands[*]}"
        warning "Some deployment features may not work properly"
    else
        info "✓ All essential commands available"
    fi

    # Check PHP version
    if command -v php &> /dev/null; then
        local php_version=$(php -r "echo PHP_VERSION;" 2>/dev/null)
        info "PHP version: $php_version"

        # Check PHP extensions
        local required_extensions=("pdo" "mysql" "mbstring" "xml" "curl" "zip")
        local missing_extensions=()

        for ext in "${required_extensions[@]}"; do
            if ! php -m | grep -q "^$ext$"; then
                missing_extensions+=("$ext")
            fi
        done

        if [ ${#missing_extensions[@]} -gt 0 ]; then
            warning "Missing PHP extensions: ${missing_extensions[*]}"
        else
            info "✓ Required PHP extensions available"
        fi
    fi

    # Summary
    if [ $package_count -eq 0 ] && [ "$has_source_files" = false ]; then
        error "No deployment source found. Need either package files or source files."
    fi

    log "Environment check completed"
}

# Function to find or create package file
find_package_file() {
    log "Looking for NTool package file..."

    # Look for package files in current directory
    local package_files=($(ls -1 ntool-*.tar.gz 2>/dev/null | sort -r))

    if [ ${#package_files[@]} -eq 0 ]; then
        warning "No pre-built package found. Checking for source files..."

        # Check if we have source files to package
        if [ -f "composer.json" ] && [ -d "app" ] && [ -f "artisan" ]; then
            info "Found Laravel source files in current directory"

            # Check if package-ntool.sh exists
            if [ -f "package-ntool.sh" ]; then
                log "Creating package from source files..."
                chmod +x package-ntool.sh

                # Run packaging script
                if ./package-ntool.sh; then
                    # Look for the newly created package
                    package_files=($(ls -1 ntool-*.tar.gz 2>/dev/null | sort -r))

                    if [ ${#package_files[@]} -eq 0 ]; then
                        error "Package creation failed. No package file generated."
                    fi

                    info "Package created successfully"
                else
                    error "Package creation failed. Check package-ntool.sh script."
                fi
            else
                # Create package manually if package-ntool.sh doesn't exist
                log "Creating package manually from current directory..."
                create_manual_package
            fi
        else
            error "No package file or source files found. Please ensure either:"
            error "1. ntool-*.tar.gz package file exists, OR"
            error "2. Laravel source files (composer.json, app/, artisan) exist in current directory"
        fi
    fi

    # Now we should have package files
    if [ ${#package_files[@]} -eq 1 ]; then
        PACKAGE_FILE="${package_files[0]}"
        info "Using package: $PACKAGE_FILE"
    elif [ ${#package_files[@]} -gt 1 ]; then
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
    else
        error "No package file available after creation attempt"
    fi
}

# Function to create package manually
create_manual_package() {
    log "Creating package manually from source files..."

    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local package_name="ntool-${timestamp}.tar.gz"
    local temp_dir="ntool-package-${timestamp}"

    # Create temporary package directory
    mkdir -p "$temp_dir"

    # Copy essential Laravel files and directories
    local essential_items=(
        "app" "bootstrap" "config" "database" "public" "resources"
        "routes" "storage" "tests" "composer.json" "package.json"
        "artisan" ".env.example" "README.md"
    )

    info "Copying source files to package..."
    for item in "${essential_items[@]}"; do
        if [ -e "$item" ]; then
            cp -r "$item" "$temp_dir/"
            info "✓ Copied $item"
        fi
    done

    # Create missing essential directories
    mkdir -p "$temp_dir/storage/app/public"
    mkdir -p "$temp_dir/storage/framework/cache/data"
    mkdir -p "$temp_dir/storage/framework/sessions"
    mkdir -p "$temp_dir/storage/framework/views"
    mkdir -p "$temp_dir/storage/logs"
    mkdir -p "$temp_dir/bootstrap/cache"

    # Create .gitignore files for empty directories
    echo "*" > "$temp_dir/storage/app/public/.gitignore"
    echo "!.gitignore" >> "$temp_dir/storage/app/public/.gitignore"
    echo "*" > "$temp_dir/storage/framework/cache/data/.gitignore"
    echo "!.gitignore" >> "$temp_dir/storage/framework/cache/data/.gitignore"
    echo "*" > "$temp_dir/storage/framework/sessions/.gitignore"
    echo "!.gitignore" >> "$temp_dir/storage/framework/sessions/.gitignore"
    echo "*" > "$temp_dir/storage/framework/views/.gitignore"
    echo "!.gitignore" >> "$temp_dir/storage/framework/views/.gitignore"
    echo "*" > "$temp_dir/storage/logs/.gitignore"
    echo "!.gitignore" >> "$temp_dir/storage/logs/.gitignore"
    echo "*" > "$temp_dir/bootstrap/cache/.gitignore"
    echo "!.gitignore" >> "$temp_dir/bootstrap/cache/.gitignore"

    # Set proper permissions
    find "$temp_dir" -type f -exec chmod 644 {} \;
    find "$temp_dir" -type d -exec chmod 755 {} \;
    chmod +x "$temp_dir/artisan" 2>/dev/null || true

    # Create the package
    info "Creating package archive..."
    tar -czf "$package_name" "$temp_dir"

    # Cleanup
    rm -rf "$temp_dir"

    if [ -f "$package_name" ]; then
        local package_size=$(du -h "$package_name" | cut -f1)
        info "✓ Package created: $package_name ($package_size)"
        PACKAGE_FILE="$package_name"
    else
        error "Failed to create package file"
    fi
}

# Complete backup function (root version)
create_complete_backup() {
    log "Creating complete backup of existing website..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Backup website files if they exist
    if [ -d "$WEB_ROOT" ] && [ "$(ls -A $WEB_ROOT 2>/dev/null)" ]; then
        info "Backing up website files..."
        tar -czf "${BACKUP_DIR}/${BACKUP_NAME}_files.tar.gz" -C "$WEB_ROOT" . 2>/dev/null || true
        
        local file_count=$(find "$WEB_ROOT" -type f 2>/dev/null | wc -l)
        info "Backed up $file_count files"
    else
        info "No existing website files to backup"
    fi
    
    # Backup database
    backup_database
    
    log "Backup completed: ${BACKUP_NAME}"
}

# Database backup function (root version)
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

# Complete cleanup function (root version)
perform_complete_cleanup() {
    log "Performing complete cleanup of web directory..."
    
    if [ ! -d "$WEB_ROOT" ]; then
        info "Web root doesn't exist, creating: $WEB_ROOT"
        mkdir -p "$WEB_ROOT"
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
    
    # Perform the cleanup (root version - no sudo needed)
    info "Removing all files and directories..."
    
    # Remove all contents but preserve the directory
    find "$WEB_ROOT" -mindepth 1 -delete 2>/dev/null || {
        # Fallback method
        rm -rf "$WEB_ROOT"/*
        rm -rf "$WEB_ROOT"/.[^.]*
    }
    
    log "Complete cleanup finished"
}

# Extract package function (root version)
extract_package() {
    log "Extracting NTool package..."

    # Create temporary extraction directory
    mkdir -p "$TEMP_EXTRACT_DIR"

    # Extract package
    info "Extracting $PACKAGE_FILE..."
    tar -xzf "$PACKAGE_FILE" -C "$TEMP_EXTRACT_DIR"

    # Find the extracted directory - try multiple patterns
    local extracted_dir=""

    # First try to find ntool-* directory
    extracted_dir=$(find "$TEMP_EXTRACT_DIR" -maxdepth 1 -type d -name "ntool-*" | head -1)

    # If not found, check if files were extracted directly
    if [ -z "$extracted_dir" ]; then
        # Check if Laravel files exist directly in temp directory
        if [ -f "$TEMP_EXTRACT_DIR/artisan" ] && [ -f "$TEMP_EXTRACT_DIR/composer.json" ]; then
            extracted_dir="$TEMP_EXTRACT_DIR"
            info "Package extracted directly to temp directory"
        else
            # Look for any subdirectory that contains Laravel files
            for dir in "$TEMP_EXTRACT_DIR"/*; do
                if [ -d "$dir" ] && [ -f "$dir/artisan" ] && [ -f "$dir/composer.json" ]; then
                    extracted_dir="$dir"
                    break
                fi
            done
        fi
    fi

    if [ -z "$extracted_dir" ]; then
        error "Could not find Laravel application in extracted package. Expected files: artisan, composer.json"
    fi

    info "Package extracted to: $extracted_dir"

    # Verify essential Laravel files exist
    local essential_files=("artisan" "composer.json" "app" "public" "config")
    for file in "${essential_files[@]}"; do
        if [ ! -e "$extracted_dir/$file" ]; then
            warning "Essential file/directory missing: $file"
        fi
    done

    # Copy all files to web root (root version - no sudo needed)
    log "Copying files to web root..."

    if [ "$extracted_dir" = "$TEMP_EXTRACT_DIR" ]; then
        # Files are directly in temp directory
        cp -r "$TEMP_EXTRACT_DIR"/* "$WEB_ROOT/" 2>/dev/null || true
        cp -r "$TEMP_EXTRACT_DIR"/.[^.]* "$WEB_ROOT/" 2>/dev/null || true
    else
        # Files are in a subdirectory
        cp -r "$extracted_dir"/* "$WEB_ROOT/" 2>/dev/null || true
        cp -r "$extracted_dir"/.[^.]* "$WEB_ROOT/" 2>/dev/null || true
    fi

    # Verify files were copied
    local copied_files=$(find "$WEB_ROOT" -type f 2>/dev/null | wc -l)
    if [ $copied_files -eq 0 ]; then
        error "No files were copied to web root. Check package structure."
    fi

    info "Copied $copied_files files to web root"

    # Cleanup temp directory
    rm -rf "$TEMP_EXTRACT_DIR"

    log "Files copied successfully"
}

# Set proper permissions (root version)
set_permissions() {
    log "Setting proper file permissions..."
    
    # Set ownership (root version - no sudo needed)
    chown -R $WEB_USER:$WEB_USER "$WEB_ROOT"
    
    # Set file permissions
    find "$WEB_ROOT" -type f -exec chmod 644 {} \;
    find "$WEB_ROOT" -type d -exec chmod 755 {} \;
    
    # Set special permissions for Laravel
    if [ -f "$WEB_ROOT/artisan" ]; then
        chmod +x "$WEB_ROOT/artisan"
    fi
    
    if [ -d "$WEB_ROOT/storage" ]; then
        chmod -R 775 "$WEB_ROOT/storage"
    fi
    
    if [ -d "$WEB_ROOT/bootstrap/cache" ]; then
        chmod -R 775 "$WEB_ROOT/bootstrap/cache"
    fi
    
    log "Permissions set successfully"
}

# Install dependencies (root version)
install_dependencies() {
    log "Installing project dependencies..."
    
    cd "$WEB_ROOT"
    
    # Install Composer dependencies (as web user)
    if [ -f "composer.json" ]; then
        info "Installing Composer dependencies..."
        su - $WEB_USER -c "cd '$WEB_ROOT' && composer install --no-dev --optimize-autoloader --no-interaction"
    fi
    
    # Install NPM dependencies and build assets (as web user)
    if [ -f "package.json" ]; then
        info "Installing NPM dependencies..."
        su - $WEB_USER -c "cd '$WEB_ROOT' && npm install --production"
        
        info "Building production assets..."
        su - $WEB_USER -c "cd '$WEB_ROOT' && npm run build" 2>/dev/null || su - $WEB_USER -c "cd '$WEB_ROOT' && npm run production" 2>/dev/null || true
    fi
    
    log "Dependencies installed successfully"
}

# Configure environment (root version)
configure_environment() {
    log "Configuring environment..."
    
    cd "$WEB_ROOT"
    
    # Copy .env.example to .env if .env doesn't exist
    if [ ! -f ".env" ] && [ -f ".env.example" ]; then
        su - $WEB_USER -c "cd '$WEB_ROOT' && cp '.env.example' '.env'"
        info "Created .env from .env.example"
    fi
    
    # Generate application key
    if [ -f ".env" ] && [ -f "artisan" ]; then
        su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan key:generate --force"
        info "Application key generated"
    fi
    
    # Update .env with production settings
    if [ -f ".env" ]; then
        sed -i "s|APP_ENV=.*|APP_ENV=production|g" ".env"
        sed -i "s|APP_DEBUG=.*|APP_DEBUG=false|g" ".env"
        sed -i "s|APP_URL=.*|APP_URL=https://$DOMAIN|g" ".env"
        info "Environment configured for production"
    fi
    
    log "Environment configuration completed"
}

# Setup database (root version)
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
        sed -i "s|DB_DATABASE=.*|DB_DATABASE=$db_name|g" ".env"
        sed -i "s|DB_USERNAME=.*|DB_USERNAME=$db_user|g" ".env"
        sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$db_password|g" ".env"
        info "Database credentials updated in .env"
    fi
    
    # Run migrations (as web user)
    info "Running database migrations..."
    su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan migrate --force"
    
    # Seed database (as web user)
    info "Seeding database..."
    su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan db:seed --force" 2>/dev/null || true
    
    log "Database setup completed"
}

# Optimize Laravel (root version)
optimize_laravel() {
    log "Optimizing Laravel application..."
    
    cd "$WEB_ROOT"
    
    if [ ! -f "artisan" ]; then
        warning "Laravel artisan not found, skipping optimization"
        return 0
    fi
    
    # Clear all caches (as web user)
    su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan config:clear"
    su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan route:clear"
    su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan view:clear"
    su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan cache:clear"
    
    # Cache configurations for production (as web user)
    su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan config:cache"
    su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan route:cache"
    su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan view:cache"
    
    # Create storage link (as web user)
    su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan storage:link" 2>/dev/null || true
    
    log "Laravel optimization completed"
}

# Main deployment function (root version)
main() {
    log "🚀 Starting BestHammer NTool Platform deployment (Root Mode)..."
    echo
    
    # Check root privileges
    check_root_privileges

    # Check deployment environment
    check_deployment_environment

    # Display configuration
    info "Deployment Configuration:"
    info "Domain: $DOMAIN"
    info "Web Root: $WEB_ROOT"
    info "Web User: $WEB_USER"
    info "Backup Directory: $BACKUP_DIR"
    info "Running as: root"
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
    info "- Nginx error logs: tail -f /var/log/nginx/error.log"
    info "- Laravel logs: tail -f $WEB_ROOT/storage/logs/laravel.log"
    info "- PHP-FPM logs: tail -f /var/log/php*-fpm.log"
}

# Handle script interruption
trap 'error "Deployment interrupted! Check system state and consider running rollback if needed."' INT TERM

main "$@"
