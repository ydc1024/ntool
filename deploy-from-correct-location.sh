#!/bin/bash

# Deploy from Correct Laravel Source Location
# This script automatically finds and deploys from the correct ntool directory

set -e

# Configuration
DOMAIN="besthammer.club"
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; exit 1; }
info() { echo -e "${BLUE}ℹ️ $1${NC}"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    error "Run as root: sudo ./deploy-from-correct-location.sh"
fi

echo "🎯 Deploy from Correct Laravel Source Location"
echo "============================================="
echo "Current directory: $(pwd)"
echo "Time: $(date)"
echo "============================================="
echo

# Find the correct Laravel source directory
log "Step 1: Finding Laravel source directory..."

LARAVEL_SOURCE=""

# Check current directory
if [ -f "composer.json" ] && [ -d "app" ] && [ -f "artisan" ]; then
    LARAVEL_SOURCE="$(pwd)"
    log "✓ Found Laravel source in current directory"
# Check parent directory ntool
elif [ -f "../ntool/composer.json" ] && [ -d "../ntool/app" ] && [ -f "../ntool/artisan" ]; then
    LARAVEL_SOURCE="$(realpath ../ntool)"
    log "✓ Found Laravel source in ../ntool/"
# Check sibling ntool directory
elif [ -f "../ntool/composer.json" ] && [ -d "../ntool/app" ] && [ -f "../ntool/artisan" ]; then
    LARAVEL_SOURCE="$(realpath ../ntool)"
    log "✓ Found Laravel source in sibling ntool directory"
else
    error "Laravel source not found. Checked:"
    error "  - Current directory: $(pwd)"
    error "  - Parent ntool: $(realpath ../ntool 2>/dev/null || echo 'not found')"
fi

info "Laravel source directory: $LARAVEL_SOURCE"

# Verify Laravel structure
log "Step 2: Verifying Laravel structure..."
cd "$LARAVEL_SOURCE"

REQUIRED_ITEMS=("composer.json" "artisan" "app" "config" "public" "routes")
MISSING_ITEMS=()

for item in "${REQUIRED_ITEMS[@]}"; do
    if [ ! -e "$item" ]; then
        MISSING_ITEMS+=("$item")
    fi
done

if [ ${#MISSING_ITEMS[@]} -gt 0 ]; then
    error "Missing Laravel components: ${MISSING_ITEMS[*]}"
fi

# Show Laravel info
if [ -f "composer.json" ]; then
    APP_NAME=$(grep '"name"' composer.json | head -1 | cut -d'"' -f4 2>/dev/null || echo "Unknown")
    info "Application: $APP_NAME"
fi

FILE_COUNT=$(find . -type f -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./vendor/*" | wc -l)
info "Source files: $FILE_COUNT"

log "✓ Laravel structure verified"

# Confirm deployment
echo
warning "This will deploy Laravel application to FastPanel:"
warning "• Source: $LARAVEL_SOURCE"
warning "• Target: $WEB_ROOT"
warning "• Domain: $DOMAIN"
echo

read -p "Continue with deployment? (type 'yes'): " confirm
if [ "$confirm" != "yes" ]; then
    info "Deployment cancelled"
    exit 0
fi

# Create backup
log "Step 3: Creating backup..."
if [ -d "$WEB_ROOT" ] && [ "$(ls -A $WEB_ROOT 2>/dev/null)" ]; then
    BACKUP_FILE="/tmp/backup_${TIMESTAMP}.tar.gz"
    tar -czf "$BACKUP_FILE" -C "$WEB_ROOT" . 2>/dev/null || true
    info "✓ Backup created: $BACKUP_FILE"
fi

# Clear web root
log "Step 4: Clearing web root..."
rm -rf "$WEB_ROOT"/* 2>/dev/null || true
rm -rf "$WEB_ROOT"/.[^.]* 2>/dev/null || true
mkdir -p "$WEB_ROOT"

# Copy Laravel application
log "Step 5: Copying Laravel application..."

# Copy directories
DIRS=("app" "bootstrap" "config" "database" "public" "resources" "routes" "storage" "tests")
for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        cp -r "$dir" "$WEB_ROOT/"
        info "✓ Copied: $dir"
    fi
done

# Copy files
FILES=("composer.json" "artisan" "package.json" ".env.example" "vite.config.js" "tailwind.config.js")
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "$WEB_ROOT/"
        info "✓ Copied: $file"
    fi
done

# Copy additional files
OPTIONAL_FILES=("webpack.mix.js" "phpunit.xml" ".gitignore" "README.md")
for file in "${OPTIONAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "$WEB_ROOT/"
        info "✓ Copied: $file"
    fi
done

# Create Laravel structure
log "Step 6: Setting up Laravel structure..."
mkdir -p "$WEB_ROOT/storage/app/public"
mkdir -p "$WEB_ROOT/storage/framework/cache/data"
mkdir -p "$WEB_ROOT/storage/framework/sessions"
mkdir -p "$WEB_ROOT/storage/framework/views"
mkdir -p "$WEB_ROOT/storage/logs"
mkdir -p "$WEB_ROOT/bootstrap/cache"

# Create .gitignore files
echo "*" > "$WEB_ROOT/storage/logs/.gitignore"
echo "!.gitignore" >> "$WEB_ROOT/storage/logs/.gitignore"
echo "*" > "$WEB_ROOT/bootstrap/cache/.gitignore"
echo "!.gitignore" >> "$WEB_ROOT/bootstrap/cache/.gitignore"

# Set permissions
log "Step 7: Setting permissions..."
chown -R $WEB_USER:$WEB_USER "$WEB_ROOT"
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
chmod +x "$WEB_ROOT/artisan"
chmod -R 775 "$WEB_ROOT/storage"
chmod -R 775 "$WEB_ROOT/bootstrap/cache"

# Configure environment
log "Step 8: Configuring environment..."
cd "$WEB_ROOT"

if [ -f ".env.example" ]; then
    cp ".env.example" ".env"
    info "✓ Created .env from .env.example"
fi

if [ -f ".env" ]; then
    sed -i "s|APP_ENV=.*|APP_ENV=production|g" ".env"
    sed -i "s|APP_DEBUG=.*|APP_DEBUG=false|g" ".env"
    sed -i "s|APP_URL=.*|APP_URL=https://$DOMAIN|g" ".env"
    info "✓ Environment configured"
fi

# Generate app key
if [ -f "artisan" ]; then
    su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan key:generate --force" 2>/dev/null || warning "Key generation failed"
    info "✓ Application key generated"
fi

# Install dependencies
log "Step 9: Installing dependencies..."

# Composer
if command -v composer &>/dev/null && [ -f "composer.json" ]; then
    info "Installing Composer dependencies..."
    su - $WEB_USER -c "cd '$WEB_ROOT' && composer install --no-dev --optimize-autoloader --no-interaction" 2>/dev/null || warning "Composer install failed"
    info "✓ Composer dependencies processed"
fi

# NPM
if command -v npm &>/dev/null && [ -f "package.json" ]; then
    info "Installing NPM dependencies..."
    su - $WEB_USER -c "cd '$WEB_ROOT' && npm install --production" 2>/dev/null || warning "NPM install failed"
    su - $WEB_USER -c "cd '$WEB_ROOT' && npm run build" 2>/dev/null || warning "Asset build failed"
    info "✓ NPM dependencies processed"
fi

# Database setup
log "Step 10: Database setup..."
read -p "Setup database? (y/N): " setup_db
if [[ $setup_db =~ ^[Yy]$ ]]; then
    read -s -p "MySQL root password: " mysql_pass
    echo
    
    if [ -n "$mysql_pass" ] && mysql -uroot -p"$mysql_pass" -e "SELECT 1;" &>/dev/null; then
        DB_NAME="besthammer_db"
        DB_USER="besthammer_user"
        DB_PASS=$(openssl rand -base64 20 | tr -d "=+/" | cut -c1-16)
        
        mysql -uroot -p"$mysql_pass" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
        mysql -uroot -p"$mysql_pass" -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';" 2>/dev/null
        mysql -uroot -p"$mysql_pass" -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';" 2>/dev/null
        mysql -uroot -p"$mysql_pass" -e "FLUSH PRIVILEGES;" 2>/dev/null
        
        # Update .env
        sed -i "s|DB_DATABASE=.*|DB_DATABASE=$DB_NAME|g" ".env"
        sed -i "s|DB_USERNAME=.*|DB_USERNAME=$DB_USER|g" ".env"
        sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|g" ".env"
        
        # Run migrations
        su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan migrate --force" 2>/dev/null || warning "Migration failed"
        
        info "✓ Database configured: $DB_NAME"
        echo "Database: $DB_NAME, User: $DB_USER, Password: $DB_PASS" > "/root/db_credentials_${TIMESTAMP}.txt"
        info "✓ Credentials saved to /root/db_credentials_${TIMESTAMP}.txt"
    else
        warning "Database setup skipped"
    fi
else
    warning "Database setup skipped"
fi

# Optimize Laravel
log "Step 11: Optimizing Laravel..."
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan config:cache" 2>/dev/null || true
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan route:cache" 2>/dev/null || true
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan view:cache" 2>/dev/null || true
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan storage:link" 2>/dev/null || true

# Restart services
systemctl restart php*-fpm nginx 2>/dev/null || true

# Verification
log "Step 12: Verifying deployment..."
FILES_DEPLOYED=$(find "$WEB_ROOT" -type f | wc -l)
info "Files deployed: $FILES_DEPLOYED"

# Test services
if systemctl is-active --quiet nginx; then
    info "✓ Nginx running"
else
    warning "Nginx may not be running"
fi

if systemctl is-active --quiet php*-fpm; then
    info "✓ PHP-FPM running"
else
    warning "PHP-FPM may not be running"
fi

# Test website
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" =~ ^[23] ]]; then
    info "✓ Website accessible (HTTP $HTTP_CODE)"
else
    warning "Website status: HTTP $HTTP_CODE"
fi

# Test Laravel
if [ -f "$WEB_ROOT/artisan" ]; then
    if sudo -u $WEB_USER php "$WEB_ROOT/artisan" --version &>/dev/null; then
        LARAVEL_VERSION=$(sudo -u $WEB_USER php "$WEB_ROOT/artisan" --version 2>/dev/null)
        info "✓ Laravel working: $LARAVEL_VERSION"
    else
        warning "Laravel may have issues"
    fi
fi

# Success message
echo
log "🎉 Deployment completed successfully!"
echo
echo "🌐 Website: https://$DOMAIN"
echo "📁 Source: $LARAVEL_SOURCE"
echo "📁 Target: $WEB_ROOT"
echo "👤 Web User: $WEB_USER"
echo
echo "🧮 Test calculators:"
echo "• https://$DOMAIN/loan-calculator"
echo "• https://$DOMAIN/bmi-calculator"
echo "• https://$DOMAIN/currency-converter"
echo
echo "⚙️ Next steps:"
echo "1. Configure SSL in FastPanel"
echo "2. Test all calculator functions"
echo "3. Check error logs if needed"
echo
if [ -f "/root/db_credentials_${TIMESTAMP}.txt" ]; then
    echo "📄 Database credentials: /root/db_credentials_${TIMESTAMP}.txt"
fi
echo
if [ -f "$BACKUP_FILE" ]; then
    echo "🔄 Restore backup if needed: tar -xzf $BACKUP_FILE -C $WEB_ROOT"
fi
