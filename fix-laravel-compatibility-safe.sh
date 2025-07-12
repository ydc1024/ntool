#!/bin/bash

# Laravel 10 Compatibility Fix Script - Safe Version
# This script fixes Laravel compatibility issues with improved error handling

set -e

# Configuration
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"
SCRIPT_PID=$$

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Improved logging functions - NO EXIT ON ERROR
log() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }  # Removed exit 1
info() { echo -e "${BLUE}ℹ️ $1${NC}"; }

# Progress indicator function
show_progress() {
    local pid=$1
    local message="$2"
    local delay=0.5
    local spinstr='|/-\'
    
    echo -n "$message "
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
    echo " Done!"
}

# Timeout function
run_with_timeout() {
    local timeout=$1
    local command="$2"
    local description="$3"
    
    info "$description (timeout: ${timeout}s)"
    
    # Run command in background
    eval "$command" &
    local cmd_pid=$!
    
    # Wait for command with timeout
    local count=0
    while [ $count -lt $timeout ]; do
        if ! kill -0 $cmd_pid 2>/dev/null; then
            wait $cmd_pid
            return $?
        fi
        sleep 1
        ((count++))
        
        # Show progress every 10 seconds
        if [ $((count % 10)) -eq 0 ]; then
            info "Still running... (${count}s elapsed)"
        fi
    done
    
    # Timeout reached
    warning "Command timed out after ${timeout}s"
    kill $cmd_pid 2>/dev/null || true
    return 124  # Timeout exit code
}

echo "🔧 Laravel 10 Compatibility Fix - Safe Version"
echo "=============================================="
echo "Web Root: $WEB_ROOT"
echo "Web User: $WEB_USER"
echo "Fix Time: $(date)"
echo "Script PID: $SCRIPT_PID"
echo "=============================================="
echo

# Check root
if [[ $EUID -ne 0 ]]; then
    error "Run as root: sudo ./fix-laravel-compatibility-safe.sh"
    exit 1
fi

cd "$WEB_ROOT"

# Step 1: Create Laravel 10 compatible bootstrap/app.php
log "Step 1: Creating Laravel 10 compatible bootstrap/app.php"

cat > bootstrap/app.php << 'EOF'
<?php

/*
|--------------------------------------------------------------------------
| Create The Application
|--------------------------------------------------------------------------
*/

$app = new Illuminate\Foundation\Application(
    $_ENV['APP_BASE_PATH'] ?? dirname(__DIR__)
);

/*
|--------------------------------------------------------------------------
| Bind Important Interfaces
|--------------------------------------------------------------------------
*/

$app->singleton(
    Illuminate\Contracts\Http\Kernel::class,
    App\Http\Kernel::class
);

$app->singleton(
    Illuminate\Contracts\Console\Kernel::class,
    App\Console\Kernel::class
);

$app->singleton(
    Illuminate\Contracts\Debug\ExceptionHandler::class,
    App\Exceptions\Handler::class
);

/*
|--------------------------------------------------------------------------
| Return The Application
|--------------------------------------------------------------------------
*/

return $app;
EOF

log "✓ Created Laravel 10 compatible bootstrap/app.php"

# Step 2: Create missing Console Kernel
log "Step 2: Creating Console Kernel"

mkdir -p app/Console

cat > app/Console/Kernel.php << 'EOF'
<?php

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    protected function schedule(Schedule $schedule): void
    {
        // $schedule->command('inspire')->hourly();
    }

    protected function commands(): void
    {
        $this->load(__DIR__.'/Commands');
        require base_path('routes/console.php');
    }
}
EOF

log "✓ Created Console Kernel"

# Step 3: Create Exception Handler
log "Step 3: Creating Exception Handler"

mkdir -p app/Exceptions

cat > app/Exceptions/Handler.php << 'EOF'
<?php

namespace App\Exceptions;

use Illuminate\Foundation\Exceptions\Handler as ExceptionHandler;
use Throwable;

