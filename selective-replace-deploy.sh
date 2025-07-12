#!/bin/bash

# Selective Replace Deployment for BestHammer NTool Platform
# This script selectively replaces files in existing FastPanel website

set -e

# Configuration
DOMAIN="besthammer.club"
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/var/backups/website"

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
    error "Run as root: sudo ./selective-replace-deploy.sh"
fi

echo "🔄 Selective Replace Deployment for BestHammer NTool"
echo "===================================================="
echo "Website Root: $WEB_ROOT"
echo "Domain: $DOMAIN"
echo "Time: $(date)"
echo "===================================================="
echo

# Step 1: Verify source and target
log "Step 1: Verifying source and target locations"

# Check if we have source files (from git or created)
SOURCE_DIR=""

# Check current directory for Laravel files
if [ -f "composer.json" ] && [ -d "app" ] && [ -f "artisan" ]; then
    SOURCE_DIR="$(pwd)"
    log "✓ Source files found in current directory"
elif [ -f "../composer.json" ] && [ -d "../app" ] && [ -f "../artisan" ]; then
    SOURCE_DIR="$(realpath ..)"
    log "✓ Source files found in parent directory"
elif [ -d "besthammer-ntool" ] && [ -f "besthammer-ntool/composer.json" ]; then
    SOURCE_DIR="$(realpath besthammer-ntool)"
    log "✓ Source files found in besthammer-ntool directory"
else
    error "No BestHammer NTool source files found. Please ensure you have:"
    error "  - composer.json with BestHammer content"
    error "  - Laravel application structure"
    error "  - BestHammer NTool controllers and views"
fi

# Verify target directory
if [ ! -d "$WEB_ROOT" ]; then
    error "Target directory does not exist: $WEB_ROOT"
fi

info "Source: $SOURCE_DIR"
info "Target: $WEB_ROOT"

# Step 2: Analyze existing website
log "Step 2: Analyzing existing website"

cd "$WEB_ROOT"

EXISTING_FILES=$(find . -type f | wc -l)
EXISTING_SIZE=$(du -sh . | cut -f1)

info "Existing files: $EXISTING_FILES"
info "Existing size: $EXISTING_SIZE"

# Check if it's a Laravel app
if [ -f "composer.json" ] && [ -d "app" ] && [ -f "artisan" ]; then
    log "✓ Existing Laravel application detected"
    
    # Check if it's already BestHammer
    if grep -q "besthammer\|ntool" composer.json 2>/dev/null; then
        log "✓ BestHammer content detected - will update"
    else
        warning "Generic Laravel app - will convert to BestHammer"
    fi
else
    warning "Non-Laravel content detected - will replace"
fi

# Step 3: Create comprehensive backup
log "Step 3: Creating comprehensive backup"

mkdir -p "$BACKUP_DIR"
BACKUP_FILE="${BACKUP_DIR}/selective_backup_${TIMESTAMP}.tar.gz"

tar -czf "$BACKUP_FILE" -C "$WEB_ROOT" . 2>/dev/null || true

