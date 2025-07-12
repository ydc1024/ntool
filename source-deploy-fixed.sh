#!/bin/bash

# BestHammer NTool Platform Source File Deployment Script - Fixed Version
# This script deploys directly from source files with comprehensive error handling

set -e

# Configuration
DOMAIN="besthammer.club"
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
BACKUP_DIR="/var/backups/website"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="backup_${DOMAIN}_${TIMESTAMP}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }

# Detect web user
detect_web_user() {
    if [ -d "/usr/local/fastpanel" ] || [ -f "/etc/nginx/fastpanel.conf" ]; then
        if id "besthammer_c_usr" &>/dev/null; then
            echo "besthammer_c_usr"
            return 0
        fi
    fi
    echo "www-data"
}

WEB_USER=$(detect_web_user)

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Use: sudo ./source-deploy-fixed.sh"
fi

# Check system requirements
check_requirements() {
    log "Checking system requirements..."
    
    # Check essential commands
    local missing_commands=()
    for cmd in php mysql tar find; do
        if ! command -v $cmd &>/dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        error "Missing required commands: ${missing_commands[*]}"
    fi
    
    # Check PHP version
    if command -v php &>/dev/null; then
        local php_version=$(php -r "echo PHP_VERSION;" 2>/dev/null)
        local php_major=$(echo $php_version | cut -d'.' -f1)
        local php_minor=$(echo $php_version | cut -d'.' -f2)
        
        if [ "$php_major" -lt 8 ] || ([ "$php_major" -eq 8 ] && [ "$php_minor" -lt 1 ]); then
            error "PHP 8.1+ required. Current version: $php_version"
        fi
        
        info "✓ PHP version: $php_version"
    fi
    
    # Check MySQL service
    if ! systemctl is-active --quiet mysql; then
        warning "MySQL service not running. Starting MySQL..."
        systemctl start mysql
        sleep 3
        
        if ! systemctl is-active --quiet mysql; then
            error "Failed to start MySQL service"
        fi
    fi
    
    info "✓ System requirements verified"
}

# Banner
echo "🔨 BestHammer NTool Platform - Source File Deployment (Fixed)"
echo "============================================================"
echo

# Check requirements first
check_requirements

log "Detecting and checking source files..."

# Store original directory
ORIGINAL_DIR=$(pwd)

# Detect source location with debugging
SOURCE_DIR=""

info "Debugging source detection..."
info "Current directory: $(pwd)"
info "Files in current directory:"
ls -la | head -10

# Test each condition separately for debugging
info "Testing composer.json..."
if [ -f "composer.json" ]; then
    info "✓ composer.json found"
else
    info "✗ composer.json NOT found"
fi

info "Testing app directory..."
if [ -d "app" ]; then
    info "✓ app directory found"
else
    info "✗ app directory NOT found"
fi

info "Testing artisan file..."
if [ -f "artisan" ]; then
    info "✓ artisan found"
else
    info "✗ artisan NOT found"
fi

# Now test combined condition
if [ -f "composer.json" ] && [ -d "app" ] && [ -f "artisan" ]; then
    SOURCE_DIR="$ORIGINAL_DIR"
    log "✓ Laravel source files found in current directory"
    info "Source directory set to: $SOURCE_DIR"
elif [ -d "ntool" ] && [ -f "ntool/composer.json" ] && [ -d "ntool/app" ] && [ -f "ntool/artisan" ]; then
    SOURCE_DIR="$ORIGINAL_DIR/ntool"
    log "✓ Laravel source files found in ntool directory"
    info "Source directory set to: $SOURCE_DIR"
else
    error "Laravel source files not found after debugging."
    error "Please check the debug output above."
    error "Current directory: $(pwd)"
    error "Required files: composer.json, app/, artisan"
fi

# Verify essential Laravel files and directories
ESSENTIAL_DIRS=("app" "config" "database" "public" "resources" "routes")
ESSENTIAL_FILES=("composer.json" "artisan")
MISSING_ITEMS=()

for dir in "${ESSENTIAL_DIRS[@]}"; do
    if [ ! -d "$SOURCE_DIR/$dir" ]; then
        MISSING_ITEMS+=("directory: $dir")
    fi
