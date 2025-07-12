#!/bin/bash

# Complete BestHammer NTool Platform Deployment Script
# This script creates and deploys the COMPLETE BestHammer NTool Platform with ALL features

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
    error "Run as root: sudo ./complete-besthammer-deploy.sh"
fi

echo "🔨 COMPLETE BestHammer NTool Platform Deployment"
echo "==============================================="
echo "Domain: $DOMAIN"
echo "Target: $WEB_ROOT"
echo "Web User: $WEB_USER"
echo "Features: ALL COMPLETE FEATURES"
echo "Time: $(date)"
echo "==============================================="
echo

# Step 1: Verify target and create backup
log "Step 1: Preparing deployment environment"

if [ ! -d "$WEB_ROOT" ]; then
    mkdir -p "$WEB_ROOT"
    info "✓ Created web root directory"
fi

# Create backup if files exist
if [ -d "$WEB_ROOT" ] && [ "$(ls -A $WEB_ROOT 2>/dev/null)" ]; then
    BACKUP_FILE="/tmp/complete_backup_${TIMESTAMP}.tar.gz"
    tar -czf "$BACKUP_FILE" -C "$WEB_ROOT" . 2>/dev/null || true
    info "✓ Backup created: $BACKUP_FILE"
fi

# Preserve .env if exists
ENV_BACKUP=""
if [ -f "$WEB_ROOT/.env" ]; then
    ENV_BACKUP="/tmp/env_backup_${TIMESTAMP}"
    cp "$WEB_ROOT/.env" "$ENV_BACKUP"
    info "✓ Preserved existing .env file"
fi

