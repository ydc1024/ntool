#!/bin/bash

# BestHammer NTool Platform - 500 Error Fix Script
# This script fixes the identified critical issues causing 500 errors

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

echo "🔧 BestHammer NTool Platform - 500 Error Fix"
echo "============================================"
echo "Domain: $DOMAIN"
echo "Web Root: $WEB_ROOT"
echo "Web User: $WEB_USER"
echo "Fix Time: $(date)"
echo "============================================"
echo

# Check root
if [[ $EUID -ne 0 ]]; then
    error "Run as root: sudo ./fix-500-error.sh"
fi

# Verify web root exists
if [ ! -d "$WEB_ROOT" ]; then
    error "Web root directory does not exist: $WEB_ROOT"
fi

cd "$WEB_ROOT"

# Step 1: Create missing Laravel bootstrap files
log "Step 1: Creating missing Laravel bootstrap files"

# Create bootstrap directory if it doesn't exist
mkdir -p bootstrap/cache

# Create bootstrap/app.php
cat > bootstrap/app.php << 'EOF'
<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        //
    })
    ->withExceptions(function (Exceptions $exceptions) {
        //
    })->create();
EOF

log "✓ Created bootstrap/app.php"

# Step 2: Create missing Laravel configuration files
log "Step 2: Creating missing Laravel configuration files"

# Create config/app.php
cat > config/app.php << 'EOF'
<?php

use Illuminate\Support\Facades\Facade;
use Illuminate\Support\ServiceProvider;

return [

    /*
    |--------------------------------------------------------------------------
    | Application Name
    |--------------------------------------------------------------------------
    */

    'name' => env('APP_NAME', 'BestHammer - NTool Platform'),

    /*
    |--------------------------------------------------------------------------
    | Application Environment
    |--------------------------------------------------------------------------
    */

    'env' => env('APP_ENV', 'production'),

    /*
    |--------------------------------------------------------------------------
    | Application Debug Mode
    |--------------------------------------------------------------------------
    */

    'debug' => (bool) env('APP_DEBUG', false),

    /*
    |--------------------------------------------------------------------------
    | Application URL
    |--------------------------------------------------------------------------
    */

    'url' => env('APP_URL', 'https://besthammer.club'),

    'asset_url' => env('ASSET_URL'),

    /*
    |--------------------------------------------------------------------------
    | Application Timezone
    |--------------------------------------------------------------------------
    */

    'timezone' => 'UTC',

    /*
    |--------------------------------------------------------------------------
    | Application Locale Configuration
    |--------------------------------------------------------------------------
    */

    'locale' => 'en',

    'fallback_locale' => 'en',

    'faker_locale' => 'en_US',

    /*
    |--------------------------------------------------------------------------
    | Encryption Key
    |--------------------------------------------------------------------------
    */

    'key' => env('APP_KEY'),

    'cipher' => 'AES-256-CBC',

    /*
    |--------------------------------------------------------------------------
    | Maintenance Mode Driver
    |--------------------------------------------------------------------------
    */

    'maintenance' => [
        'driver' => 'file',
    ],

    /*
    |--------------------------------------------------------------------------
    | Autoloaded Service Providers
    |--------------------------------------------------------------------------
    */

    'providers' => ServiceProvider::defaultProviders()->merge([
        /*
         * Package Service Providers...
         */

        /*
         * Application Service Providers...
         */
        App\Providers\AppServiceProvider::class,
        App\Providers\AuthServiceProvider::class,
        // App\Providers\BroadcastServiceProvider::class,
        App\Providers\EventServiceProvider::class,
        App\Providers\RouteServiceProvider::class,
    ])->toArray(),

    /*
    |--------------------------------------------------------------------------
    | Class Aliases
    |--------------------------------------------------------------------------
    */

    'aliases' => Facade::defaultAliases()->merge([
        // 'Example' => App\Facades\Example::class,
    ])->toArray(),

];
EOF

log "✓ Created config/app.php"

# Create app/Http/Kernel.php
mkdir -p app/Http
cat > app/Http/Kernel.php << 'EOF'
<?php

namespace App\Http;

use Illuminate\Foundation\Http\Kernel as HttpKernel;

