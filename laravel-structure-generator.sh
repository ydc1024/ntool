#!/bin/bash

# Laravel Structure Generator and Website Cleaner
# Creates complete Laravel directory structure and removes all unrelated files

set -e

# Configuration
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"
DOMAIN="besthammer.club"
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

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Use: sudo ./laravel-structure-generator.sh"
fi

echo "🏗️ Laravel Structure Generator & Website Cleaner"
echo "==============================================="
echo "Target: $WEB_ROOT"
echo "Web User: $WEB_USER"
echo "Time: $(date)"
echo "==============================================="
echo

# Step 1: Comprehensive backup
log "Step 1: Creating comprehensive backup..."
BACKUP_DIR="/var/backups/website"
BACKUP_NAME="complete_backup_${DOMAIN}_${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

if [ -d "$WEB_ROOT" ] && [ "$(ls -A $WEB_ROOT 2>/dev/null)" ]; then
    # Count existing files
    EXISTING_FILES=$(find "$WEB_ROOT" -type f 2>/dev/null | wc -l)
    EXISTING_DIRS=$(find "$WEB_ROOT" -type d 2>/dev/null | wc -l)
    
    info "Found $EXISTING_FILES files in $EXISTING_DIRS directories"
    
    # Create backup
    tar -czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" -C "$WEB_ROOT" . 2>/dev/null || true
    
    # Verify backup
    if [ -f "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" ]; then
        BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)
        log "Backup created: ${BACKUP_NAME}.tar.gz ($BACKUP_SIZE)"
    else
        error "Backup creation failed"
    fi
else
    info "No existing files to backup"
fi

# Step 2: Complete website cleanup
log "Step 2: Performing complete website cleanup..."

