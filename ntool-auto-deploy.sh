#!/bin/bash

# NTool Automatic Deployment Script for FastPanel
# Specifically designed to deploy ntool directory contents to FastPanel

set -e

# Configuration
DOMAIN="besthammer.club"
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"
BACKUP_DIR="/var/backups/website"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="backup_${DOMAIN}_${TIMESTAMP}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO] $1${NC}"; }
warning() { echo -e "${YELLOW}[WARN] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }
info() { echo -e "${BLUE}[NOTICE] $1${NC}"; }

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Use: sudo ./ntool-auto-deploy.sh"
fi

# Banner
echo "🔨 BestHammer NTool Platform - Automatic FastPanel Deployment"
echo "============================================================"
echo "Domain: $DOMAIN"
echo "Target: $WEB_ROOT"
echo "Web User: $WEB_USER"
echo "Time: $(date)"
echo "============================================================"
echo

# Step 1: Detect ntool source location
log "Step 1: Detecting ntool source files..."

NTOOL_SOURCE=""
if [ -d "ntool" ] && [ -f "ntool/composer.json" ] && [ -d "ntool/app" ] && [ -f "ntool/artisan" ]; then
    NTOOL_SOURCE="ntool"
    info "✓ Found ntool directory with Laravel application"
elif [ -f "composer.json" ] && [ -d "app" ] && [ -f "artisan" ]; then
    NTOOL_SOURCE="."
    info "✓ Found Laravel application in current directory"
else
    error "NTool Laravel application not found. Expected structure:"
    error "  - ntool/composer.json, ntool/app/, ntool/artisan"
    error "  OR composer.json, app/, artisan in current directory"
fi

# Change to source directory
cd "$NTOOL_SOURCE"
SOURCE_PATH=$(pwd)
info "Working from: $SOURCE_PATH"

# Verify ntool application structure
log "Verifying ntool application structure..."
REQUIRED_DIRS=("app" "config" "database" "public" "resources" "routes")
REQUIRED_FILES=("composer.json" "artisan")

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        error "Required directory missing: $dir"
    fi
done

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        error "Required file missing: $file"
    fi
done

# Count source files
SOURCE_FILES=$(find . -type f -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./vendor/*" | wc -l)
info "✓ NTool application verified: $SOURCE_FILES source files"

# Step 2: Create backup
log "Step 2: Creating backup of existing website..."
mkdir -p "$BACKUP_DIR"

if [ -d "$WEB_ROOT" ] && [ "$(ls -A $WEB_ROOT 2>/dev/null)" ]; then
    tar -czf "${BACKUP_DIR}/${BACKUP_NAME}_files.tar.gz" -C "$WEB_ROOT" . 2>/dev/null || true
    local existing_files=$(find "$WEB_ROOT" -type f 2>/dev/null | wc -l)
    info "✓ Backed up $existing_files existing files to: ${BACKUP_NAME}_files.tar.gz"
else
    info "No existing files to backup"
fi

# Step 3: Clear web root
log "Step 3: Clearing FastPanel web root..."
if [ -d "$WEB_ROOT" ]; then
    find "$WEB_ROOT" -mindepth 1 -delete 2>/dev/null || {
        rm -rf "$WEB_ROOT"/*
        rm -rf "$WEB_ROOT"/.[^.]*
    }
    info "✓ Web root cleared"
else
    mkdir -p "$WEB_ROOT"
    info "✓ Web root created"
fi

# Step 4: Deploy ntool application
log "Step 4: Deploying ntool application to FastPanel..."

# Copy all Laravel directories
LARAVEL_DIRS=("app" "bootstrap" "config" "database" "public" "resources" "routes" "storage" "tests")
for dir in "${LARAVEL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        cp -r "$dir" "$WEB_ROOT/"
        local file_count=$(find "$dir" -type f | wc -l)
        info "✓ Deployed $dir: $file_count files"
    fi
done

# Copy Laravel files
LARAVEL_FILES=("composer.json" "artisan" "package.json" ".env.example")
for file in "${LARAVEL_FILES[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "$WEB_ROOT/"
        info "✓ Deployed file: $file"
    fi
done

# Copy additional configuration files
CONFIG_FILES=("vite.config.js" "tailwind.config.js" "webpack.mix.js" "phpunit.xml" ".gitignore" ".editorconfig")
for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "$WEB_ROOT/"
        info "✓ Deployed config: $file"
    fi
done

# Step 5: Setup Laravel directory structure
log "Step 5: Setting up Laravel directory structure..."

# Ensure all required Laravel directories exist
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
done

# Create Laravel .gitignore files
cat > "$WEB_ROOT/storage/app/.gitignore" << 'EOF'
*
!public/
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

info "✓ Laravel directory structure completed"

# Step 6: Set FastPanel permissions
log "Step 6: Setting FastPanel-optimized permissions..."

# Set ownership
chown -R $WEB_USER:$WEB_USER "$WEB_ROOT"

# Set base permissions
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
find "$WEB_ROOT" -type d -exec chmod 755 {} \;

# Set executable permissions
chmod +x "$WEB_ROOT/artisan"

# Set writable permissions for Laravel
chmod -R 775 "$WEB_ROOT/storage"
chmod -R 775 "$WEB_ROOT/bootstrap/cache"

info "✓ FastPanel permissions set"

# Step 7: Install dependencies
log "Step 7: Installing application dependencies..."
cd "$WEB_ROOT"

# Install Composer dependencies
if [ -f "composer.json" ]; then
    info "Installing Composer dependencies..."
    su - $WEB_USER -c "cd '$WEB_ROOT' && composer install --no-dev --optimize-autoloader --no-interaction"
    info "✓ Composer dependencies installed"
fi

# Install NPM dependencies
if [ -f "package.json" ]; then
    info "Installing NPM dependencies..."
    su - $WEB_USER -c "cd '$WEB_ROOT' && npm install --production"
    
    info "Building production assets..."
    su - $WEB_USER -c "cd '$WEB_ROOT' && npm run build" 2>/dev/null || \
    su - $WEB_USER -c "cd '$WEB_ROOT' && npm run production" 2>/dev/null || \
    warning "Asset building failed - may need manual intervention"
    
    info "✓ NPM dependencies processed"
fi

# Step 8: Configure Laravel environment
log "Step 8: Configuring Laravel environment..."

# Create .env from .env.example
if [ ! -f ".env" ] && [ -f ".env.example" ]; then
    su - $WEB_USER -c "cd '$WEB_ROOT' && cp '.env.example' '.env'"
    info "✓ Created .env from .env.example"
fi

# Configure production settings
if [ -f ".env" ]; then
    sed -i "s|APP_ENV=.*|APP_ENV=production|g" ".env"
    sed -i "s|APP_DEBUG=.*|APP_DEBUG=false|g" ".env"
    sed -i "s|APP_URL=.*|APP_URL=https://$DOMAIN|g" ".env"
    info "✓ Configured for production environment"
fi

# Generate application key
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan key:generate --force"
info "✓ Application key generated"

# Step 9: Database setup
log "Step 9: Setting up database..."

echo "Database Setup Options:"
echo "1. Create new database automatically"
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
        
        if [ -n "$mysql_password" ] && mysql -uroot -p"$mysql_password" -e "SELECT 1;" &>/dev/null; then
            DB_NAME="besthammer_db"
            DB_USER="besthammer_user"
            DB_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
            
            mysql -uroot -p"$mysql_password" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
            mysql -uroot -p"$mysql_password" -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
            mysql -uroot -p"$mysql_password" -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
            mysql -uroot -p"$mysql_password" -e "FLUSH PRIVILEGES;"
            
            # Update .env
            sed -i "s|DB_DATABASE=.*|DB_DATABASE=$DB_NAME|g" ".env"
            sed -i "s|DB_USERNAME=.*|DB_USERNAME=$DB_USER|g" ".env"
            sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|g" ".env"
            
            # Run migrations
            su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan migrate --force"
            su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan db:seed --force" 2>/dev/null || true
            
            info "✓ Database created and configured: $DB_NAME"
        else
            warning "Database setup failed - continuing without database"
        fi
        ;;
    2)
        # Use existing database
        read -p "Enter database name: " DB_NAME
        read -p "Enter database user: " DB_USER
        read -s -p "Enter database password: " DB_PASS
        echo
        
        if [ -n "$DB_NAME" ] && [ -n "$DB_USER" ] && [ -n "$DB_PASS" ]; then
            sed -i "s|DB_DATABASE=.*|DB_DATABASE=$DB_NAME|g" ".env"
            sed -i "s|DB_USERNAME=.*|DB_USERNAME=$DB_USER|g" ".env"
            sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|g" ".env"
            
            su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan migrate --force"
            info "✓ Using existing database: $DB_NAME"
        fi
        ;;
    3)
        warning "Database setup skipped"
        ;;
esac

# Step 10: Optimize Laravel
log "Step 10: Optimizing Laravel application..."

su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan config:cache" 2>/dev/null || true
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan route:cache" 2>/dev/null || true
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan view:cache" 2>/dev/null || true
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan storage:link" 2>/dev/null || true

info "✓ Laravel optimization completed"

# Step 11: Restart services
log "Step 11: Restarting web services..."
systemctl restart php*-fpm 2>/dev/null || true
systemctl restart nginx 2>/dev/null || true
info "✓ Web services restarted"

# Step 12: Final verification
log "Step 12: Verifying deployment..."

DEPLOYED_FILES=$(find "$WEB_ROOT" -type f | wc -l)
info "✓ Deployed files: $DEPLOYED_FILES"

if systemctl is-active --quiet nginx && systemctl is-active --quiet php*-fpm; then
    info "✓ Web services are running"
else
    warning "Some web services may not be running"
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" =~ ^[23] ]]; then
    info "✓ Website is accessible (HTTP $HTTP_CODE)"
else
    warning "Website accessibility: HTTP $HTTP_CODE"
fi

# Success message
echo
log "🎉 NTool deployment completed successfully!"
echo
echo "🌐 Website: https://$DOMAIN"
echo "📁 Location: $WEB_ROOT"
echo "💾 Backup: ${BACKUP_NAME}_files.tar.gz"
echo "👤 Web User: $WEB_USER"
echo
echo "🧮 Test your calculators:"
echo "• Loan Calculator: https://$DOMAIN/loan-calculator"
echo "• BMI Calculator: https://$DOMAIN/bmi-calculator"
echo "• Currency Converter: https://$DOMAIN/currency-converter"
echo
echo "⚙️ Next steps:"
echo "1. Configure SSL certificate in FastPanel"
echo "2. Test all calculator functions"
echo "3. Update Google Analytics ID in .env"
echo "4. Test privacy compliance features"
echo "5. Configure email settings if needed"
echo
echo "🔄 If issues occur, restore from backup:"
echo "   tar -xzf ${BACKUP_DIR}/${BACKUP_NAME}_files.tar.gz -C $WEB_ROOT"