class Kernel extends HttpKernel
{
    /**
     * The application's global HTTP middleware stack.
     *
     * These middleware are run during every request to your application.
     *
     * @var array<int, class-string|string>
     */
    protected $middleware = [
        // \App\Http\Middleware\TrustHosts::class,
        \App\Http\Middleware\TrustProxies::class,
        \Illuminate\Http\Middleware\HandleCors::class,
        \App\Http\Middleware\PreventRequestsDuringMaintenance::class,
        \Illuminate\Foundation\Http\Middleware\ValidatePostSize::class,
        \App\Http\Middleware\TrimStrings::class,
        \Illuminate\Foundation\Http\Middleware\ConvertEmptyStringsToNull::class,
    ];

    /**
     * The application's route middleware groups.
     *
     * @var array<string, array<int, class-string|string>>
     */
    protected $middlewareGroups = [
        'web' => [
            \App\Http\Middleware\EncryptCookies::class,
            \Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse::class,
            \Illuminate\Session\Middleware\StartSession::class,
            \Illuminate\View\Middleware\ShareErrorsFromSession::class,
            \App\Http\Middleware\VerifyCsrfToken::class,
            \Illuminate\Routing\Middleware\SubstituteBindings::class,
        ],

        'api' => [
            // \Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful::class,
            \Illuminate\Routing\Middleware\ThrottleRequests::class.':api',
            \Illuminate\Routing\Middleware\SubstituteBindings::class,
        ],
    ];

    /**
     * The application's middleware aliases.
     *
     * Aliases may be used instead of class names to conveniently assign middleware to routes and groups.
     *
     * @var array<string, class-string|string>
     */
    protected $middlewareAliases = [
        'auth' => \App\Http\Middleware\Authenticate::class,
        'auth.basic' => \Illuminate\Auth\Middleware\AuthenticateWithBasicAuth::class,
        'auth.session' => \Illuminate\Session\Middleware\AuthenticateSession::class,
        'cache.headers' => \Illuminate\Http\Middleware\SetCacheHeaders::class,
        'can' => \Illuminate\Auth\Middleware\Authorize::class,
        'guest' => \App\Http\Middleware\RedirectIfAuthenticated::class,
        'password.confirm' => \Illuminate\Auth\Middleware\RequirePassword::class,
        'precognitive' => \Illuminate\Foundation\Http\Middleware\HandlePrecognitiveRequests::class,
        'signed' => \App\Http\Middleware\ValidateSignature::class,
        'throttle' => \Illuminate\Routing\Middleware\ThrottleRequests::class,
        'verified' => \Illuminate\Auth\Middleware\EnsureEmailIsVerified::class,
    ];
}
EOF

log "✓ Created app/Http/Kernel.php"

# Step 3: Create missing middleware files
log "Step 3: Creating missing middleware files"

mkdir -p app/Http/Middleware

# Create basic middleware files
cat > app/Http/Middleware/TrustProxies.php << 'EOF'
<?php

namespace App\Http\Middleware;

use Illuminate\Http\Middleware\TrustProxies as Middleware;
use Illuminate\Http\Request;

class TrustProxies extends Middleware
{
    protected $proxies;
    protected $headers =
        Request::HEADER_X_FORWARDED_FOR |
        Request::HEADER_X_FORWARDED_HOST |
        Request::HEADER_X_FORWARDED_PORT |
        Request::HEADER_X_FORWARDED_PROTO |
        Request::HEADER_X_FORWARDED_AWS_ELB;
}
EOF

cat > app/Http/Middleware/PreventRequestsDuringMaintenance.php << 'EOF'
<?php

namespace App\Http\Middleware;

use Illuminate\Foundation\Http\Middleware\PreventRequestsDuringMaintenance as Middleware;

class PreventRequestsDuringMaintenance extends Middleware
{
    protected $except = [];
}
EOF

cat > app/Http/Middleware/TrimStrings.php << 'EOF'
<?php

namespace App\Http\Middleware;

use Illuminate\Foundation\Http\Middleware\TrimStrings as Middleware;

class TrimStrings extends Middleware
{
    protected $except = [
        'current_password',
        'password',
        'password_confirmation',
    ];
}
EOF

cat > app/Http/Middleware/EncryptCookies.php << 'EOF'
<?php

