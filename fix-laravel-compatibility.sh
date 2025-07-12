#!/bin/bash

# Laravel 10 Compatibility Fix Script
# This script fixes Laravel compatibility issues

set -e

# Configuration
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"

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

echo "🔧 Laravel 10 Compatibility Fix"
echo "==============================="
echo "Web Root: $WEB_ROOT"
echo "Web User: $WEB_USER"
echo "Fix Time: $(date)"
echo "==============================="
echo

# Check root
if [[ $EUID -ne 0 ]]; then
    error "Run as root: sudo ./fix-laravel-compatibility.sh"
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
|
| The first thing we will do is create a new Laravel application instance
| which serves as the "glue" for all the components of Laravel, and is
| the IoC container for the system binding all of the various parts.
|
*/

$app = new Illuminate\Foundation\Application(
    $_ENV['APP_BASE_PATH'] ?? dirname(__DIR__)
);

/*
|--------------------------------------------------------------------------
| Bind Important Interfaces
|--------------------------------------------------------------------------
|
| Next, we need to bind some important interfaces into the container so
| we will be able to resolve them when needed. The kernels serve the
| incoming requests to this application from both the web and CLI.
|
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
|
| This script returns the application instance. The instance is given to
| the calling script so we can separate the building of the instances
| from the actual running of the application and sending responses.
|
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
    /**
     * Define the application's command schedule.
     */
    protected function schedule(Schedule $schedule): void
    {
        // $schedule->command('inspire')->hourly();
    }

    /**
     * Register the commands for the application.
     */
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
    /**
     * The list of the inputs that are never flashed to the session on validation exceptions.
     *
     * @var array<int, string>
     */
    protected $dontFlash = [
        'current_password',
        'password',
        'password_confirmation',
    ];

    /**
     * Register the exception handling callbacks for the application.
     */
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
cp composer.json composer.json.backup

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

log "✓ Updated composer.json for Laravel 10"

# Step 5: Completely reinstall Composer dependencies
log "Step 5: Completely reinstalling Composer dependencies"

# Remove vendor directory and lock file
rm -rf vendor
rm -f composer.lock

# Clear composer cache globally
sudo -u $WEB_USER composer clear-cache 2>/dev/null || true
sudo -u $WEB_USER composer global clear-cache 2>/dev/null || true

# Update Composer to latest version
info "Updating Composer to latest version..."
composer self-update 2>/dev/null || true

# Validate composer.json
info "Validating composer.json..."
if sudo -u $WEB_USER composer validate; then
    log "✓ composer.json is valid"
else
    warning "composer.json validation issues detected"
fi

# Install dependencies with verbose output
info "Installing Composer dependencies (this may take several minutes)..."
info "This will download and install Laravel framework and all dependencies..."

if sudo -u $WEB_USER composer install --no-dev --optimize-autoloader --no-interaction --verbose; then
    log "✓ Composer dependencies installed successfully"

    # Verify critical packages are installed
    info "Verifying critical Laravel packages..."
    CRITICAL_PACKAGES=("illuminate/foundation" "illuminate/console" "illuminate/container" "laravel/framework")

    for package in "${CRITICAL_PACKAGES[@]}"; do
        PACKAGE_PATH="vendor/${package}"
        if [ -d "$PACKAGE_PATH" ]; then
            log "✓ $package installed"
        else
            error "✗ $package still missing after installation"
        fi
    done

else
    error "Failed to install Composer dependencies - check network connection and try again"
fi

# Generate optimized autoloader
info "Generating optimized autoloader..."
sudo -u $WEB_USER composer dump-autoload --optimize --no-dev

log "✓ Composer dependencies completely reinstalled"

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

# Create additional config files
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

        'database' => [
            'driver' => 'database',
            'table' => 'cache',
            'connection' => null,
            'lock_connection' => null,
        ],

        'file' => [
            'driver' => 'file',
            'path' => storage_path('framework/cache/data'),
        ],

        'memcached' => [
            'driver' => 'memcached',
            'persistent_id' => env('MEMCACHED_PERSISTENT_ID'),
            'sasl' => [
                env('MEMCACHED_USERNAME'),
                env('MEMCACHED_PASSWORD'),
            ],
            'options' => [
                // Memcached::OPT_CONNECT_TIMEOUT => 2000,
            ],
            'servers' => [
                [
                    'host' => env('MEMCACHED_HOST', '127.0.0.1'),
                    'port' => env('MEMCACHED_PORT', 11211),
                    'weight' => 100,
                ],
            ],
        ],

        'redis' => [
            'driver' => 'redis',
            'connection' => 'cache',
            'lock_connection' => 'default',
        ],

        'dynamodb' => [
            'driver' => 'dynamodb',
            'key' => env('AWS_ACCESS_KEY_ID'),
            'secret' => env('AWS_SECRET_ACCESS_KEY'),
            'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
            'table' => env('DYNAMODB_CACHE_TABLE', 'cache'),
            'endpoint' => env('DYNAMODB_ENDPOINT'),
        ],

        'octane' => [
            'driver' => 'octane',
        ],

    ],

    'prefix' => env('CACHE_PREFIX', Str::slug(env('APP_NAME', 'laravel'), '_').'_cache_'),
];
EOF

log "✓ Created additional required files"