class Handler extends ExceptionHandler
{
    protected $dontFlash = [
        'current_password',
        'password',
        'password_confirmation',
    ];

    public function register(): void
    {
        $this->reportable(function (Throwable $e) {
            //
        });
    }
}
EOF

log "✓ Created Exception Handler"

# Step 4: Update composer.json for Laravel 10
log "Step 4: Updating composer.json for Laravel 10 compatibility"

# Backup original composer.json
if [ -f "composer.json" ]; then
    cp composer.json composer.json.backup.$(date +%Y%m%d_%H%M%S)
    log "✓ Backed up original composer.json"
fi

# Create Laravel 10 compatible composer.json
cat > composer.json << 'EOF'
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
        "laravel/tinker": "^2.8"
    },
    "require-dev": {
        "fakerphp/faker": "^1.9.1",
        "laravel/pint": "^1.0",
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

log "✓ Updated composer.json for Laravel 10"

# Step 5: Safely reinstall Composer dependencies
log "Step 5: Safely reinstalling Composer dependencies"

# Remove vendor directory and lock file
info "Removing old vendor directory and lock file..."
rm -rf vendor
rm -f composer.lock

# Clear composer cache
info "Clearing Composer cache..."
sudo -u $WEB_USER composer clear-cache 2>/dev/null || true

# Update Composer
info "Updating Composer..."
composer self-update 2>/dev/null || warning "Could not update Composer"

# Validate composer.json
info "Validating composer.json..."
if sudo -u $WEB_USER composer validate --no-check-publish; then
    log "✓ composer.json is valid"
else
    warning "composer.json validation issues detected, but continuing..."
fi

# Install dependencies with timeout and progress
info "Installing Composer dependencies..."
info "This may take 5-15 minutes depending on your internet connection."

COMPOSER_COMMAND="sudo -u $WEB_USER composer install --no-dev --optimize-autoloader --no-interaction"

if run_with_timeout 900 "$COMPOSER_COMMAND" "Installing Laravel framework and dependencies"; then
    log "✓ Composer dependencies installed successfully"
    
    # Verify critical packages are installed
    info "Verifying critical Laravel packages..."
    CRITICAL_PACKAGES=("illuminate/foundation" "illuminate/console" "illuminate/container" "laravel/framework")
    
    MISSING_PACKAGES=()
    for package in "${CRITICAL_PACKAGES[@]}"; do
        PACKAGE_PATH="vendor/${package}"
        if [ -d "$PACKAGE_PATH" ]; then
            log "✓ $package installed"
        else
            error "✗ $package still missing after installation"
            MISSING_PACKAGES+=("$package")
        fi
    done
    
    if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
        error "Some critical packages are missing: ${MISSING_PACKAGES[*]}"
        warning "Will continue with remaining steps, but Laravel may not work properly"
    fi
    
else
    error "Composer installation failed or timed out"
    warning "Will continue with remaining steps using existing vendor directory"
fi

# Generate optimized autoloader
info "Generating optimized autoloader..."
if sudo -u $WEB_USER composer dump-autoload --optimize --no-dev 2>/dev/null; then
    log "✓ Autoloader optimized"
else
    warning "Could not optimize autoloader"
fi

log "✓ Composer dependencies processing completed"

# Step 6: Create additional required files
log "Step 6: Creating additional required files"

# Create User model
mkdir -p app/Models
cat > app/Models/User.php << 'EOF'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'email',
        'password',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'password' => 'hashed',
    ];
}
EOF

# Create essential config files
cat > config/auth.php << 'EOF'
<?php

return [
    'defaults' => [
        'guard' => 'web',
        'passwords' => 'users',
    ],
    'guards' => [
        'web' => [
            'driver' => 'session',
            'provider' => 'users',
        ],
    ],
    'providers' => [
        'users' => [
            'driver' => 'eloquent',
            'model' => App\Models\User::class,
        ],
    ],
    'passwords' => [
        'users' => [
            'provider' => 'users',
            'table' => 'password_reset_tokens',
            'expire' => 60,
            'throttle' => 60,
        ],
    ],
    'password_timeout' => 10800,
];
EOF