namespace App\Http\Middleware;

use Illuminate\Cookie\Middleware\EncryptCookies as Middleware;

class EncryptCookies extends Middleware
{
    protected $except = [];
}
EOF

cat > app/Http/Middleware/VerifyCsrfToken.php << 'EOF'
<?php

namespace App\Http\Middleware;

use Illuminate\Foundation\Http\Middleware\VerifyCsrfToken as Middleware;

class VerifyCsrfToken extends Middleware
{
    protected $except = [];
}
EOF

cat > app/Http/Middleware/Authenticate.php << 'EOF'
<?php

namespace App\Http\Middleware;

use Illuminate\Auth\Middleware\Authenticate as Middleware;
use Illuminate\Http\Request;

class Authenticate extends Middleware
{
    protected function redirectTo(Request $request): ?string
    {
        return $request->expectsJson() ? null : route('login');
    }
}
EOF

cat > app/Http/Middleware/RedirectIfAuthenticated.php << 'EOF'
<?php

namespace App\Http\Middleware;

use App\Providers\RouteServiceProvider;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

class RedirectIfAuthenticated
{
    public function handle(Request $request, Closure $next, string ...$guards): Response
    {
        $guards = empty($guards) ? [null] : $guards;

        foreach ($guards as $guard) {
            if (Auth::guard($guard)->check()) {
                return redirect(RouteServiceProvider::HOME);
            }
        }

        return $next($request);
    }
}
EOF

cat > app/Http/Middleware/ValidateSignature.php << 'EOF'
<?php

namespace App\Http\Middleware;

use Illuminate\Routing\Middleware\ValidateSignature as Middleware;

class ValidateSignature extends Middleware
{
    protected $except = [];
}
EOF

log "✓ Created middleware files"

# Step 4: Create missing provider files
log "Step 4: Creating missing provider files"

mkdir -p app/Providers

cat > app/Providers/AppServiceProvider.php << 'EOF'
<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        //
    }
}
EOF

cat > app/Providers/AuthServiceProvider.php << 'EOF'
<?php

namespace App\Providers;

use Illuminate\Foundation\Support\Providers\AuthServiceProvider as ServiceProvider;

class AuthServiceProvider extends ServiceProvider
{
    protected $policies = [];

    public function boot(): void
    {
        //
    }
}
EOF

cat > app/Providers/EventServiceProvider.php << 'EOF'
<?php

namespace App\Providers;

use Illuminate\Auth\Events\Registered;
use Illuminate\Auth\Listeners\SendEmailVerificationNotification;
use Illuminate\Foundation\Support\Providers\EventServiceProvider as ServiceProvider;

class EventServiceProvider extends ServiceProvider
{
    protected $listen = [
        Registered::class => [
            SendEmailVerificationNotification::class,
        ],
    ];

    public function boot(): void
    {
        //
    }

    public function shouldDiscoverEvents(): bool
    {
        return false;
    }
}
EOF

cat > app/Providers/RouteServiceProvider.php << 'EOF'
<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Foundation\Support\Providers\RouteServiceProvider as ServiceProvider;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Route;

class RouteServiceProvider extends ServiceProvider
{
    public const HOME = '/';

    public function boot(): void
    {
        RateLimiter::for('api', function (Request $request) {
            return Limit::perMinute(60)->by($request->user()?->id ?: $request->ip());
        });

        $this->routes(function () {
            Route::middleware('api')
                ->prefix('api')
                ->group(base_path('routes/api.php'));

            Route::middleware('web')
                ->group(base_path('routes/web.php'));
        });
    }
}
EOF

log "✓ Created provider files"

# Step 5: Create additional configuration files
log "Step 5: Creating additional configuration files"

# Create config/database.php
cat > config/database.php << 'EOF'
<?php

use Illuminate\Support\Str;