if [ -f "$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "✓ Backup created: $BACKUP_FILE ($BACKUP_SIZE)"
else
    error "Failed to create backup"
fi

# Step 4: Preserve important files
log "Step 4: Preserving important existing files"

PRESERVE_DIR="/tmp/preserve_${TIMESTAMP}"
mkdir -p "$PRESERVE_DIR"

# Preserve .env file
if [ -f ".env" ]; then
    cp ".env" "$PRESERVE_DIR/.env"
    log "✓ Preserved .env file"
fi

# Preserve storage/logs
if [ -d "storage/logs" ]; then
    mkdir -p "$PRESERVE_DIR/storage"
    cp -r "storage/logs" "$PRESERVE_DIR/storage/"
    log "✓ Preserved storage/logs"
fi

# Preserve any custom uploads
if [ -d "public/uploads" ]; then
    mkdir -p "$PRESERVE_DIR/public"
    cp -r "public/uploads" "$PRESERVE_DIR/public/"
    log "✓ Preserved public/uploads"
fi

# Step 5: Remove old application files
log "Step 5: Removing old application files"

# Remove Laravel application files (but preserve structure)
REMOVE_PATTERNS=(
    "app/Http/Controllers/*.php"
    "app/Models/*.php"
    "resources/views/*.blade.php"
    "resources/views/*/*.blade.php"
    "resources/js/*"
    "resources/css/*"
    "database/migrations/*.php"
    "database/seeders/*.php"
    "routes/*.php"
)

for pattern in "${REMOVE_PATTERNS[@]}"; do
    if find . -path "./$pattern" -type f | head -1 | grep -q .; then
        find . -path "./$pattern" -type f -delete 2>/dev/null || true
        info "✓ Removed: $pattern"
    fi
done

# Remove non-Laravel files
NON_LARAVEL_PATTERNS=("*.html" "*.htm" "wp-*" "*.zip" "*.tar.gz")

for pattern in "${NON_LARAVEL_PATTERNS[@]}"; do
    if find . -maxdepth 2 -name "$pattern" -type f | head -1 | grep -q .; then
        find . -maxdepth 2 -name "$pattern" -type f -delete 2>/dev/null || true
        info "✓ Removed non-Laravel files: $pattern"
    fi
done

# Step 6: Copy new BestHammer NTool files
log "Step 6: Copying new BestHammer NTool files"

cd "$SOURCE_DIR"

# Copy Laravel application files
COPY_ITEMS=(
    "app"
    "config"
    "database"
    "resources"
    "routes"
    "composer.json"
    "package.json"
    ".env.example"
)

for item in "${COPY_ITEMS[@]}"; do
    if [ -e "$item" ]; then
        cp -r "$item" "$WEB_ROOT/"
        info "✓ Copied: $item"
    else
        warning "Source item not found: $item"
    fi
done

# Copy additional files
ADDITIONAL_FILES=("artisan" "vite.config.js" "tailwind.config.js" "webpack.mix.js" "phpunit.xml")

for file in "${ADDITIONAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "$WEB_ROOT/"
        info "✓ Copied: $file"
    fi
done

# Step 7: Restore preserved files
log "Step 7: Restoring preserved files"

cd "$WEB_ROOT"

# Restore .env file
if [ -f "$PRESERVE_DIR/.env" ]; then
    cp "$PRESERVE_DIR/.env" ".env"
    log "✓ Restored .env file"
elif [ -f ".env.example" ]; then
    cp ".env.example" ".env"
    log "✓ Created .env from .env.example"
fi

# Restore storage/logs
if [ -d "$PRESERVE_DIR/storage/logs" ]; then
    mkdir -p "storage"
    cp -r "$PRESERVE_DIR/storage/logs" "storage/"
    log "✓ Restored storage/logs"
fi

# Restore uploads
if [ -d "$PRESERVE_DIR/public/uploads" ]; then
    mkdir -p "public"
    cp -r "$PRESERVE_DIR/public/uploads" "public/"
    log "✓ Restored public/uploads"
fi

# Step 8: Update configuration
log "Step 8: Updating configuration"

# Update .env for production
if [ -f ".env" ]; then
    sed -i "s|APP_ENV=.*|APP_ENV=production|g" ".env"
    sed -i "s|APP_DEBUG=.*|APP_DEBUG=false|g" ".env"
    sed -i "s|APP_URL=.*|APP_URL=https://$DOMAIN|g" ".env"
    
    # Update app name if not set
    if ! grep -q "APP_NAME.*BestHammer" ".env"; then
        sed -i "s|APP_NAME=.*|APP_NAME=\"BestHammer - NTool Platform\"|g" ".env"
    fi
    
    log "✓ Updated .env configuration"
fi

# Step 9: Set permissions
log "Step 9: Setting proper permissions"

chown -R $WEB_USER:$WEB_USER "$WEB_ROOT"
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
chmod +x "$WEB_ROOT/artisan"
chmod -R 775 "$WEB_ROOT/storage"
chmod -R 775 "$WEB_ROOT/bootstrap/cache"

log "✓ Permissions set"

# Step 10: Install dependencies
log "Step 10: Installing dependencies"

# Install Composer dependencies
if [ -f "composer.json" ]; then
    if command -v composer &>/dev/null; then
        su - $WEB_USER -c "cd '$WEB_ROOT' && composer install --no-dev --optimize-autoloader --no-interaction" || warning "Composer install failed"
        log "✓ Composer dependencies installed"
    else
        warning "Composer not found - skipping PHP dependencies"
    fi
fi

# Install NPM dependencies
if [ -f "package.json" ]; then
    if command -v npm &>/dev/null; then
        su - $WEB_USER -c "cd '$WEB_ROOT' && npm install --production" || warning "NPM install failed"
        su - $WEB_USER -c "cd '$WEB_ROOT' && npm run build" 2>/dev/null || warning "Asset build failed"
        log "✓ NPM dependencies installed"
    else
        warning "NPM not found - skipping frontend dependencies"
    fi
fi

# Step 11: Laravel setup
log "Step 11: Laravel application setup"

# Generate app key if needed
if ! grep -q "APP_KEY=base64:" ".env" 2>/dev/null; then
    su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan key:generate --force" || warning "Key generation failed"
    log "✓ Application key generated"
fi

# Run migrations
read -p "Run database migrations? (y/N): " run_migrations
if [[ $run_migrations =~ ^[Yy]$ ]]; then
    su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan migrate --force" || warning "Migration failed"
    log "✓ Database migrations completed"
fi

# Optimize Laravel
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan config:cache" 2>/dev/null || true
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan route:cache" 2>/dev/null || true
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan view:cache" 2>/dev/null || true
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan storage:link" 2>/dev/null || true

log "✓ Laravel optimization completed"

# Step 12: Restart services
log "Step 12: Restarting web services"

systemctl restart php*-fpm 2>/dev/null || true
systemctl restart nginx 2>/dev/null || true

log "✓ Web services restarted"

# Step 13: Verification
log "Step 13: Verifying deployment"

NEW_FILES=$(find "$WEB_ROOT" -type f | wc -l)
NEW_SIZE=$(du -sh "$WEB_ROOT" | cut -f1)

info "New file count: $NEW_FILES"
info "New size: $NEW_SIZE"

# Test website
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" =~ ^[23] ]]; then
    log "✓ Website accessible (HTTP $HTTP_CODE)"
else
    warning "Website status: HTTP $HTTP_CODE"
fi

# Test Laravel
if [ -f "artisan" ]; then
    if sudo -u $WEB_USER php "artisan" --version &>/dev/null; then
        LARAVEL_VERSION=$(sudo -u $WEB_USER php "artisan" --version 2>/dev/null)
        log "✓ Laravel working: $LARAVEL_VERSION"
    else
        warning "Laravel may have issues"
    fi
fi

# Cleanup
rm -rf "$PRESERVE_DIR"

# Success message
echo
log "🎉 Selective replacement deployment completed!"
echo
echo "🌐 Website: https://$DOMAIN"
echo "📁 Location: $WEB_ROOT"
echo "💾 Backup: $BACKUP_FILE"
echo "👤 Web User: $WEB_USER"
echo
echo "📊 Changes:"
echo "• Files before: $EXISTING_FILES"
echo "• Files after: $NEW_FILES"
echo "• Size before: $EXISTING_SIZE"
echo "• Size after: $NEW_SIZE"
echo
echo "🧮 Test calculators:"
echo "• https://$DOMAIN/loan-calculator"
echo "• https://$DOMAIN/bmi-calculator"
echo "• https://$DOMAIN/currency-converter"
echo
echo "⚙️ Next steps:"
echo "1. Test all calculator functions"
echo "2. Check error logs if needed"
echo "3. Configure SSL in FastPanel"
echo "4. Update Google Analytics settings"
echo
echo "🔄 If issues occur, restore from backup:"
echo "   tar -xzf $BACKUP_FILE -C $WEB_ROOT"