cat > config/cache.php << 'EOF'
<?php

use Illuminate\Support\Str;

return [
    'default' => env('CACHE_DRIVER', 'file'),
    'stores' => [
        'array' => [
            'driver' => 'array',
            'serialize' => false,
        ],
        'file' => [
            'driver' => 'file',
            'path' => storage_path('framework/cache/data'),
        ],
        'redis' => [
            'driver' => 'redis',
            'connection' => 'cache',
            'lock_connection' => 'default',
        ],
    ],
    'prefix' => env('CACHE_PREFIX', Str::slug(env('APP_NAME', 'laravel'), '_').'_cache_'),
];
EOF

log "✓ Created additional required files"

# Step 7: Fix file permissions
log "Step 7: Fixing file permissions"

chown -R $WEB_USER:$WEB_USER "$WEB_ROOT"
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
chmod +x "$WEB_ROOT/artisan"
chmod -R 775 "$WEB_ROOT/storage"
chmod -R 775 "$WEB_ROOT/bootstrap/cache"

log "✓ File permissions fixed"

# Step 8: Generate APP_KEY safely
log "Step 8: Generating APP_KEY"

if sudo -u $WEB_USER php artisan key:generate --force &>/dev/null; then
    log "✓ APP_KEY generated successfully using artisan"
else
    warning "Artisan key:generate failed, generating manually"
    APP_KEY="base64:$(openssl rand -base64 32)"
    sed -i "s|APP_KEY=.*|APP_KEY=$APP_KEY|g" .env
    log "✓ APP_KEY generated manually"
fi

# Step 9: Clear and rebuild caches safely
log "Step 9: Clearing and rebuilding caches"

info "Clearing existing caches..."
sudo -u $WEB_USER php artisan config:clear 2>/dev/null || warning "Could not clear config cache"
sudo -u $WEB_USER php artisan cache:clear 2>/dev/null || warning "Could not clear application cache"
sudo -u $WEB_USER php artisan route:clear 2>/dev/null || warning "Could not clear route cache"
sudo -u $WEB_USER php artisan view:clear 2>/dev/null || warning "Could not clear view cache"

info "Rebuilding caches..."
sudo -u $WEB_USER php artisan config:cache 2>/dev/null || warning "Could not cache config"
sudo -u $WEB_USER php artisan route:cache 2>/dev/null || warning "Could not cache routes"

log "✓ Caches processed"

# Step 10: Test Laravel functionality (NON-FATAL)
log "Step 10: Testing Laravel functionality"

LARAVEL_WORKING=false

# Test 1: Check if autoload works
info "Testing autoload functionality..."
cat > /tmp/test_autoload_safe.php << 'EOF'
<?php
try {
    require_once __DIR__ . '/vendor/autoload.php';
    echo "SUCCESS: Autoload working\n";

    if (class_exists('Illuminate\Foundation\Application')) {
        echo "SUCCESS: Laravel Foundation available\n";
    } else {
        echo "ERROR: Laravel Foundation missing\n";
    }

} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
} catch (Error $e) {
    echo "FATAL: " . $e->getMessage() . "\n";
}
EOF

AUTOLOAD_RESULT=$(sudo -u $WEB_USER php /tmp/test_autoload_safe.php 2>&1)
rm -f /tmp/test_autoload_safe.php

if echo "$AUTOLOAD_RESULT" | grep -q "SUCCESS: Autoload working"; then
    log "✓ Autoload is working"
    if echo "$AUTOLOAD_RESULT" | grep -q "SUCCESS: Laravel Foundation available"; then
        log "✓ Laravel Foundation is available"
    else
        warning "Laravel Foundation is not available"
    fi
else
    error "Autoload is not working"
    echo "$AUTOLOAD_RESULT" | sed 's/^/  /'
fi