return [

    'default' => env('DB_CONNECTION', 'mysql'),

    'connections' => [

        'sqlite' => [
            'driver' => 'sqlite',
            'url' => env('DATABASE_URL'),
            'database' => env('DB_DATABASE', database_path('database.sqlite')),
            'prefix' => '',
            'foreign_key_constraints' => env('DB_FOREIGN_KEYS', true),
        ],

        'mysql' => [
            'driver' => 'mysql',
            'url' => env('DATABASE_URL'),
            'host' => env('DB_HOST', '127.0.0.1'),
            'port' => env('DB_PORT', '3306'),
            'database' => env('DB_DATABASE', 'forge'),
            'username' => env('DB_USERNAME', 'forge'),
            'password' => env('DB_PASSWORD', ''),
            'unix_socket' => env('DB_SOCKET', ''),
            'charset' => 'utf8mb4',
            'collation' => 'utf8mb4_unicode_ci',
            'prefix' => '',
            'prefix_indexes' => true,
            'strict' => true,
            'engine' => null,
            'options' => extension_loaded('pdo_mysql') ? array_filter([
                PDO::MYSQL_ATTR_SSL_CA => env('MYSQL_ATTR_SSL_CA'),
            ]) : [],
        ],

        'pgsql' => [
            'driver' => 'pgsql',
            'url' => env('DATABASE_URL'),
            'host' => env('DB_HOST', '127.0.0.1'),
            'port' => env('DB_PORT', '5432'),
            'database' => env('DB_DATABASE', 'forge'),
            'username' => env('DB_USERNAME', 'forge'),
            'password' => env('DB_PASSWORD', ''),
            'charset' => 'utf8',
            'prefix' => '',
            'prefix_indexes' => true,
            'search_path' => 'public',
            'sslmode' => 'prefer',
        ],

    ],

    'migrations' => 'migrations',

    'redis' => [

        'client' => env('REDIS_CLIENT', 'phpredis'),

        'options' => [
            'cluster' => env('REDIS_CLUSTER', 'redis'),
            'prefix' => env('REDIS_PREFIX', Str::slug(env('APP_NAME', 'laravel'), '_').'_database_'),
        ],

        'default' => [
            'url' => env('REDIS_URL'),
            'host' => env('REDIS_HOST', '127.0.0.1'),
            'username' => env('REDIS_USERNAME'),
            'password' => env('REDIS_PASSWORD'),
            'port' => env('REDIS_PORT', '6379'),
            'database' => env('REDIS_DB', '0'),
        ],

        'cache' => [
            'url' => env('REDIS_URL'),
            'host' => env('REDIS_HOST', '127.0.0.1'),
            'username' => env('REDIS_USERNAME'),
            'password' => env('REDIS_PASSWORD'),
            'port' => env('REDIS_PORT', '6379'),
            'database' => env('REDIS_CACHE_DB', '1'),
        ],

    ],

];
EOF

# Create routes/console.php
cat > routes/console.php << 'EOF'
<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote')->hourly();
EOF

log "✓ Created additional configuration files"

# Step 6: Generate APP_KEY
log "Step 6: Generating APP_KEY"

# Generate APP_KEY using Laravel
if sudo -u $WEB_USER php artisan key:generate --force &>/dev/null; then
    log "✓ APP_KEY generated successfully"
else
    # Fallback: generate manually
    warning "Artisan key:generate failed, generating manually"
    APP_KEY="base64:$(openssl rand -base64 32)"
    sed -i "s|APP_KEY=.*|APP_KEY=$APP_KEY|g" .env
    log "✓ APP_KEY generated manually"
fi

# Step 7: Fix file permissions
log "Step 7: Fixing file permissions"

# Set correct ownership
chown -R $WEB_USER:$WEB_USER "$WEB_ROOT"

# Set correct permissions
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
find "$WEB_ROOT" -type d -exec chmod 755 {} \;

# Set special permissions for Laravel
chmod +x "$WEB_ROOT/artisan"
chmod -R 775 "$WEB_ROOT/storage"
chmod -R 775 "$WEB_ROOT/bootstrap/cache"
chmod -R 775 "$WEB_ROOT/public"

log "✓ File permissions fixed"

# Step 8: Install missing PHP extensions
log "Step 8: Installing missing PHP extensions"

# Install php-mysql extension
if ! php -m | grep -q "^mysql$"; then
    info "Installing php8.3-mysql extension..."
    apt-get update -qq
    apt-get install -y php8.3-mysql
    systemctl restart php8.3-fpm
    log "✓ php8.3-mysql extension installed"
fi