if [ -d "$WEB_ROOT" ]; then
    # List what will be removed (for logging)
    info "Removing all existing website files..."
    
    # Remove all files and directories
    find "$WEB_ROOT" -mindepth 1 -delete 2>/dev/null || {
        # Fallback method
        rm -rf "$WEB_ROOT"/*
        rm -rf "$WEB_ROOT"/.[^.]*
    }
    
    log "Complete cleanup finished"
else
    mkdir -p "$WEB_ROOT"
    log "Web root directory created"
fi

# Step 3: Generate complete Laravel directory structure
log "Step 3: Generating Laravel directory structure..."

# Create all Laravel directories
LARAVEL_DIRS=(
    "app/Console/Commands"
    "app/Exceptions"
    "app/Http/Controllers/Auth"
    "app/Http/Controllers/Api"
    "app/Http/Middleware"
    "app/Http/Requests"
    "app/Models"
    "app/Providers"
    "app/Services"
    "bootstrap/cache"
    "config"
    "database/factories"
    "database/migrations"
    "database/seeders"
    "public/css"
    "public/js"
    "public/images"
    "public/assets"
    "resources/css"
    "resources/js"
    "resources/views/layouts"
    "resources/views/components"
    "resources/views/auth"
    "resources/views/calculators"
    "resources/views/privacy"
    "resources/lang/en"
    "routes"
    "storage/app/public"
    "storage/framework/cache/data"
    "storage/framework/sessions"
    "storage/framework/views"
    "storage/framework/testing"
    "storage/logs"
    "tests/Feature"
    "tests/Unit"
)

for dir in "${LARAVEL_DIRS[@]}"; do
    mkdir -p "$WEB_ROOT/$dir"
done

info "✓ Created ${#LARAVEL_DIRS[@]} Laravel directories"

# Step 4: Generate essential Laravel files
log "Step 4: Generating essential Laravel files..."

# Create artisan file
cat > "$WEB_ROOT/artisan" << 'EOF'
#!/usr/bin/env php
<?php

define('LARAVEL_START', microtime(true));

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';

$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);

$status = $kernel->handle(
    $input = new Symfony\Component\Console\Input\ArgvInput,
    new Symfony\Component\Console\Output\ConsoleOutput
);

$kernel->terminate($input, $status);

exit($status);
EOF

# Create public/index.php
cat > "$WEB_ROOT/public/index.php" << 'EOF'
<?php

use Illuminate\Contracts\Http\Kernel;
use Illuminate\Http\Request;

define('LARAVEL_START', microtime(true));

if (file_exists($maintenance = __DIR__.'/../storage/framework/maintenance.php')) {
    require $maintenance;
}

require_once __DIR__.'/../vendor/autoload.php';

$app = require_once __DIR__.'/../bootstrap/app.php';

$kernel = $app->make(Kernel::class);

$response = $kernel->handle(
    $request = Request::capture()
)->send();

$kernel->terminate($request, $response);
EOF

# Create composer.json
cat > "$WEB_ROOT/composer.json" << 'EOF'
{
    "name": "besthammer/ntool-platform",
    "type": "project",
    "description": "BestHammer NTool Platform - Professional calculation tools",
    "keywords": ["laravel", "calculator", "loan", "bmi", "currency", "converter"],
    "license": "MIT",
    "require": {
        "php": "^8.1",
        "guzzlehttp/guzzle": "^7.2",
        "laravel/framework": "^10.10",
        "laravel/sanctum": "^3.2",
        "laravel/tinker": "^2.8",
        "predis/predis": "^2.0"
    },
    "require-dev": {
        "fakerphp/faker": "^1.9.1",
        "laravel/pint": "^1.0",
        "laravel/sail": "^1.18",
        "mockery/mockery": "^1.4.4",
        "nunomaduro/collision": "^7.0",
        "phpunit/phpunit": "^10.1",
        "spatie/laravel-ignition": "^2.0"
    },
    "autoload": {
        "psr-4": {
            "App\\": "app/",
            "Database\\Factories\\": "database/factories/",
            "Database\\Seeders\\": "database/seeders/"
        }
    },
    "autoload-dev": {
        "psr-4": {
            "Tests\\": "tests/"
        }
    },
    "scripts": {
        "post-autoload-dump": [
            "Illuminate\\Foundation\\ComposerScripts::postAutoloadDump",
            "@php artisan package:discover --ansi"
        ],
        "post-update-cmd": [
            "@php artisan vendor:publish --tag=laravel-assets --ansi --force"
        ],
        "post-root-package-install": [
            "@php -r \"file_exists('.env') || copy('.env.example', '.env');\""
        ],
        "post-create-project-cmd": [
            "@php artisan key:generate --ansi"
        ]
    },
    "extra": {
        "laravel": {
            "dont-discover": []
        }
    },
    "config": {
        "optimize-autoloader": true,
        "preferred-install": "dist",
        "sort-packages": true,
        "allow-plugins": {
            "pestphp/pest-plugin": true,
            "php-http/discovery": true
        }
    },
    "minimum-stability": "stable",
    "prefer-stable": true
}
EOF

# Create .env.example
cat > "$WEB_ROOT/.env.example" << 'EOF'
APP_NAME="BestHammer - NTool Platform"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=https://besthammer.club

LOG_CHANNEL=stack
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=besthammer_db
DB_USERNAME=besthammer_user
DB_PASSWORD=

BROADCAST_DRIVER=log
CACHE_DRIVER=redis
FILESYSTEM_DISK=local
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
SESSION_LIFETIME=120

MEMCACHED_HOST=127.0.0.1

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=localhost
MAIL_PORT=587
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS="noreply@besthammer.club"
MAIL_FROM_NAME="${APP_NAME}"

CURRENCY_API_KEY=
CURRENCY_API_URL=https://api.exchangerate-api.com/v4/latest/

GA4_MEASUREMENT_ID=GA_MEASUREMENT_ID_PLACEHOLDER
GTM_ID=
GOOGLE_OPTIMIZE_ID=
ANALYTICS_DEBUG=false

FREE_EXPERIENCE_MODE=true
FREE_EXPERIENCE_DURATION=90
FREE_EXPERIENCE_START_DATE=2024-01-01
ENFORCE_SUBSCRIPTIONS=false
TRACK_USAGE_IN_FREE_MODE=true

PRIVACY_EMAIL=privacy@besthammer.club
ADMIN_EMAIL=admin@besthammer.club
EOF

# Create package.json
cat > "$WEB_ROOT/package.json" << 'EOF'
{
    "name": "besthammer-ntool",
    "version": "1.0.0",
    "description": "BestHammer NTool Platform Frontend Assets",
    "private": true,
    "scripts": {
        "dev": "vite",
        "build": "vite build",
        "watch": "vite build --watch",
        "hot": "vite --host"
    },
    "devDependencies": {
        "@vitejs/plugin-laravel": "^0.7.5",
        "axios": "^1.1.2",
        "laravel-vite-plugin": "^0.7.2",
        "lodash": "^4.17.19",
        "postcss": "^8.1.14",
        "vite": "^4.0.0"
    },
    "dependencies": {
        "alpinejs": "^3.10.2",
        "chart.js": "^3.9.1",
        "tailwindcss": "^3.2.0",
        "autoprefixer": "^10.4.12"
    }
}
EOF

# Step 5: Create Laravel .gitignore files
log "Step 5: Creating Laravel .gitignore files..."

# Main .gitignore
cat > "$WEB_ROOT/.gitignore" << 'EOF'
/node_modules
/public/build
/public/hot
/public/storage
/storage/*.key
/vendor
.env
.env.backup
.env.production
.phpunit.result.cache
Homestead.json
Homestead.yaml
auth.json
npm-debug.log
yarn-error.log
/.fleet
/.idea
/.vscode
EOF

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

cat > "$WEB_ROOT/storage/framework/.gitignore" << 'EOF'
compiled.php
config.php
down
events.scanned.php
maintenance.php
routes.php
routes.scanned.php
schedule-*
services.json
EOF

cat > "$WEB_ROOT/storage/framework/cache/.gitignore" << 'EOF'
*
!data/
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

cat > "$WEB_ROOT/storage/framework/testing/.gitignore" << 'EOF'
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

info "✓ Created Laravel .gitignore files"

# Step 6: Set proper permissions
log "Step 6: Setting Laravel-optimized permissions..."

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

# Ensure public directory is readable
chmod -R 755 "$WEB_ROOT/public"

info "✓ Laravel permissions set"

# Step 7: Verification
log "Step 7: Verifying Laravel structure..."

# Count created files and directories
CREATED_FILES=$(find "$WEB_ROOT" -type f | wc -l)
CREATED_DIRS=$(find "$WEB_ROOT" -type d | wc -l)

# Verify essential files
ESSENTIAL_FILES=("artisan" "composer.json" ".env.example" "public/index.php")
MISSING_FILES=()

for file in "${ESSENTIAL_FILES[@]}"; do
    if [ ! -f "$WEB_ROOT/$file" ]; then
        MISSING_FILES+=("$file")
    fi
done

if [ ${#MISSING_FILES[@]} -eq 0 ]; then
    log "✓ All essential Laravel files created"
else
    warning "Missing files: ${MISSING_FILES[*]}"
fi

# Verify directory structure
ESSENTIAL_DIRS=("app" "config" "database" "public" "resources" "routes" "storage")
MISSING_DIRS=()

for dir in "${ESSENTIAL_DIRS[@]}"; do
    if [ ! -d "$WEB_ROOT/$dir" ]; then
        MISSING_DIRS+=("$dir")
    fi
done

if [ ${#MISSING_DIRS[@]} -eq 0 ]; then
    log "✓ All essential Laravel directories created"
else
    warning "Missing directories: ${MISSING_DIRS[*]}"
fi

# Final summary
echo
log "🎉 Laravel structure generation completed!"
echo
info "Summary:"
info "• Created files: $CREATED_FILES"
info "• Created directories: $CREATED_DIRS"
info "• Web root: $WEB_ROOT"
info "• Web user: $WEB_USER"
info "• Backup: ${BACKUP_NAME}.tar.gz"
echo
info "Next steps:"
info "1. Copy your application files to $WEB_ROOT"
info "2. Run composer install"
info "3. Configure .env file"
info "4. Run Laravel migrations"
echo
if [ -f "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" ]; then
    info "🔄 Restore backup if needed:"
    info "   tar -xzf ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz -C $WEB_ROOT"
fi