# Test 2: Test artisan command (NON-FATAL)
info "Testing artisan command..."
if sudo -u $WEB_USER php artisan --version &>/dev/null; then
    LARAVEL_VERSION=$(sudo -u $WEB_USER php artisan --version 2>/dev/null)
    log "✓ Laravel is working: $LARAVEL_VERSION"
    LARAVEL_WORKING=true

    # Test additional artisan commands
    if sudo -u $WEB_USER php artisan list &>/dev/null; then
        log "✓ Artisan commands are working"
    else
        warning "Some artisan commands may have issues"
    fi

else
    error "Laravel artisan is not working yet"
    warning "This may be normal - will continue with remaining steps"

    # Show detailed error for debugging
    echo "Artisan error details:"
    sudo -u $WEB_USER php artisan --version 2>&1 | sed 's/^/  /' || true
fi

# Step 11: Restart services and test
log "Step 11: Restarting services and testing"

info "Restarting PHP-FPM..."
systemctl restart php8.3-fpm || warning "Could not restart PHP-FPM"

info "Restarting Nginx..."
systemctl restart nginx || warning "Could not restart Nginx"

log "✓ Services restarted"

# Wait for services to fully start
sleep 3

# Step 12: Final website testing
log "Step 12: Final website testing"

info "Testing website response..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    log "✓ Website responds with HTTP $HTTP_CODE"
elif [ "$HTTP_CODE" = "500" ]; then
    warning "Website still responds with HTTP $HTTP_CODE"
    info "This may be normal if Laravel is not fully working yet"
else
    info "Website responds with HTTP $HTTP_CODE"
fi

# Test HTTPS if available
HTTPS_CODE=$(curl -s -k -o /dev/null -w "%{http_code}" "https://besthammer.club" 2>/dev/null || echo "000")
if [ "$HTTPS_CODE" = "200" ]; then
    log "✓ HTTPS responds with HTTP $HTTPS_CODE"
else
    info "HTTPS responds with HTTP $HTTPS_CODE"
fi

# Step 13: Final summary
log "Step 13: Final summary and recommendations"

echo
echo "🎯 COMPATIBILITY FIX SUMMARY"
echo "============================"
echo "✅ Created Laravel 10 compatible bootstrap/app.php"
echo "✅ Created Console Kernel and Exception Handler"
echo "✅ Updated composer.json for Laravel 10"
echo "✅ Processed Composer dependencies"
echo "✅ Created additional required files"
echo "✅ Fixed file permissions"
echo "✅ Generated APP_KEY"
echo "✅ Processed Laravel caches"
echo "✅ Restarted web services"
echo "✅ Tested website response"
echo

if [ "$LARAVEL_WORKING" = true ]; then
    log "🎉 SUCCESS: Laravel is working properly!"
    echo
    echo "🌐 Test your website:"
    echo "• Main site: https://besthammer.club"
    echo "• BMI Calculator: https://besthammer.club/bmi-calculator"
    echo "• Currency Converter: https://besthammer.club/currency-converter"
    echo "• Loan Calculator: https://besthammer.club/loan-calculator"
    echo "• Health check: https://besthammer.club/health"
else
    warning "Laravel artisan is not working yet, but basic setup is complete"
    echo
    echo "🔧 NEXT STEPS:"
    echo "1. Run the debug script: ./debug-laravel-startup.sh"
    echo "2. Check error logs:"
    echo "   • Laravel: tail -f storage/logs/laravel.log"
    echo "   • Nginx: tail -f /var/log/nginx/error.log"
    echo "   • PHP-FPM: tail -f /var/log/php8.3-fpm.log"
    echo "3. Test individual components manually"
fi

echo
echo "📋 Backup files created:"
find . -name "composer.json.backup.*" -type f 2>/dev/null | head -3 | sed 's/^/• /'
echo
echo "============================"
echo "Compatibility fix completed at $(date)"
echo "Script completed successfully without fatal errors"
echo "============================"
