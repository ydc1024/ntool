#!/bin/bash

# Quick NTool Deployment Script - Simplified and Reliable
# Designed for immediate deployment and testing

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
    error "Run as root: sudo ./quick-ntool-deploy.sh"
fi

echo "🚀 Quick NTool Deployment for FastPanel"
echo "======================================"
echo "Domain: $DOMAIN"
echo "Target: $WEB_ROOT"
echo "Time: $(date)"
echo "======================================"
echo

# Step 1: Verify Laravel files in current directory
log "Step 1: Verifying Laravel application..."

REQUIRED_FILES=("composer.json" "artisan" "app" "config" "public" "routes")
MISSING_FILES=()

for item in "${REQUIRED_FILES[@]}"; do
    if [ ! -e "$item" ]; then
        MISSING_FILES+=("$item")
    fi
done

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    error "Missing Laravel files: ${MISSING_FILES[*]}"
fi

info "✓ Laravel application verified in current directory"

# Step 2: Quick backup
log "Step 2: Creating backup..."
if [ -d "$WEB_ROOT" ] && [ "$(ls -A $WEB_ROOT 2>/dev/null)" ]; then
    BACKUP_FILE="/tmp/website_backup_${TIMESTAMP}.tar.gz"
    tar -czf "$BACKUP_FILE" -C "$WEB_ROOT" . 2>/dev/null || true
    info "✓ Backup created: $BACKUP_FILE"
else
    info "No existing files to backup"
fi

# Step 3: Clear and prepare web root
log "Step 3: Preparing web root..."
if [ -d "$WEB_ROOT" ]; then
    rm -rf "$WEB_ROOT"/* 2>/dev/null || true
    rm -rf "$WEB_ROOT"/.[^.]* 2>/dev/null || true
else
    mkdir -p "$WEB_ROOT"
fi
info "✓ Web root prepared"

# Step 4: Copy application files
log "Step 4: Copying application files..."

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

# Step 5: Create Laravel structure
log "Step 5: Setting up Laravel structure..."

# Create storage directories
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

info "✓ Laravel structure created"

# Step 6: Set permissions
log "Step 6: Setting permissions..."
chown -R $WEB_USER:$WEB_USER "$WEB_ROOT"
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
chmod +x "$WEB_ROOT/artisan"
chmod -R 775 "$WEB_ROOT/storage"
chmod -R 775 "$WEB_ROOT/bootstrap/cache"
info "✓ Permissions set"

# Step 7: Install dependencies (optional)
log "Step 7: Installing dependencies..."
cd "$WEB_ROOT"

read -p "Install Composer dependencies? (y/N): " install_composer
if [[ $install_composer =~ ^[Yy]$ ]]; then
    if command -v composer &>/dev/null; then
        info "Installing Composer dependencies..."
        su - $WEB_USER -c "cd '$WEB_ROOT' && composer install --no-dev --optimize-autoloader --no-interaction" || warning "Composer install failed"
    else
        warning "Composer not found - skipping"
    fi
fi

read -p "Install NPM dependencies? (y/N): " install_npm
if [[ $install_npm =~ ^[Yy]$ ]]; then
    if command -v npm &>/dev/null; then
        info "Installing NPM dependencies..."
        su - $WEB_USER -c "cd '$WEB_ROOT' && npm install --production" || warning "NPM install failed"
        su - $WEB_USER -c "cd '$WEB_ROOT' && npm run build" 2>/dev/null || warning "Asset build failed"
    else
        warning "NPM not found - skipping"
    fi
fi

# Step 8: Configure environment
log "Step 8: Configuring environment..."

# Create .env
if [ -f ".env.example" ]; then
    cp ".env.example" ".env"
    info "✓ Created .env from .env.example"
fi

# Basic configuration
if [ -f ".env" ]; then
    sed -i "s|APP_ENV=.*|APP_ENV=production|g" ".env"
    sed -i "s|APP_DEBUG=.*|APP_DEBUG=false|g" ".env"
    sed -i "s|APP_URL=.*|APP_URL=https://$DOMAIN|g" ".env"
    info "✓ Basic environment configured"
fi

# Generate app key
if [ -f "artisan" ]; then
    su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan key:generate --force" || warning "Key generation failed"
    info "✓ Application key generated"
fi

# Step 9: Database setup (simplified)
log "Step 9: Database setup..."

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
        
        # Save credentials
        echo "Database: $DB_NAME, User: $DB_USER, Password: $DB_PASS" > "/root/db_credentials_${TIMESTAMP}.txt"
        info "✓ Credentials saved to /root/db_credentials_${TIMESTAMP}.txt"
    else
        warning "Database setup skipped"
    fi
else
    warning "Database setup skipped"
fi

# Step 10: Final optimization
log "Step 10: Final optimization..."

# Laravel optimization
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan config:cache" 2>/dev/null || true
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan route:cache" 2>/dev/null || true
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan view:cache" 2>/dev/null || true
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan storage:link" 2>/dev/null || true

# Restart services
systemctl restart php*-fpm 2>/dev/null || true
systemctl restart nginx 2>/dev/null || true

info "✓ Optimization completed"

# Step 11: Verification
log "Step 11: Verifying deployment..."

DEPLOYED_FILES=$(find "$WEB_ROOT" -type f | wc -l)
info "Files deployed: $DEPLOYED_FILES"

# Test web services
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

# Success message
echo
log "🎉 Quick deployment completed!"
echo
echo "🌐 Website: https://$DOMAIN"
echo "📁 Location: $WEB_ROOT"
echo "👤 Web User: $WEB_USER"
echo
echo "🧮 Test URLs:"
echo "• Main site: https://$DOMAIN"
echo "• Loan Calculator: https://$DOMAIN/loan-calculator"
echo "• BMI Calculator: https://$DOMAIN/bmi-calculator"
echo "• Currency Converter: https://$DOMAIN/currency-converter"
echo
echo "⚙️ Next steps:"
echo "1. Configure SSL in FastPanel"
echo "2. Test calculator functions"
echo "3. Check error logs if needed:"
echo "   tail -f $WEB_ROOT/storage/logs/laravel.log"
echo "   tail -f /var/log/nginx/error.log"
echo
if [ -f "/root/db_credentials_${TIMESTAMP}.txt" ]; then
    echo "📄 Database credentials: /root/db_credentials_${TIMESTAMP}.txt"
fi
echo
echo "🔄 If issues occur, restore backup:"
if [ -f "$BACKUP_FILE" ]; then
    echo "   tar -xzf $BACKUP_FILE -C $WEB_ROOT"
fi