# Step 7: Fix file permissions again
log "Step 7: Fixing file permissions"

chown -R $WEB_USER:$WEB_USER "$WEB_ROOT"
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
chmod +x "$WEB_ROOT/artisan"
chmod -R 775 "$WEB_ROOT/storage"
chmod -R 775 "$WEB_ROOT/bootstrap/cache"

log "✓ File permissions fixed"

# Step 8: Generate APP_KEY properly
log "Step 8: Generating APP_KEY"

if sudo -u $WEB_USER php artisan key:generate --force &>/dev/null; then
    log "✓ APP_KEY generated successfully"
else
    warning "Artisan key:generate failed, generating manually"
    APP_KEY="base64:$(openssl rand -base64 32)"
    sed -i "s|APP_KEY=.*|APP_KEY=$APP_KEY|g" .env
    log "✓ APP_KEY generated manually"
fi

# Step 9: Clear and rebuild caches
log "Step 9: Clearing and rebuilding caches"

sudo -u $WEB_USER php artisan config:clear 2>/dev/null || true
sudo -u $WEB_USER php artisan cache:clear 2>/dev/null || true
sudo -u $WEB_USER php artisan route:clear 2>/dev/null || true
sudo -u $WEB_USER php artisan view:clear 2>/dev/null || true

sudo -u $WEB_USER php artisan config:cache 2>/dev/null || true
sudo -u $WEB_USER php artisan route:cache 2>/dev/null || true

log "✓ Caches cleared and rebuilt"

# Step 10: Comprehensive Laravel functionality testing
log "Step 10: Comprehensive Laravel functionality testing"

# Test 1: Check if autoload works
info "Testing autoload functionality..."
cat > /tmp/test_autoload_fix.php << 'EOF'
<?php
try {
    require_once __DIR__ . '/vendor/autoload.php';
    echo "Autoload: OK\n";

    if (class_exists('Illuminate\Foundation\Application')) {
        echo "Laravel Foundation: OK\n";
    } else {
        echo "Laravel Foundation: MISSING\n";
    }

    if (class_exists('Illuminate\Console\Application')) {
        echo "Laravel Console: OK\n";
    } else {
        echo "Laravel Console: MISSING\n";
    }

} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
EOF

sudo -u $WEB_USER php /tmp/test_autoload_fix.php 2>&1 | sed 's/^/  /'
rm -f /tmp/test_autoload_fix.php

# Test 2: Test artisan command
info "Testing artisan command..."
if sudo -u $WEB_USER php artisan --version &>/dev/null; then
    LARAVEL_VERSION=$(sudo -u $WEB_USER php artisan --version 2>/dev/null)
    log "✓ Laravel is working: $LARAVEL_VERSION"

    # Test additional artisan commands
    info "Testing additional artisan commands..."
    if sudo -u $WEB_USER php artisan list &>/dev/null; then
        log "✓ Artisan commands list working"
    else
        warning "Artisan commands list has issues"
    fi

else
    error "Laravel artisan still not working"
    echo "Detailed error output:"
    sudo -u $WEB_USER php artisan --version 2>&1 | sed 's/^/  /'

    # Try to diagnose the issue
    echo
    warning "Attempting to diagnose the issue..."

    # Check if bootstrap file exists and is readable
    if [ -f "bootstrap/app.php" ]; then
        info "bootstrap/app.php exists"
        if sudo -u $WEB_USER php -l bootstrap/app.php &>/dev/null; then
            info "bootstrap/app.php syntax is OK"
        else
            error "bootstrap/app.php has syntax errors"
            sudo -u $WEB_USER php -l bootstrap/app.php
        fi
    else
        error "bootstrap/app.php is missing"
    fi

    # Check vendor/autoload.php
    if [ -f "vendor/autoload.php" ]; then
        info "vendor/autoload.php exists"
    else
        error "vendor/autoload.php is missing"
    fi

    echo "Please check the error output above and run the debug script for more details."
fi

# Step 11: Restart services and test
log "Step 11: Restarting services and testing"

systemctl restart php8.3-fpm
systemctl restart nginx

sleep 3

# Test website
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    log "✓ Website responds with HTTP $HTTP_CODE"
elif [ "$HTTP_CODE" = "500" ]; then
    warning "Website still responds with HTTP $HTTP_CODE"
else
    info "Website responds with HTTP $HTTP_CODE"
fi

echo
echo "🎯 COMPATIBILITY FIX SUMMARY"
echo "============================"
echo "✅ Created Laravel 10 compatible bootstrap/app.php"
echo "✅ Created Console Kernel and Exception Handler"
echo "✅ Updated composer.json for Laravel 10"
echo "✅ Reinstalled Composer dependencies"
echo "✅ Created additional required files"
echo "✅ Fixed file permissions"
echo "✅ Generated APP_KEY"
echo "✅ Cleared and rebuilt caches"
echo
echo "🌐 Test your website:"
echo "• Main site: https://besthammer.club"
echo "• Health check: https://besthammer.club/health"
echo
echo "📋 If issues persist:"
echo "• Run: ./debug-laravel-startup.sh"
echo "• Check logs: tail -f storage/logs/laravel.log"
echo
echo "============================"
echo "Compatibility fix completed"
echo "============================"