done

for file in "${ESSENTIAL_FILES[@]}"; do
    if [ ! -f "$SOURCE_DIR/$file" ]; then
        MISSING_ITEMS+=("file: $file")
    fi
done

if [ ${#MISSING_ITEMS[@]} -gt 0 ]; then
    error "Missing essential Laravel components:"
    for item in "${MISSING_ITEMS[@]}"; do
        error "  - $item"
    done
    exit 1
fi

info "✓ All essential Laravel components verified"
info "✓ Web user: $WEB_USER"
info "✓ Source directory: $SOURCE_DIR"

# Show what will be deployed
FILE_COUNT=$(find "$SOURCE_DIR" -type f -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/vendor/*" -not -path "*/storage/logs/*" | wc -l)
DIR_COUNT=$(find "$SOURCE_DIR" -type d -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/vendor/*" | wc -l)
info "Source files to deploy: $FILE_COUNT files in $DIR_COUNT directories"

echo
warning "This deployment will:"
warning "• Backup existing website"
warning "• COMPLETELY REMOVE all current files"
warning "• Deploy source files directly"
warning "• Install dependencies and configure"
echo

read -p "Continue with source deployment? (type 'yes'): " confirm
if [ "$confirm" != "yes" ]; then
    info "Deployment cancelled"
    exit 0
fi

# Create backup
log "Creating backup..."
mkdir -p "$BACKUP_DIR"

if [ -d "$WEB_ROOT" ] && [ "$(ls -A $WEB_ROOT 2>/dev/null)" ]; then
    tar -czf "${BACKUP_DIR}/${BACKUP_NAME}_files.tar.gz" -C "$WEB_ROOT" . 2>/dev/null || true
    info "Files backed up to: ${BACKUP_NAME}_files.tar.gz"
fi

# Clear web root
log "Clearing web directory..."
if [ -d "$WEB_ROOT" ]; then
    find "$WEB_ROOT" -mindepth 1 -delete 2>/dev/null || {
        rm -rf "$WEB_ROOT"/*
        rm -rf "$WEB_ROOT"/.[^.]*
    }
else
    mkdir -p "$WEB_ROOT"
fi

# Copy source files with comprehensive approach
log "Copying source files to FastPanel web root..."

# Copy essential Laravel directories
log "Copying core Laravel directories..."
CORE_DIRS=("app" "bootstrap" "config" "database" "public" "resources" "routes")

for dir in "${CORE_DIRS[@]}"; do
    if [ -d "$SOURCE_DIR/$dir" ]; then
        info "Copying directory: $dir"
        cp -r "$SOURCE_DIR/$dir" "$WEB_ROOT/"
        
        # Verify copy
        if [ -d "$WEB_ROOT/$dir" ]; then
            file_count=$(find "$SOURCE_DIR/$dir" -type f | wc -l)
            copied_count=$(find "$WEB_ROOT/$dir" -type f | wc -l)
            info "✓ $dir: $copied_count/$file_count files copied"
        else
            error "Failed to copy directory: $dir"
        fi
    else
        warning "Directory not found: $dir"
    fi
done

# Copy storage directory with special handling
log "Setting up storage directory..."
if [ -d "$SOURCE_DIR/storage" ]; then
    cp -r "$SOURCE_DIR/storage" "$WEB_ROOT/"
    # Clean up any existing logs
    rm -rf "$WEB_ROOT/storage/logs"/*
    info "✓ Storage directory copied and cleaned"
else
    warning "Storage directory not found - will create basic structure"
fi

# Copy tests directory if it exists
if [ -d "$SOURCE_DIR/tests" ]; then
    cp -r "$SOURCE_DIR/tests" "$WEB_ROOT/"
    info "✓ Tests directory copied"
fi

# Copy essential Laravel files
log "Copying essential Laravel files..."
ESSENTIAL_FILES=("composer.json" "artisan")

for file in "${ESSENTIAL_FILES[@]}"; do
    if [ -f "$SOURCE_DIR/$file" ]; then
        cp "$SOURCE_DIR/$file" "$WEB_ROOT/"
        info "✓ Copied: $file"
    else
        error "Essential file missing: $file"
    fi
done

# Copy configuration and build files
log "Copying configuration files..."
CONFIG_FILES=("package.json" ".env.example" "vite.config.js" "tailwind.config.js")

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$SOURCE_DIR/$file" ]; then
        cp "$SOURCE_DIR/$file" "$WEB_ROOT/"
        info "✓ Copied: $file"
    else
        info "Optional file not found: $file"
    fi
done

# Copy additional optional files
OPTIONAL_FILES=("README.md" "webpack.mix.js" "phpunit.xml" ".gitignore" ".editorconfig")
for file in "${OPTIONAL_FILES[@]}"; do
    if [ -f "$SOURCE_DIR/$file" ]; then
        cp "$SOURCE_DIR/$file" "$WEB_ROOT/"
        info "✓ Copied: $file"
    fi
done

# Verify total files copied
total_copied=$(find "$WEB_ROOT" -type f | wc -l)
info "✓ Total files copied: $total_copied"

# Ensure complete Laravel directory structure
log "Ensuring complete Laravel directory structure..."

# Create missing storage subdirectories
STORAGE_DIRS=(
    "storage/app/public"
    "storage/framework/cache/data"
    "storage/framework/sessions"
    "storage/framework/views"
    "storage/framework/testing"
    "storage/logs"
    "bootstrap/cache"
)

for dir in "${STORAGE_DIRS[@]}"; do
    mkdir -p "$WEB_ROOT/$dir"
    info "✓ Created: $dir"
done

# Create Laravel .gitignore files
log "Creating Laravel .gitignore files..."

# Storage .gitignore files
cat > "$WEB_ROOT/storage/app/.gitignore" << 'EOF'
*
!public/
!.gitignore
EOF

cat > "$WEB_ROOT/storage/app/public/.gitignore" << 'EOF'
*
!.gitignore
EOF

cat > "$WEB_ROOT/storage/framework/cache/data/.gitignore" << 'EOF'
*
!.gitignore
EOF

cat > "$WEB_ROOT/storage/framework/sessions/.gitignore" << 'EOF'
*
!.gitignore
EOF

cat > "$WEB_ROOT/storage/framework/views/.gitignore" << 'EOF'
*
!.gitignore
EOF

cat > "$WEB_ROOT/storage/logs/.gitignore" << 'EOF'
*
!.gitignore
EOF

cat > "$WEB_ROOT/bootstrap/cache/.gitignore" << 'EOF'
*
!.gitignore
EOF

info "✓ Laravel .gitignore files created"

# Set comprehensive FastPanel permissions
log "Setting FastPanel-optimized permissions..."

# Set ownership to FastPanel web user
chown -R $WEB_USER:$WEB_USER "$WEB_ROOT"
info "✓ Set ownership to $WEB_USER:$WEB_USER"

# Set base file and directory permissions
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
info "✓ Set base permissions (files: 644, directories: 755)"

# Set executable permissions for Laravel artisan
if [ -f "$WEB_ROOT/artisan" ]; then
    chmod +x "$WEB_ROOT/artisan"
    info "✓ Made artisan executable"
fi

# Set special permissions for Laravel writable directories
WRITABLE_DIRS=("storage" "bootstrap/cache")
for dir in "${WRITABLE_DIRS[@]}"; do
    if [ -d "$WEB_ROOT/$dir" ]; then
        chmod -R 775 "$WEB_ROOT/$dir"
        chown -R $WEB_USER:$WEB_USER "$WEB_ROOT/$dir"
        info "✓ Set writable permissions for $dir"
    fi
done

# Verify critical permissions
log "Verifying critical permissions..."
if [ -w "$WEB_ROOT/storage" ] && [ -w "$WEB_ROOT/bootstrap/cache" ]; then
    info "✓ Laravel writable directories are accessible"
else
    warning "Some Laravel directories may not be writable"
fi

# Test web user access
if sudo -u $WEB_USER test -r "$WEB_ROOT/composer.json"; then
    info "✓ Web user can read application files"
else
    warning "Web user may not have proper read access"
fi

if sudo -u $WEB_USER test -w "$WEB_ROOT/storage"; then
    info "✓ Web user can write to storage directory"
else
    warning "Web user may not have proper write access to storage"
fi

# Install dependencies with error checking
log "Installing dependencies..."
cd "$WEB_ROOT"

# Check and install Composer dependencies
if [ -f "composer.json" ]; then
    if command -v composer &>/dev/null; then
        info "Installing Composer dependencies..."
        if su - $WEB_USER -c "cd '$WEB_ROOT' && composer install --no-dev --optimize-autoloader --no-interaction"; then
            info "✓ Composer dependencies installed successfully"
        else
            warning "Composer installation failed - continuing without dependencies"
        fi
    else
        warning "Composer not found - skipping PHP dependencies"
    fi
else
    warning "composer.json not found - skipping PHP dependencies"
fi

# Check and install NPM dependencies
if [ -f "package.json" ]; then
    if command -v npm &>/dev/null; then
        info "Installing NPM dependencies..."
        if su - $WEB_USER -c "cd '$WEB_ROOT' && npm install --production"; then
            info "✓ NPM dependencies installed successfully"

            # Try to build assets
            info "Building production assets..."
            if su - $WEB_USER -c "cd '$WEB_ROOT' && npm run build" 2>/dev/null; then
                info "✓ Assets built with 'npm run build'"
            elif su - $WEB_USER -c "cd '$WEB_ROOT' && npm run production" 2>/dev/null; then
                info "✓ Assets built with 'npm run production'"
            else
                warning "Asset building failed - frontend may not work properly"
            fi
        else
            warning "NPM installation failed - continuing without frontend dependencies"
        fi
    else
        warning "NPM not found - skipping frontend dependencies"
    fi
else
    warning "package.json not found - skipping frontend dependencies"
fi

# Configure environment
log "Configuring environment..."
if [ ! -f ".env" ] && [ -f ".env.example" ]; then
    su - $WEB_USER -c "cd '$WEB_ROOT' && cp '.env.example' '.env'"
    info "✓ Created .env from .env.example"
fi

if [ -f ".env" ]; then
    sed -i "s|APP_ENV=.*|APP_ENV=production|g" ".env"
    sed -i "s|APP_DEBUG=.*|APP_DEBUG=false|g" ".env"
    sed -i "s|APP_URL=.*|APP_URL=https://$DOMAIN|g" ".env"
    info "✓ Environment configured for production"
fi

# Generate app key
if [ -f "artisan" ]; then
    if su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan key:generate --force"; then
        info "✓ Application key generated"
    else
        warning "Application key generation failed"
    fi
fi

# Enhanced database setup with secure password handling
log "Setting up database with FastPanel integration..."

echo
info "Database Setup Options:"
echo "1. Create new database automatically (recommended)"
echo "2. Use existing database"
echo "3. Skip database setup"
echo

read -p "Select option (1-3) [default: 1]: " db_option
db_option=${db_option:-1}

case $db_option in
    1)
        # Create new database with secure password handling
        read -s -p "Enter MySQL root password: " mysql_password
        echo

        if [ -z "$mysql_password" ]; then
            warning "Database setup skipped - no password provided"
        else
            # Create temporary MySQL config file for secure authentication
            MYSQL_CONFIG=$(mktemp)
            cat > "$MYSQL_CONFIG" << EOF
[client]
user=root
password=$mysql_password
EOF
            chmod 600 "$MYSQL_CONFIG"

            # Test connection
            if mysql --defaults-file="$MYSQL_CONFIG" -e "SELECT 1;" &>/dev/null; then
                DB_NAME="besthammer_db"
                DB_USER="besthammer_user"
                DB_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

                info "Creating database: $DB_NAME"
                mysql --defaults-file="$MYSQL_CONFIG" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || error "Failed to create database"
                mysql --defaults-file="$MYSQL_CONFIG" -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';" || error "Failed to create user"
                mysql --defaults-file="$MYSQL_CONFIG" -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';" || error "Failed to grant privileges"
                mysql --defaults-file="$MYSQL_CONFIG" -e "FLUSH PRIVILEGES;" || error "Failed to flush privileges"

                # Update .env
                if [ -f ".env" ]; then
                    sed -i "s|DB_DATABASE=.*|DB_DATABASE=$DB_NAME|g" ".env"
                    sed -i "s|DB_USERNAME=.*|DB_USERNAME=$DB_USER|g" ".env"
                    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|g" ".env"
                    sed -i "s|DB_HOST=.*|DB_HOST=127.0.0.1|g" ".env"
                    sed -i "s|DB_PORT=.*|DB_PORT=3306|g" ".env"
                fi

                # Save credentials securely
                cat > "/root/besthammer-db-credentials.txt" << EOF
BestHammer Database Credentials
==============================
Database: $DB_NAME
User: $DB_USER
Password: $DB_PASS
Host: localhost
Port: 3306
Created: $(date)
EOF
                chmod 600 "/root/besthammer-db-credentials.txt"
                info "Database credentials saved to /root/besthammer-db-credentials.txt"

                # Run migrations
                info "Running database migrations..."
                if su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan migrate --force"; then
                    info "✓ Database migrations completed"

                    # Run seeders
                    if su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan db:seed --force" 2>/dev/null; then
                        info "✓ Database seeding completed"
                    else
                        info "Database seeding skipped (no seeders or already seeded)"
                    fi
                else
                    warning "Migration failed - database may not be properly configured"
                fi

                log "Database setup completed: $DB_NAME"
            else
                error "Failed to connect to MySQL with provided password"
            fi

            # Clean up temporary config file
            rm -f "$MYSQL_CONFIG"
        fi
        ;;
    2)
        # Use existing database
        read -p "Enter database name: " DB_NAME
        read -p "Enter database user: " DB_USER
        read -s -p "Enter database password: " DB_PASS
        echo

        if [ -n "$DB_NAME" ] && [ -n "$DB_USER" ] && [ -n "$DB_PASS" ]; then
            # Create temporary config for testing
            MYSQL_CONFIG=$(mktemp)
            cat > "$MYSQL_CONFIG" << EOF
[client]
user=$DB_USER
password=$DB_PASS
EOF
            chmod 600 "$MYSQL_CONFIG"

            if mysql --defaults-file="$MYSQL_CONFIG" -e "USE $DB_NAME;" &>/dev/null; then
                # Update .env
                if [ -f ".env" ]; then
                    sed -i "s|DB_DATABASE=.*|DB_DATABASE=$DB_NAME|g" ".env"
                    sed -i "s|DB_USERNAME=.*|DB_USERNAME=$DB_USER|g" ".env"
                    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|g" ".env"
                fi

                # Run migrations
                if su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan migrate --force"; then
                    info "✓ Database migrations completed"
                    su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan db:seed --force" 2>/dev/null || true
                else
                    warning "Migration failed"
                fi

                info "Using existing database: $DB_NAME"
            else
                error "Failed to connect to existing database"
            fi

            rm -f "$MYSQL_CONFIG"
        else
            warning "Database setup skipped - incomplete credentials"
        fi
        ;;
    3)
        warning "Database setup skipped"
        ;;
esac

# Optimize Laravel
log "Optimizing application..."
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan config:cache" 2>/dev/null || true
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan route:cache" 2>/dev/null || true
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan view:cache" 2>/dev/null || true
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan storage:link" 2>/dev/null || true

# Restart services
log "Restarting services..."
systemctl restart php*-fpm 2>/dev/null || true
systemctl restart nginx 2>/dev/null || true

# Comprehensive deployment verification
log "Performing comprehensive deployment verification..."

# File deployment verification
DEPLOYED_FILES=$(find "$WEB_ROOT" -type f 2>/dev/null | wc -l)
DEPLOYED_DIRS=$(find "$WEB_ROOT" -type d 2>/dev/null | wc -l)
info "Deployed: $DEPLOYED_FILES files in $DEPLOYED_DIRS directories"

# Laravel structure verification
log "Verifying Laravel application structure..."
REQUIRED_LARAVEL_FILES=("composer.json" "artisan" "public/index.php")
REQUIRED_LARAVEL_DIRS=("app" "config" "database" "public" "resources" "routes" "storage")

for file in "${REQUIRED_LARAVEL_FILES[@]}"; do
    if [ -f "$WEB_ROOT/$file" ]; then
        info "✓ Required file exists: $file"
    else
        error "✗ Missing required file: $file"
    fi
done

for dir in "${REQUIRED_LARAVEL_DIRS[@]}"; do
    if [ -d "$WEB_ROOT/$dir" ]; then
        file_count=$(find "$WEB_ROOT/$dir" -type f | wc -l)
        info "✓ Required directory exists: $dir ($file_count files)"
    else
        error "✗ Missing required directory: $dir"
    fi
done

# Web server verification
log "Verifying web server status..."
if systemctl is-active --quiet nginx; then
    info "✓ Nginx is running"

    if nginx -t &>/dev/null; then
        info "✓ Nginx configuration is valid"
    else
        warning "✗ Nginx configuration may have issues"
    fi
else
    warning "✗ Nginx may not be running"
fi

if systemctl is-active --quiet php*-fpm; then
    info "✓ PHP-FPM is running"
else
    warning "✗ PHP-FPM may not be running"
fi

# Website accessibility verification
log "Testing website accessibility..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" =~ ^[23] ]]; then
    info "✓ Website is accessible (HTTP $HTTP_CODE)"

    if curl -s "http://localhost" | grep -q "Laravel\|BestHammer" 2>/dev/null; then
        info "✓ Website content appears correct"
    else
        warning "Website content may not be correct"
    fi
else
    warning "✗ Website may not be accessible (HTTP $HTTP_CODE)"
fi

# Laravel application verification
if [ -f "$WEB_ROOT/artisan" ]; then
    log "Testing Laravel application..."

    if sudo -u $WEB_USER php "$WEB_ROOT/artisan" --version &>/dev/null; then
        laravel_version=$(sudo -u $WEB_USER php "$WEB_ROOT/artisan" --version 2>/dev/null)
        info "✓ Laravel application working: $laravel_version"
    else
        warning "✗ Laravel application may have issues"
    fi

    # Test database connection if configured
    if [ -f "$WEB_ROOT/.env" ] && grep -q "DB_DATABASE=" "$WEB_ROOT/.env"; then
        if sudo -u $WEB_USER php "$WEB_ROOT/artisan" migrate:status &>/dev/null; then
            info "✓ Database connection working"
        else
            warning "Database connection may have issues"
        fi
    fi
fi

# FastPanel integration verification
log "Verifying FastPanel integration..."
if [ -d "/usr/local/fastpanel" ]; then
    info "✓ FastPanel environment detected"

    if [ -d "/var/www/besthammer_c_usr" ]; then
        info "✓ FastPanel domain directory exists"
    else
        warning "FastPanel domain directory not found"
    fi

    if id "$WEB_USER" &>/dev/null; then
        info "✓ FastPanel web user exists: $WEB_USER"
    else
        warning "FastPanel web user not found: $WEB_USER"
    fi
else
    info "Standard server environment (non-FastPanel)"
fi

# Return to original directory
cd "$ORIGINAL_DIR"

# Success message
echo
log "🎉 Source deployment completed successfully!"
echo
echo "🌐 Website: https://$DOMAIN"
echo "📁 Location: $WEB_ROOT"
echo "💾 Backup: ${BACKUP_NAME}_files.tar.gz"
echo "👤 Web User: $WEB_USER"
echo
echo "🧮 Test calculators:"
echo "• Loan: https://$DOMAIN/loan-calculator"
echo "• BMI: https://$DOMAIN/bmi-calculator"
echo "• Currency: https://$DOMAIN/currency-converter"
echo
echo "⚙️ Next steps:"
echo "1. Configure SSL in FastPanel"
echo "2. Test all calculator functions"
echo "3. Update Google Analytics ID in .env"
echo "4. Test privacy compliance features"
echo "5. Monitor error logs if needed"
echo
echo "📄 Important files:"
if [ -f "/root/besthammer-db-credentials.txt" ]; then
    echo "• Database credentials: /root/besthammer-db-credentials.txt"
fi
echo "• Application logs: $WEB_ROOT/storage/logs/laravel.log"
echo "• Nginx logs: /var/log/nginx/error.log"
echo
echo "🔄 If issues occur, restore from backup:"
echo "   tar -xzf ${BACKUP_DIR}/${BACKUP_NAME}_files.tar.gz -C $WEB_ROOT"
