#!/bin/bash

# BestHammer NTool Platform Source File Direct Deployment Script
# This script deploys directly from source files without packaging

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
    error "This script must be run as root. Use: sudo ./source-deploy.sh"
fi

# Banner
echo "🔨 BestHammer NTool Platform - Source File Deployment"
echo "===================================================="
echo

log "Checking source files..."

# Verify we have Laravel source files
if [ ! -f "composer.json" ] || [ ! -d "app" ] || [ ! -f "artisan" ]; then
    error "Laravel source files not found. Required: composer.json, app/, artisan"
fi

# Check for essential directories
ESSENTIAL_DIRS=("app" "config" "database" "public" "resources" "routes")
MISSING_DIRS=()

for dir in "${ESSENTIAL_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        MISSING_DIRS+=("$dir")
    fi
done

if [ ${#MISSING_DIRS[@]} -gt 0 ]; then
    error "Missing essential directories: ${MISSING_DIRS[*]}"
fi

info "✓ Laravel source files verified"
info "✓ Web user: $WEB_USER"

# Show what will be deployed
FILE_COUNT=$(find . -type f -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./vendor/*" | wc -l)
info "Source files to deploy: $FILE_COUNT"

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

# Copy source files
log "Copying source files..."

# Copy essential files and directories
COPY_ITEMS=(
    "app" "bootstrap" "config" "database" "public" "resources" 
    "routes" "storage" "tests" "composer.json" "package.json" 
    "artisan" ".env.example"
)

for item in "${COPY_ITEMS[@]}"; do
    if [ -e "$item" ]; then
        cp -r "$item" "$WEB_ROOT/"
        info "✓ Copied $item"
    fi
done

# Copy additional files if they exist
OPTIONAL_FILES=("README.md" "webpack.mix.js" "vite.config.js" "phpunit.xml" ".gitignore")
for file in "${OPTIONAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "$WEB_ROOT/"
        info "✓ Copied $file"
    fi
done

# Create missing storage structure
log "Creating storage structure..."
mkdir -p "$WEB_ROOT/storage/app/public"
mkdir -p "$WEB_ROOT/storage/framework/cache/data"
mkdir -p "$WEB_ROOT/storage/framework/sessions"
mkdir -p "$WEB_ROOT/storage/framework/views"
mkdir -p "$WEB_ROOT/storage/logs"
mkdir -p "$WEB_ROOT/bootstrap/cache"

# Create .gitignore files for empty directories
echo "*" > "$WEB_ROOT/storage/app/public/.gitignore"
echo "!.gitignore" >> "$WEB_ROOT/storage/app/public/.gitignore"

echo "*" > "$WEB_ROOT/storage/framework/cache/data/.gitignore"
echo "!.gitignore" >> "$WEB_ROOT/storage/framework/cache/data/.gitignore"

echo "*" > "$WEB_ROOT/storage/framework/sessions/.gitignore"
echo "!.gitignore" >> "$WEB_ROOT/storage/framework/sessions/.gitignore"

echo "*" > "$WEB_ROOT/storage/framework/views/.gitignore"
echo "!.gitignore" >> "$WEB_ROOT/storage/framework/views/.gitignore"

echo "*" > "$WEB_ROOT/storage/logs/.gitignore"
echo "!.gitignore" >> "$WEB_ROOT/storage/logs/.gitignore"

echo "*" > "$WEB_ROOT/bootstrap/cache/.gitignore"
echo "!.gitignore" >> "$WEB_ROOT/bootstrap/cache/.gitignore"

# Set permissions
log "Setting permissions..."
chown -R $WEB_USER:$WEB_USER "$WEB_ROOT"
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
chmod +x "$WEB_ROOT/artisan"
chmod -R 775 "$WEB_ROOT/storage"
chmod -R 775 "$WEB_ROOT/bootstrap/cache"

# Install dependencies
log "Installing dependencies..."
cd "$WEB_ROOT"

if [ -f "composer.json" ]; then
    info "Installing Composer dependencies..."
    su - $WEB_USER -c "cd '$WEB_ROOT' && composer install --no-dev --optimize-autoloader --no-interaction"
fi

if [ -f "package.json" ]; then
    info "Installing NPM dependencies..."
    su - $WEB_USER -c "cd '$WEB_ROOT' && npm install --production"
    su - $WEB_USER -c "cd '$WEB_ROOT' && npm run build" 2>/dev/null || su - $WEB_USER -c "cd '$WEB_ROOT' && npm run production" 2>/dev/null || true
fi

# Configure environment
log "Configuring environment..."
if [ ! -f ".env" ] && [ -f ".env.example" ]; then
    su - $WEB_USER -c "cd '$WEB_ROOT' && cp '.env.example' '.env'"
fi

if [ -f ".env" ]; then
    sed -i "s|APP_ENV=.*|APP_ENV=production|g" ".env"
    sed -i "s|APP_DEBUG=.*|APP_DEBUG=false|g" ".env"
    sed -i "s|APP_URL=.*|APP_URL=https://$DOMAIN|g" ".env"
fi

# Generate app key
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan key:generate --force"

# Enhanced database setup with FastPanel integration
log "Setting up database with FastPanel integration..."

# Check MySQL service
if ! systemctl is-active --quiet mysql; then
    warning "MySQL service not running. Starting MySQL..."
    systemctl start mysql
    sleep 3
fi

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
        # Create new database
        read -s -p "Enter MySQL root password: " mysql_password
        echo

        if [ -z "$mysql_password" ]; then
            warning "Database setup skipped - no password provided"
        else
            if mysql -uroot -p"$mysql_password" -e "SELECT 1;" &>/dev/null; then
                DB_NAME="besthammer_db"
                DB_USER="besthammer_user"
                DB_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

                info "Creating database: $DB_NAME"
                mysql -uroot -p"$mysql_password" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || error "Failed to create database"
                mysql -uroot -p"$mysql_password" -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';" || error "Failed to create user"
                mysql -uroot -p"$mysql_password" -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';" || error "Failed to grant privileges"
                mysql -uroot -p"$mysql_password" -e "FLUSH PRIVILEGES;" || error "Failed to flush privileges"

                # Update .env
                if [ -f ".env" ]; then
                    sed -i "s|DB_DATABASE=.*|DB_DATABASE=$DB_NAME|g" ".env"
                    sed -i "s|DB_USERNAME=.*|DB_USERNAME=$DB_USER|g" ".env"
                    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|g" ".env"
                    sed -i "s|DB_HOST=.*|DB_HOST=127.0.0.1|g" ".env"
                    sed -i "s|DB_PORT=.*|DB_PORT=3306|g" ".env"
                fi

                # Save credentials
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
                su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan migrate --force" || warning "Migration failed"
                su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan db:seed --force" 2>/dev/null || true

                log "Database setup completed: $DB_NAME"
            else
                error "Failed to connect to MySQL with provided password"
            fi
        fi
        ;;
    2)
        # Use existing database
        read -p "Enter database name: " DB_NAME
        read -p "Enter database user: " DB_USER
        read -s -p "Enter database password: " DB_PASS
        echo

        if [ -n "$DB_NAME" ] && [ -n "$DB_USER" ] && [ -n "$DB_PASS" ]; then
            if mysql -u"$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME;" &>/dev/null; then
                # Update .env
                if [ -f ".env" ]; then
                    sed -i "s|DB_DATABASE=.*|DB_DATABASE=$DB_NAME|g" ".env"
                    sed -i "s|DB_USERNAME=.*|DB_USERNAME=$DB_USER|g" ".env"
                    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|g" ".env"
                fi

                # Run migrations
                su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan migrate --force" || warning "Migration failed"
                su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan db:seed --force" 2>/dev/null || true

                info "Using existing database: $DB_NAME"
            else
                error "Failed to connect to existing database"
            fi
        else
            warning "Database setup skipped - incomplete credentials"
        fi
        ;;
    3)
        warning "Database setup skipped"
        ;;
    *)
        warning "Invalid option, database setup skipped"
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

# Verification
log "Verifying deployment..."
DEPLOYED_FILES=$(find "$WEB_ROOT" -type f 2>/dev/null | wc -l)
info "Deployed $DEPLOYED_FILES files"

if systemctl is-active --quiet nginx; then
    info "✓ Nginx is running"
else
    warning "Nginx may not be running"
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" =~ ^[23] ]]; then
    info "✓ Website is accessible (HTTP $HTTP_CODE)"
else
    warning "Website may not be accessible (HTTP $HTTP_CODE)"
fi

# Success message
echo
log "🎉 Source deployment completed!"
echo
echo "🌐 Website: https://$DOMAIN"
echo "📁 Location: $WEB_ROOT"
echo "💾 Backup: ${BACKUP_NAME}_files.tar.gz"
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
echo
echo "🔄 If issues occur, restore from backup: ${BACKUP_NAME}_files.tar.gz"