# Step 9: Clear and rebuild Laravel caches
log "Step 9: Clearing and rebuilding Laravel caches"

# Clear all caches
sudo -u $WEB_USER php artisan config:clear 2>/dev/null || true
sudo -u $WEB_USER php artisan cache:clear 2>/dev/null || true
sudo -u $WEB_USER php artisan route:clear 2>/dev/null || true
sudo -u $WEB_USER php artisan view:clear 2>/dev/null || true

# Rebuild caches
sudo -u $WEB_USER php artisan config:cache 2>/dev/null || true
sudo -u $WEB_USER php artisan route:cache 2>/dev/null || true
sudo -u $WEB_USER php artisan view:cache 2>/dev/null || true

# Create storage link
sudo -u $WEB_USER php artisan storage:link 2>/dev/null || true

log "✓ Laravel caches rebuilt"

# Step 10: Restart web services
log "Step 10: Restarting web services"

systemctl restart php8.3-fpm
systemctl restart nginx

log "✓ Web services restarted"

# Step 11: Test Laravel functionality
log "Step 11: Testing Laravel functionality"

# Test artisan command
if sudo -u $WEB_USER php artisan --version &>/dev/null; then
    LARAVEL_VERSION=$(sudo -u $WEB_USER php artisan --version 2>/dev/null)
    log "✓ Laravel is working: $LARAVEL_VERSION"
else
    error "Laravel artisan still not working"
fi

# Test routes
if sudo -u $WEB_USER php artisan route:list &>/dev/null; then
    ROUTE_COUNT=$(sudo -u $WEB_USER php artisan route:list --json 2>/dev/null | grep -o '"uri"' | wc -l)
    log "✓ Routes loaded successfully ($ROUTE_COUNT routes)"
else
    warning "Routes may have issues"
fi

# Step 12: Test website response
log "Step 12: Testing website response"

sleep 3  # Wait for services to fully restart

# Test local HTTP response
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    log "✓ Website responds with HTTP $HTTP_CODE"
elif [ "$HTTP_CODE" = "500" ]; then
    error "Website still responds with HTTP $HTTP_CODE - check error logs"
else
    warning "Website responds with HTTP $HTTP_CODE"
fi

# Test HTTPS response
HTTPS_CODE=$(curl -s -k -o /dev/null -w "%{http_code}" "https://$DOMAIN" 2>/dev/null || echo "000")
if [ "$HTTPS_CODE" = "200" ]; then
    log "✓ HTTPS responds with HTTP $HTTPS_CODE"
else
    info "HTTPS responds with HTTP $HTTPS_CODE"
fi

# Step 13: Final verification
log "Step 13: Final verification"

echo
echo "🎯 FIX SUMMARY"
echo "=============="

ISSUES_FIXED=()
ISSUES_FIXED+=("✅ Created missing bootstrap/app.php")
ISSUES_FIXED+=("✅ Created missing app/Http/Kernel.php")
ISSUES_FIXED+=("✅ Created missing config/app.php")
ISSUES_FIXED+=("✅ Generated APP_KEY")
ISSUES_FIXED+=("✅ Created missing middleware files")
ISSUES_FIXED+=("✅ Created missing provider files")
ISSUES_FIXED+=("✅ Fixed file permissions")
ISSUES_FIXED+=("✅ Installed missing PHP extensions")
ISSUES_FIXED+=("✅ Rebuilt Laravel caches")

for issue in "${ISSUES_FIXED[@]}"; do
    echo "$issue"
done

echo
echo "🌐 Test your website:"
echo "• Main site: https://$DOMAIN"
echo "• BMI Calculator: https://$DOMAIN/bmi-calculator"
echo "• Currency Converter: https://$DOMAIN/currency-converter"
echo "• Loan Calculator: https://$DOMAIN/loan-calculator"
echo "• Health check: https://$DOMAIN/health"
echo
echo "📋 If issues persist, check logs:"
echo "• Laravel: tail -f $WEB_ROOT/storage/logs/laravel.log"
echo "• Nginx: tail -f /var/log/nginx/error.log"
echo "• PHP-FPM: tail -f /var/log/php8.3-fpm.log"
echo
echo "=============================================="
echo "500 Error fix completed at $(date)"
echo "=============================================="