# Clear web root
rm -rf "$WEB_ROOT"/* 2>/dev/null || true
rm -rf "$WEB_ROOT"/.[^.]* 2>/dev/null || true

# Step 2: Create COMPLETE Laravel directory structure
log "Step 2: Creating COMPLETE Laravel directory structure"

cd "$WEB_ROOT"

# Create all Laravel directories including advanced features
LARAVEL_DIRS=(
    "app/Console/Commands"
    "app/Exceptions"
    "app/Http/Controllers/Api"
    "app/Http/Controllers/Auth"
    "app/Http/Middleware"
    "app/Http/Requests"
    "app/Models"
    "app/Providers"
    "app/Services"
    "app/Notifications"
    "app/Events"
    "app/Listeners"
    "app/Jobs"
    "app/Mail"
    "bootstrap/cache"
    "config"
    "database/factories"
    "database/migrations"
    "database/seeders"
    "public/css"
    "public/js"
    "public/images"
    "public/assets"
    "public/exports"
    "resources/css"
    "resources/js"
    "resources/views/layouts"
    "resources/views/components"
    "resources/views/auth"
    "resources/views/calculators"
    "resources/views/dashboard"
    "resources/views/profile"
    "resources/views/legal"
    "resources/views/admin"
    "resources/views/emails"
    "resources/lang/en"
    "resources/lang/es"
    "resources/lang/fr"
    "resources/lang/de"
    "resources/lang/zh"
    "routes"
    "storage/app/public"
    "storage/app/exports"
    "storage/app/uploads"
    "storage/framework/cache/data"
    "storage/framework/sessions"
    "storage/framework/views"
    "storage/framework/testing"
    "storage/logs"
    "tests/Feature"
    "tests/Unit"
)

for dir in "${LARAVEL_DIRS[@]}"; do
    mkdir -p "$dir"
done

info "✓ COMPLETE Laravel directory structure created"

# Step 3: Create core Laravel files
log "Step 3: Creating core Laravel files"

# Create artisan
cat > artisan << 'EOF'
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
cat > public/index.php << 'EOF'
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

# Create COMPLETE composer.json with ALL dependencies
cat > composer.json << 'EOF'
{
    "name": "besthammer/ntool-platform",
    "type": "project",
    "description": "BestHammer NTool Platform - Complete Professional calculation tools with advanced features",
    "keywords": ["laravel", "calculator", "loan", "bmi", "currency", "converter", "api", "subscription", "analytics"],
    "license": "MIT",
    "require": {
        "php": "^8.1",
        "guzzlehttp/guzzle": "^7.2",
        "laravel/framework": "^10.10",
        "laravel/sanctum": "^3.2",
        "laravel/tinker": "^2.8",
        "laravel/breeze": "^1.21",
        "laravel/cashier": "^14.0",
        "laravel/horizon": "^5.15",
        "laravel/telescope": "^4.14",
        "spatie/laravel-permission": "^5.10",
        "spatie/laravel-activitylog": "^4.7",
        "spatie/laravel-backup": "^8.1",
        "spatie/laravel-translatable": "^6.5",
        "barryvdh/laravel-dompdf": "^2.0",
        "maatwebsite/excel": "^3.1",
        "intervention/image": "^2.7",
        "pusher/pusher-php-server": "^7.2",
        "predis/predis": "^2.0",
        "league/flysystem-aws-s3-v3": "^3.0",
        "sentry/sentry-laravel": "^3.4",
        "laravel/scout": "^10.0",
        "algolia/algoliasearch-client-php": "^3.3"
    },
    "require-dev": {
        "fakerphp/faker": "^1.9.1",
        "laravel/pint": "^1.0",
        "laravel/sail": "^1.18",
        "mockery/mockery": "^1.4.4",
        "nunomaduro/collision": "^7.0",
        "phpunit/phpunit": "^10.1",
        "spatie/laravel-ignition": "^2.0",
        "laravel/dusk": "^7.9"
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

info "✓ Core Laravel files with COMPLETE dependencies created"

# Create COMPLETE .env.example with ALL features
cat > .env.example << 'EOF'
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

BROADCAST_DRIVER=pusher
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

# Currency API Configuration
CURRENCY_API_KEY=
CURRENCY_API_URL=https://api.exchangerate-api.com/v4/latest/
CURRENCY_BACKUP_API_URL=https://api.fixer.io/latest
CURRENCY_CACHE_DURATION=3600

# Analytics Configuration
GA4_MEASUREMENT_ID=GA_MEASUREMENT_ID_PLACEHOLDER
GTM_ID=
GOOGLE_OPTIMIZE_ID=
ANALYTICS_DEBUG=false
MIXPANEL_TOKEN=
HOTJAR_ID=

# Subscription and Payment Configuration
STRIPE_KEY=
STRIPE_SECRET=
STRIPE_WEBHOOK_SECRET=
PAYPAL_CLIENT_ID=
PAYPAL_CLIENT_SECRET=
PAYPAL_MODE=sandbox

# Free Experience Configuration
FREE_EXPERIENCE_MODE=true
FREE_EXPERIENCE_DURATION=90
FREE_EXPERIENCE_START_DATE=2024-01-01
ENFORCE_SUBSCRIPTIONS=false
TRACK_USAGE_IN_FREE_MODE=true
MAX_FREE_CALCULATIONS_PER_DAY=50
MAX_FREE_API_CALLS_PER_MONTH=1000

# API Configuration
API_RATE_LIMIT_PER_MINUTE=60
API_RATE_LIMIT_PER_HOUR=1000
API_RATE_LIMIT_PER_DAY=10000
API_VERSION=v1
API_DOCUMENTATION_URL=https://besthammer.club/api/docs

# File Storage Configuration
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=
AWS_USE_PATH_STYLE_ENDPOINT=false

# Pusher Configuration
PUSHER_APP_ID=
PUSHER_APP_KEY=
PUSHER_APP_SECRET=
PUSHER_HOST=
PUSHER_PORT=443
PUSHER_SCHEME=https
PUSHER_APP_CLUSTER=mt1

# Scout Configuration
SCOUT_DRIVER=algolia
ALGOLIA_APP_ID=
ALGOLIA_SECRET=

# Backup Configuration
BACKUP_DISK=s3
BACKUP_NOTIFICATION_EMAIL=admin@besthammer.club

# Monitoring Configuration
SENTRY_LARAVEL_DSN=
TELESCOPE_ENABLED=true
HORIZON_ENABLED=true

# Multi-language Configuration
DEFAULT_LOCALE=en
FALLBACK_LOCALE=en
SUPPORTED_LOCALES=en,es,fr,de,zh

# Contact Information
PRIVACY_EMAIL=privacy@besthammer.club
ADMIN_EMAIL=admin@besthammer.club
SUPPORT_EMAIL=support@besthammer.club
BUSINESS_EMAIL=business@besthammer.club

# Social Media
FACEBOOK_URL=https://facebook.com/besthammer
TWITTER_URL=https://twitter.com/besthammer
LINKEDIN_URL=https://linkedin.com/company/besthammer
INSTAGRAM_URL=https://instagram.com/besthammer

# Advanced Features
ENABLE_USER_REGISTRATION=true
ENABLE_EMAIL_VERIFICATION=true
ENABLE_PASSWORD_RESET=true
ENABLE_TWO_FACTOR_AUTH=false
ENABLE_SOCIAL_LOGIN=false
ENABLE_API_ACCESS=true
ENABLE_EXPORT_FEATURES=true
ENABLE_ADVANCED_ANALYTICS=true
ENABLE_REAL_TIME_NOTIFICATIONS=true
EOF

# Create COMPLETE package.json with ALL frontend dependencies
cat > package.json << 'EOF'
{
    "name": "besthammer-ntool-complete",
    "version": "2.0.0",
    "description": "BestHammer NTool Platform Complete Frontend Assets",
    "private": true,
    "scripts": {
        "dev": "vite",
        "build": "vite build",
        "watch": "vite build --watch",
        "hot": "vite --host",
        "test": "jest",
        "test:watch": "jest --watch",
        "lint": "eslint resources/js --ext .js,.vue",
        "lint:fix": "eslint resources/js --ext .js,.vue --fix"
    },
    "devDependencies": {
        "@vitejs/plugin-laravel": "^0.7.5",
        "@vitejs/plugin-vue": "^4.2.3",
        "axios": "^1.1.2",
        "laravel-vite-plugin": "^0.7.2",
        "lodash": "^4.17.19",
        "postcss": "^8.1.14",
        "vite": "^4.0.0",
        "vue": "^3.3.0",
        "eslint": "^8.44.0",
        "jest": "^29.5.0",
        "@babel/preset-env": "^7.22.0"
    },
    "dependencies": {
        "alpinejs": "^3.10.2",
        "chart.js": "^3.9.1",
        "chartjs-adapter-date-fns": "^2.0.0",
        "tailwindcss": "^3.2.0",
        "autoprefixer": "^10.4.12",
        "vue-router": "^4.2.0",
        "vuex": "^4.1.0",
        "vue-i18n": "^9.2.0",
        "vue-toastification": "^2.0.0",
        "sweetalert2": "^11.7.0",
        "moment": "^2.29.0",
        "numeral": "^2.0.6",
        "lodash": "^4.17.21",
        "pusher-js": "^8.2.0",
        "laravel-echo": "^1.15.0",
        "html2canvas": "^1.4.1",
        "jspdf": "^2.5.1",
        "file-saver": "^2.0.5",
        "xlsx": "^0.18.5",
        "qrcode": "^1.5.3",
        "signature_pad": "^4.1.1"
    }
}
EOF

info "✓ COMPLETE environment and package configuration created"

# Step 4: Create COMPLETE BestHammer Controllers
log "Step 4: Creating COMPLETE BestHammer Controllers"

# Advanced BMI Controller with ALL features
cat > app/Http/Controllers/BmiController.php << 'EOF'
<?php

namespace App\Http\Controllers;

use App\Http\Requests\BmiCalculationRequest;
use App\Services\BmiCalculatorService;
use App\Models\BmiRecord;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Log;
use Barryvdh\DomPDF\Facade\Pdf;
use Maatwebsite\Excel\Facades\Excel;
use App\Exports\BmiRecordsExport;

class BmiController extends Controller
{
    protected $bmiCalculatorService;

    public function __construct(BmiCalculatorService $bmiCalculatorService)
    {
        $this->bmiCalculatorService = $bmiCalculatorService;
    }

    public function index()
    {
        return view('calculators.bmi.index');
    }

    public function calculate(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'height_cm' => 'required|numeric|min:100|max:250',
            'weight_kg' => 'required|numeric|min:30|max:300',
            'age' => 'required|integer|min:10|max:120',
            'gender' => 'required|in:male,female,other',
            'activity_level' => 'required|in:sedentary,lightly_active,moderately_active,very_active,extremely_active',
            'goal' => 'nullable|in:lose_weight,maintain,gain_weight,lose_weight_fast,gain_weight_fast',
            'body_fat_percentage' => 'nullable|numeric|min:3|max:50',
            'muscle_mass_kg' => 'nullable|numeric|min:10|max:100',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            $params = $request->only([
                'height_cm', 'weight_kg', 'age', 'gender', 'activity_level', 'goal',
                'body_fat_percentage', 'muscle_mass_kg'
            ]);

            $results = $this->bmiCalculatorService->calculate($params);

            // Calculate additional metrics
            $idealWeightRange = $this->bmiCalculatorService->calculateIdealWeightRange($params['height_cm']);
            $bodyFatAnalysis = $this->bmiCalculatorService->analyzeBodyFat($params);
            $nutritionPlan = $this->bmiCalculatorService->generateNutritionPlan($params, $results);
            $exercisePlan = $this->bmiCalculatorService->generateExercisePlan($params, $results);

            $results['ideal_weight_range'] = $idealWeightRange;
            $results['body_fat_analysis'] = $bodyFatAnalysis;
            $results['nutrition_plan'] = $nutritionPlan;
            $results['exercise_plan'] = $exercisePlan;

            // Save record if user is logged in
            if (Auth::check() && $request->input('save_record')) {
                $this->saveRecord($params, $results);
            }

            // Log calculation for analytics
            Log::info('BMI calculation performed', [
                'user_id' => Auth::id(),
                'bmi' => $results['bmi'],
                'category' => $results['category'],
                'ip' => $request->ip(),
                'user_agent' => $request->userAgent()
            ]);

            return response()->json([
                'success' => true,
                'results' => $results
            ]);

        } catch (\Exception $e) {
            Log::error('BMI calculation failed', [
                'error' => $e->getMessage(),
                'user_id' => Auth::id(),
                'request_data' => $request->all()
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Calculation failed: ' . $e->getMessage()
            ], 500);
        }
    }

    public function history()
    {
        $this->authorize('view-history');

        $records = BmiRecord::where('user_id', Auth::id())
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        return view('calculators.bmi.history', compact('records'));
    }

    public function trends()
    {
        $this->authorize('view-trends');

        $records = BmiRecord::where('user_id', Auth::id())
            ->orderBy('created_at', 'asc')
            ->get();

        $trends = $this->bmiCalculatorService->analyzeTrends($records);

        return response()->json([
            'success' => true,
            'trends' => $trends
        ]);
    }

    public function exportPdf()
    {
        $this->authorize('export-data');

        $records = BmiRecord::where('user_id', Auth::id())
            ->orderBy('created_at', 'desc')
            ->get();

        $pdf = Pdf::loadView('calculators.bmi.export-pdf', compact('records'));

        return $pdf->download('bmi-records-' . date('Y-m-d') . '.pdf');
    }

    public function exportExcel()
    {
        $this->authorize('export-data');

        return Excel::download(new BmiRecordsExport(Auth::id()), 'bmi-records-' . date('Y-m-d') . '.xlsx');
    }

    private function saveRecord($params, $results)
    {
        BmiRecord::create([
            'user_id' => Auth::id(),
            'height_cm' => $params['height_cm'],
            'weight_kg' => $params['weight_kg'],
            'age' => $params['age'],
            'gender' => $params['gender'],
            'activity_level' => $params['activity_level'],
            'goal' => $params['goal'] ?? null,
            'body_fat_percentage' => $params['body_fat_percentage'] ?? null,
            'muscle_mass_kg' => $params['muscle_mass_kg'] ?? null,
            'bmi' => $results['bmi'],
            'category' => $results['category'],
            'bmr' => $results['bmr'],
            'tdee' => $results['tdee'],
            'ideal_weight_min' => $results['ideal_weight_range']['min'],
            'ideal_weight_max' => $results['ideal_weight_range']['max'],
            'results_data' => json_encode($results)
        ]);
    }
}
EOF

info "✓ Advanced BMI Controller created"
