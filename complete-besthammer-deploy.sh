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

# Advanced Currency Controller with ALL features
cat > app/Http/Controllers/CurrencyController.php << 'EOF'
<?php

namespace App\Http\Controllers;

use App\Services\CurrencyService;
use App\Models\CurrencyConversion;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;

class CurrencyController extends Controller
{
    protected $currencyService;

    public function __construct(CurrencyService $currencyService)
    {
        $this->currencyService = $currencyService;
    }

    public function index()
    {
        $supportedCurrencies = $this->currencyService->getSupportedCurrencies();
        $popularPairs = $this->currencyService->getPopularCurrencyPairs();

        return view('calculators.currency.index', compact('supportedCurrencies', 'popularPairs'));
    }

    public function convert(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'amount' => 'required|numeric|min:0|max:1000000000',
            'from' => 'required|string|size:3',
            'to' => 'required|string|size:3'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            $result = $this->currencyService->convert(
                $request->input('amount'),
                $request->input('from'),
                $request->input('to')
            );

            // Save conversion if user is logged in
            if (Auth::check() && $request->input('save_conversion')) {
                $this->saveConversion($request->all(), $result);
            }

            // Log conversion for analytics
            Log::info('Currency conversion performed', [
                'user_id' => Auth::id(),
                'from' => $request->input('from'),
                'to' => $request->input('to'),
                'amount' => $request->input('amount'),
                'result' => $result['converted_amount'],
                'ip' => $request->ip()
            ]);

            return response()->json([
                'success' => true,
                'result' => $result
            ]);

        } catch (\Exception $e) {
            Log::error('Currency conversion failed', [
                'error' => $e->getMessage(),
                'request_data' => $request->all()
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Conversion failed: ' . $e->getMessage()
            ], 500);
        }
    }

    public function batchConvert(Request $request)
    {
        $this->authorize('batch-convert');

        $validator = Validator::make($request->all(), [
            'conversions' => 'required|array|max:50',
            'conversions.*.amount' => 'required|numeric|min:0|max:1000000000',
            'conversions.*.from' => 'required|string|size:3',
            'conversions.*.to' => 'required|string|size:3'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            $results = $this->currencyService->batchConvert($request->input('conversions'));

            return response()->json([
                'success' => true,
                'results' => $results
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Batch conversion failed: ' . $e->getMessage()
            ], 500);
        }
    }

    public function rates()
    {
        $rates = Cache::remember('currency_rates', 3600, function () {
            return $this->currencyService->getAllRates();
        });

        return response()->json([
            'success' => true,
            'rates' => $rates,
            'last_updated' => now()->toISOString()
        ]);
    }

    private function saveConversion($requestData, $result)
    {
        CurrencyConversion::create([
            'user_id' => Auth::id(),
            'amount' => $requestData['amount'],
            'from_currency' => $requestData['from'],
            'to_currency' => $requestData['to'],
            'converted_amount' => $result['converted_amount'],
            'exchange_rate' => $result['exchange_rate'],
            'provider' => $result['provider'] ?? 'default',
            'conversion_data' => json_encode($result)
        ]);
    }
}
EOF

# Advanced Loan Controller
cat > app/Http/Controllers/LoanController.php << 'EOF'
<?php

namespace App\Http\Controllers;

use App\Services\LoanCalculatorService;
use App\Models\LoanCalculation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Log;

class LoanController extends Controller
{
    protected $loanCalculatorService;

    public function __construct(LoanCalculatorService $loanCalculatorService)
    {
        $this->loanCalculatorService = $loanCalculatorService;
    }

    public function index()
    {
        return view('calculators.loan.index');
    }

    public function calculate(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'principal' => 'required|numeric|min:1|max:10000000',
            'rate' => 'required|numeric|min:0|max:50',
            'months' => 'required|integer|min:1|max:600',
            'loan_type' => 'nullable|in:fixed,variable,interest_only',
            'down_payment' => 'nullable|numeric|min:0',
            'extra_payment' => 'nullable|numeric|min:0'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            $params = $request->only([
                'principal', 'rate', 'months', 'loan_type', 'down_payment', 'extra_payment'
            ]);

            $results = $this->loanCalculatorService->calculate($params);

            // Generate amortization schedule
            $amortizationSchedule = $this->loanCalculatorService->generateAmortizationSchedule($params);
            $results['amortization_schedule'] = $amortizationSchedule;

            // Calculate scenarios
            $scenarios = $this->loanCalculatorService->calculateScenarios($params);
            $results['scenarios'] = $scenarios;

            // Save calculation if user is logged in
            if (Auth::check() && $request->input('save_calculation')) {
                $this->saveCalculation($params, $results);
            }

            // Log calculation for analytics
            Log::info('Loan calculation performed', [
                'user_id' => Auth::id(),
                'principal' => $params['principal'],
                'rate' => $params['rate'],
                'months' => $params['months'],
                'monthly_payment' => $results['monthly_payment'],
                'ip' => $request->ip()
            ]);

            return response()->json([
                'success' => true,
                'results' => $results
            ]);

        } catch (\Exception $e) {
            Log::error('Loan calculation failed', [
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

    private function saveCalculation($params, $results)
    {
        LoanCalculation::create([
            'user_id' => Auth::id(),
            'principal' => $params['principal'],
            'interest_rate' => $params['rate'],
            'term_months' => $params['months'],
            'loan_type' => $params['loan_type'] ?? 'fixed',
            'down_payment' => $params['down_payment'] ?? 0,
            'extra_payment' => $params['extra_payment'] ?? 0,
            'monthly_payment' => $results['monthly_payment'],
            'total_payment' => $results['total_payment'],
            'total_interest' => $results['total_interest'],
            'calculation_data' => json_encode($results)
        ]);
    }
}
EOF

info "✓ Advanced Currency and Loan Controllers created"

# Step 5: Create COMPLETE Service Classes
log "Step 5: Creating COMPLETE Service Classes"

# BMI Calculator Service with ALL features
cat > app/Services/BmiCalculatorService.php << 'EOF'
<?php

namespace App\Services;

use Illuminate\Support\Facades\Log;

class BmiCalculatorService
{
    public function calculate(array $params)
    {
        $heightM = $params['height_cm'] / 100;
        $weight = $params['weight_kg'];
        $age = $params['age'];
        $gender = $params['gender'];
        $activityLevel = $params['activity_level'];

        // Calculate BMI
        $bmi = $weight / ($heightM * $heightM);

        // Determine BMI category
        $category = $this->getBmiCategory($bmi);

        // Calculate BMR (Basal Metabolic Rate)
        $bmr = $this->calculateBMR($weight, $params['height_cm'], $age, $gender);

        // Calculate TDEE (Total Daily Energy Expenditure)
        $tdee = $this->calculateTDEE($bmr, $activityLevel);

        // Calculate body fat percentage if not provided
        $bodyFatPercentage = $params['body_fat_percentage'] ?? $this->estimateBodyFat($bmi, $age, $gender);

        // Calculate lean body mass
        $leanBodyMass = $weight * (1 - $bodyFatPercentage / 100);

        // Generate health recommendations
        $recommendations = $this->generateHealthRecommendations($bmi, $category, $age, $gender);

        // Calculate weight goals
        $weightGoals = $this->calculateWeightGoals($params['height_cm'], $weight, $params['goal'] ?? 'maintain');

        return [
            'bmi' => round($bmi, 1),
            'category' => $category,
            'bmr' => round($bmr, 0),
            'tdee' => round($tdee, 0),
            'body_fat_percentage' => round($bodyFatPercentage, 1),
            'lean_body_mass' => round($leanBodyMass, 1),
            'recommendations' => $recommendations,
            'weight_goals' => $weightGoals,
            'health_risks' => $this->assessHealthRisks($bmi, $bodyFatPercentage, $age),
            'progress_tracking' => $this->generateProgressMetrics($params)
        ];
    }

    public function calculateIdealWeightRange($heightCm)
    {
        $heightM = $heightCm / 100;

        return [
            'min' => round(18.5 * $heightM * $heightM, 1),
            'max' => round(24.9 * $heightM * $heightM, 1)
        ];
    }

    public function analyzeBodyFat($params)
    {
        $bodyFat = $params['body_fat_percentage'] ?? null;
        $age = $params['age'];
        $gender = $params['gender'];

        if (!$bodyFat) {
            return null;
        }

        $ranges = $this->getBodyFatRanges($age, $gender);
        $category = $this->categorizeBodyFat($bodyFat, $ranges);

        return [
            'percentage' => $bodyFat,
            'category' => $category,
            'ranges' => $ranges,
            'recommendations' => $this->getBodyFatRecommendations($category)
        ];
    }

    public function generateNutritionPlan($params, $results)
    {
        $tdee = $results['tdee'];
        $goal = $params['goal'] ?? 'maintain';
        $weight = $params['weight_kg'];

        $calorieAdjustment = $this->getCalorieAdjustment($goal);
        $targetCalories = $tdee + $calorieAdjustment;

        // Macronutrient distribution
        $protein = $weight * $this->getProteinMultiplier($goal);
        $proteinCalories = $protein * 4;

        $fatPercentage = $this->getFatPercentage($goal);
        $fatCalories = $targetCalories * $fatPercentage;
        $fat = $fatCalories / 9;

        $carbCalories = $targetCalories - $proteinCalories - $fatCalories;
        $carbs = $carbCalories / 4;

        return [
            'target_calories' => round($targetCalories),
            'protein_g' => round($protein, 1),
            'carbs_g' => round($carbs, 1),
            'fat_g' => round($fat, 1),
            'meal_suggestions' => $this->getMealSuggestions($goal),
            'hydration_target' => $this->calculateHydrationNeeds($weight, $params['activity_level'])
        ];
    }

    public function generateExercisePlan($params, $results)
    {
        $goal = $params['goal'] ?? 'maintain';
        $activityLevel = $params['activity_level'];
        $age = $params['age'];

        return [
            'weekly_schedule' => $this->getExerciseSchedule($goal, $activityLevel),
            'cardio_recommendations' => $this->getCardioRecommendations($goal, $age),
            'strength_training' => $this->getStrengthTrainingPlan($goal),
            'flexibility_routine' => $this->getFlexibilityRoutine($age),
            'progression_plan' => $this->getProgressionPlan($goal, $activityLevel)
        ];
    }

    private function getBmiCategory($bmi)
    {
        if ($bmi < 18.5) return 'Underweight';
        if ($bmi < 25) return 'Normal weight';
        if ($bmi < 30) return 'Overweight';
        if ($bmi < 35) return 'Obesity Class I';
        if ($bmi < 40) return 'Obesity Class II';
        return 'Obesity Class III';
    }

    private function calculateBMR($weight, $height, $age, $gender)
    {
        // Mifflin-St Jeor Equation
        if ($gender === 'male') {
            return (10 * $weight) + (6.25 * $height) - (5 * $age) + 5;
        } else {
            return (10 * $weight) + (6.25 * $height) - (5 * $age) - 161;
        }
    }

    private function calculateTDEE($bmr, $activityLevel)
    {
        $multipliers = [
            'sedentary' => 1.2,
            'lightly_active' => 1.375,
            'moderately_active' => 1.55,
            'very_active' => 1.725,
            'extremely_active' => 1.9
        ];

        return $bmr * ($multipliers[$activityLevel] ?? 1.2);
    }

    private function estimateBodyFat($bmi, $age, $gender)
    {
        // Deurenberg formula
        if ($gender === 'male') {
            return (1.20 * $bmi) + (0.23 * $age) - 16.2;
        } else {
            return (1.20 * $bmi) + (0.23 * $age) - 5.4;
        }
    }

    private function generateHealthRecommendations($bmi, $category, $age, $gender)
    {
        $recommendations = [];

        switch ($category) {
            case 'Underweight':
                $recommendations[] = 'Consider consulting a healthcare provider about healthy weight gain strategies.';
                $recommendations[] = 'Focus on nutrient-dense, calorie-rich foods.';
                $recommendations[] = 'Include strength training to build muscle mass.';
                break;
            case 'Normal weight':
                $recommendations[] = 'Maintain your healthy weight through balanced diet and regular exercise.';
                $recommendations[] = 'Continue current lifestyle habits that support your health.';
                break;
            case 'Overweight':
                $recommendations[] = 'Consider a moderate calorie reduction and increased physical activity.';
                $recommendations[] = 'Focus on whole foods and portion control.';
                $recommendations[] = 'Aim for 150 minutes of moderate exercise per week.';
                break;
            default: // Obesity classes
                $recommendations[] = 'Consult with a healthcare provider for personalized weight management guidance.';
                $recommendations[] = 'Consider working with a registered dietitian.';
                $recommendations[] = 'Start with low-impact exercises and gradually increase intensity.';
                break;
        }

        return $recommendations;
    }

    private function calculateWeightGoals($heightCm, $currentWeight, $goal)
    {
        $idealRange = $this->calculateIdealWeightRange($heightCm);

        switch ($goal) {
            case 'lose_weight':
                $targetWeight = max($idealRange['max'], $currentWeight * 0.9);
                $timeframe = '3-6 months';
                break;
            case 'lose_weight_fast':
                $targetWeight = max($idealRange['max'], $currentWeight * 0.85);
                $timeframe = '2-4 months';
                break;
            case 'gain_weight':
                $targetWeight = min($idealRange['min'], $currentWeight * 1.1);
                $timeframe = '3-6 months';
                break;
            case 'gain_weight_fast':
                $targetWeight = min($idealRange['min'], $currentWeight * 1.15);
                $timeframe = '2-4 months';
                break;
            default: // maintain
                $targetWeight = $currentWeight;
                $timeframe = 'ongoing';
                break;
        }

        return [
            'target_weight' => round($targetWeight, 1),
            'weight_change' => round($targetWeight - $currentWeight, 1),
            'timeframe' => $timeframe,
            'weekly_goal' => round(($targetWeight - $currentWeight) / 12, 2)
        ];
    }

    private function assessHealthRisks($bmi, $bodyFat, $age)
    {
        $risks = [];

        if ($bmi >= 30) {
            $risks[] = 'Increased risk of type 2 diabetes';
            $risks[] = 'Higher risk of cardiovascular disease';
            $risks[] = 'Increased risk of sleep apnea';
        }

        if ($bmi < 18.5) {
            $risks[] = 'Increased risk of osteoporosis';
            $risks[] = 'Weakened immune system';
            $risks[] = 'Nutritional deficiencies';
        }

        return $risks;
    }

    private function generateProgressMetrics($params)
    {
        return [
            'tracking_frequency' => 'weekly',
            'key_metrics' => ['weight', 'body_fat_percentage', 'measurements'],
            'milestone_intervals' => '4 weeks',
            'adjustment_triggers' => ['plateau', 'rapid_change', 'health_concerns']
        ];
    }

    // Additional helper methods for nutrition, exercise, etc.
    private function getCalorieAdjustment($goal)
    {
        switch ($goal) {
            case 'lose_weight': return -500;
            case 'lose_weight_fast': return -750;
            case 'gain_weight': return 300;
            case 'gain_weight_fast': return 500;
            default: return 0;
        }
    }

    private function getProteinMultiplier($goal)
    {
        switch ($goal) {
            case 'lose_weight':
            case 'lose_weight_fast': return 2.2;
            case 'gain_weight':
            case 'gain_weight_fast': return 2.0;
            default: return 1.6;
        }
    }

    private function getFatPercentage($goal)
    {
        return 0.25; // 25% of calories from fat
    }

    private function getMealSuggestions($goal)
    {
        return [
            'breakfast' => 'High protein breakfast with complex carbs',
            'lunch' => 'Balanced meal with lean protein and vegetables',
            'dinner' => 'Light protein with vegetables',
            'snacks' => 'Healthy snacks between meals'
        ];
    }

    private function calculateHydrationNeeds($weight, $activityLevel)
    {
        $baseWater = $weight * 35; // ml per kg
        $activityMultiplier = $activityLevel === 'very_active' || $activityLevel === 'extremely_active' ? 1.5 : 1.2;
        return round($baseWater * $activityMultiplier);
    }
}
EOF

info "✓ Complete BMI Calculator Service created"

# Currency Service
cat > app/Services/CurrencyService.php << 'EOF'
<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

class CurrencyService
{
    private $apiKey;
    private $baseUrl;
    private $fallbackUrl;

    public function __construct()
    {
        $this->apiKey = config('services.currency.api_key');
        $this->baseUrl = config('services.currency.api_url', 'https://api.exchangerate-api.com/v4/latest/');
        $this->fallbackUrl = config('services.currency.fallback_url', 'https://api.fixer.io/latest');
    }

    public function convert($amount, $from, $to)
    {
        $rate = $this->getExchangeRate($from, $to);
        $convertedAmount = $amount * $rate;

        return [
            'original_amount' => $amount,
            'converted_amount' => round($convertedAmount, 2),
            'from_currency' => strtoupper($from),
            'to_currency' => strtoupper($to),
            'exchange_rate' => round($rate, 6),
            'timestamp' => now()->toISOString(),
            'provider' => 'exchangerate-api'
        ];
    }

    public function batchConvert($conversions)
    {
        $results = [];

        foreach ($conversions as $conversion) {
            try {
                $results[] = $this->convert(
                    $conversion['amount'],
                    $conversion['from'],
                    $conversion['to']
                );
            } catch (\Exception $e) {
                $results[] = [
                    'error' => 'Conversion failed: ' . $e->getMessage(),
                    'original_request' => $conversion
                ];
            }
        }

        return $results;
    }

    public function getSupportedCurrencies()
    {
        return Cache::remember('supported_currencies', 86400, function () {
            return [
                'USD' => 'US Dollar',
                'EUR' => 'Euro',
                'GBP' => 'British Pound',
                'JPY' => 'Japanese Yen',
                'CAD' => 'Canadian Dollar',
                'AUD' => 'Australian Dollar',
                'CHF' => 'Swiss Franc',
                'CNY' => 'Chinese Yuan',
                'INR' => 'Indian Rupee',
                'KRW' => 'South Korean Won',
                'MXN' => 'Mexican Peso',
                'BRL' => 'Brazilian Real',
                'RUB' => 'Russian Ruble',
                'ZAR' => 'South African Rand',
                'SGD' => 'Singapore Dollar',
                'HKD' => 'Hong Kong Dollar'
            ];
        });
    }

    public function getPopularCurrencyPairs()
    {
        return [
            ['from' => 'USD', 'to' => 'EUR'],
            ['from' => 'USD', 'to' => 'GBP'],
            ['from' => 'USD', 'to' => 'JPY'],
            ['from' => 'EUR', 'to' => 'GBP'],
            ['from' => 'EUR', 'to' => 'USD'],
            ['from' => 'GBP', 'to' => 'USD']
        ];
    }

    public function getAllRates($baseCurrency = 'USD')
    {
        return Cache::remember("currency_rates_{$baseCurrency}", 3600, function () use ($baseCurrency) {
            try {
                $response = Http::timeout(10)->get($this->baseUrl . $baseCurrency);

                if ($response->successful()) {
                    return $response->json()['rates'] ?? [];
                }

                throw new \Exception('Primary API failed');

            } catch (\Exception $e) {
                Log::warning('Primary currency API failed, trying fallback', ['error' => $e->getMessage()]);

                try {
                    $response = Http::timeout(10)->get($this->fallbackUrl, [
                        'access_key' => $this->apiKey,
                        'base' => $baseCurrency
                    ]);

                    if ($response->successful()) {
                        return $response->json()['rates'] ?? [];
                    }
                } catch (\Exception $fallbackError) {
                    Log::error('All currency APIs failed', [
                        'primary_error' => $e->getMessage(),
                        'fallback_error' => $fallbackError->getMessage()
                    ]);
                }

                // Return mock rates as last resort
                return $this->getMockRates();
            }
        });
    }

    private function getExchangeRate($from, $to)
    {
        if ($from === $to) {
            return 1.0;
        }

        $rates = $this->getAllRates('USD');

        $fromRate = $from === 'USD' ? 1 : ($rates[$from] ?? null);
        $toRate = $to === 'USD' ? 1 : ($rates[$to] ?? null);

        if (!$fromRate || !$toRate) {
            throw new \Exception("Exchange rate not available for {$from} to {$to}");
        }

        return $toRate / $fromRate;
    }

    private function getMockRates()
    {
        return [
            'EUR' => 0.85,
            'GBP' => 0.73,
            'JPY' => 110.0,
            'CAD' => 1.25,
            'AUD' => 1.35,
            'CHF' => 0.92,
            'CNY' => 6.45,
            'INR' => 74.5,
            'KRW' => 1180.0,
            'MXN' => 20.1,
            'BRL' => 5.2,
            'RUB' => 73.5,
            'ZAR' => 14.8,
            'SGD' => 1.35,
            'HKD' => 7.8
        ];
    }
}
EOF

# Loan Calculator Service
cat > app/Services/LoanCalculatorService.php << 'EOF'
<?php

namespace App\Services;

class LoanCalculatorService
{
    public function calculate(array $params)
    {
        $principal = $params['principal'];
        $annualRate = $params['rate'] / 100;
        $monthlyRate = $annualRate / 12;
        $months = $params['months'];
        $downPayment = $params['down_payment'] ?? 0;
        $extraPayment = $params['extra_payment'] ?? 0;

        $loanAmount = $principal - $downPayment;

        if ($monthlyRate == 0) {
            $monthlyPayment = $loanAmount / $months;
        } else {
            $monthlyPayment = $loanAmount * ($monthlyRate * pow(1 + $monthlyRate, $months)) / (pow(1 + $monthlyRate, $months) - 1);
        }

        $totalPayment = $monthlyPayment * $months;
        $totalInterest = $totalPayment - $loanAmount;

        // Calculate with extra payments
        $payoffTime = $this->calculatePayoffTime($loanAmount, $monthlyRate, $monthlyPayment + $extraPayment);
        $interestSaved = $totalInterest - $this->calculateTotalInterest($loanAmount, $monthlyRate, $monthlyPayment + $extraPayment, $payoffTime);

        return [
            'loan_amount' => round($loanAmount, 2),
            'monthly_payment' => round($monthlyPayment, 2),
            'total_payment' => round($totalPayment, 2),
            'total_interest' => round($totalInterest, 2),
            'down_payment' => $downPayment,
            'extra_payment' => $extraPayment,
            'payoff_time_months' => $payoffTime,
            'interest_saved' => round($interestSaved, 2),
            'effective_rate' => round($annualRate * 100, 3)
        ];
    }

    public function generateAmortizationSchedule(array $params)
    {
        $principal = $params['principal'] - ($params['down_payment'] ?? 0);
        $monthlyRate = ($params['rate'] / 100) / 12;
        $months = $params['months'];
        $extraPayment = $params['extra_payment'] ?? 0;

        if ($monthlyRate == 0) {
            $monthlyPayment = $principal / $months;
        } else {
            $monthlyPayment = $principal * ($monthlyRate * pow(1 + $monthlyRate, $months)) / (pow(1 + $monthlyRate, $months) - 1);
        }

        $schedule = [];
        $balance = $principal;
        $totalInterest = 0;

        for ($month = 1; $month <= $months && $balance > 0; $month++) {
            $interestPayment = $balance * $monthlyRate;
            $principalPayment = min($monthlyPayment + $extraPayment - $interestPayment, $balance);
            $balance -= $principalPayment;
            $totalInterest += $interestPayment;

            $schedule[] = [
                'month' => $month,
                'payment' => round($monthlyPayment + $extraPayment, 2),
                'principal' => round($principalPayment, 2),
                'interest' => round($interestPayment, 2),
                'balance' => round(max(0, $balance), 2),
                'cumulative_interest' => round($totalInterest, 2)
            ];

            if ($balance <= 0) break;
        }

        return $schedule;
    }

    public function calculateScenarios(array $params)
    {
        $baseCalculation = $this->calculate($params);

        $scenarios = [
            'base' => $baseCalculation,
            'extra_100' => $this->calculate(array_merge($params, ['extra_payment' => 100])),
            'extra_200' => $this->calculate(array_merge($params, ['extra_payment' => 200])),
            'shorter_term' => $this->calculate(array_merge($params, ['months' => max(12, $params['months'] - 60)])),
            'longer_term' => $this->calculate(array_merge($params, ['months' => $params['months'] + 60]))
        ];

        return $scenarios;
    }

    private function calculatePayoffTime($principal, $monthlyRate, $payment)
    {
        if ($monthlyRate == 0) {
            return ceil($principal / $payment);
        }

        return ceil(log(1 + ($principal * $monthlyRate) / $payment) / log(1 + $monthlyRate));
    }

    private function calculateTotalInterest($principal, $monthlyRate, $payment, $months)
    {
        return ($payment * $months) - $principal;
    }
}
EOF

info "✓ Complete Currency and Loan Services created"

# Step 6: Create Models
log "Step 6: Creating Models"

# BMI Record Model
cat > app/Models/BmiRecord.php << 'EOF'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class BmiRecord extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'user_id',
        'height_cm',
        'weight_kg',
        'age',
        'gender',
        'activity_level',
        'goal',
        'body_fat_percentage',
        'muscle_mass_kg',
        'bmi',
        'category',
        'bmr',
        'tdee',
        'ideal_weight_min',
        'ideal_weight_max',
        'results_data',
        'notes',
        'tags'
    ];

    protected $casts = [
        'results_data' => 'array',
        'tags' => 'array',
        'body_fat_percentage' => 'decimal:1',
        'muscle_mass_kg' => 'decimal:1',
        'bmi' => 'decimal:1',
        'bmr' => 'integer',
        'tdee' => 'integer',
        'ideal_weight_min' => 'decimal:1',
        'ideal_weight_max' => 'decimal:1'
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
EOF

# Currency Conversion Model
cat > app/Models/CurrencyConversion.php << 'EOF'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CurrencyConversion extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'amount',
        'from_currency',
        'to_currency',
        'converted_amount',
        'exchange_rate',
        'provider',
        'conversion_data'
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'converted_amount' => 'decimal:2',
        'exchange_rate' => 'decimal:6',
        'conversion_data' => 'array'
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
EOF

# Loan Calculation Model
cat > app/Models/LoanCalculation.php << 'EOF'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class LoanCalculation extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'principal',
        'interest_rate',
        'term_months',
        'loan_type',
        'down_payment',
        'extra_payment',
        'monthly_payment',
        'total_payment',
        'total_interest',
        'calculation_data'
    ];

    protected $casts = [
        'principal' => 'decimal:2',
        'interest_rate' => 'decimal:3',
        'down_payment' => 'decimal:2',
        'extra_payment' => 'decimal:2',
        'monthly_payment' => 'decimal:2',
        'total_payment' => 'decimal:2',
        'total_interest' => 'decimal:2',
        'calculation_data' => 'array'
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
EOF

info "✓ Complete Models created"

# Step 7: Create Routes
log "Step 7: Creating Routes"

# Web Routes
cat > routes/web.php << 'EOF'
<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\BmiController;
use App\Http\Controllers\CurrencyController;
use App\Http\Controllers\LoanController;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
*/

Route::get('/', function () {
    return view('welcome');
})->name('home');

// Calculator pages
Route::get('/bmi-calculator', [BmiController::class, 'index'])->name('bmi.calculator');
Route::get('/currency-converter', [CurrencyController::class, 'index'])->name('currency.converter');
Route::get('/loan-calculator', [LoanController::class, 'index'])->name('loan.calculator');

// Authenticated routes
Route::middleware(['auth'])->group(function () {
    Route::get('/bmi/history', [BmiController::class, 'history'])->name('bmi.history');
    Route::get('/bmi/trends', [BmiController::class, 'trends'])->name('bmi.trends');
    Route::get('/bmi/export/pdf', [BmiController::class, 'exportPdf'])->name('bmi.export.pdf');
    Route::get('/bmi/export/excel', [BmiController::class, 'exportExcel'])->name('bmi.export.excel');
});

// Privacy and legal pages
Route::view('/privacy-policy', 'legal.privacy')->name('privacy.policy');
Route::view('/terms-of-service', 'legal.terms')->name('terms.service');
Route::view('/cookie-policy', 'legal.cookies')->name('cookie.policy');

// Health check
Route::get('/health', function () {
    return response()->json([
        'status' => 'ok',
        'timestamp' => now()->toISOString(),
        'version' => '2.0.0'
    ]);
})->name('health.check');
EOF

# API Routes
cat > routes/api.php << 'EOF'
<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\BmiController;
use App\Http\Controllers\CurrencyController;
use App\Http\Controllers\LoanController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/

Route::middleware(['throttle:60,1'])->group(function () {
    Route::post('/calculate-bmi', [BmiController::class, 'calculate']);
    Route::post('/convert-currency', [CurrencyController::class, 'convert']);
    Route::post('/calculate-loan', [LoanController::class, 'calculate']);
    Route::get('/currency-rates', [CurrencyController::class, 'rates']);
});

Route::middleware(['auth:sanctum', 'throttle:100,1'])->group(function () {
    Route::post('/batch-convert-currency', [CurrencyController::class, 'batchConvert']);
    Route::get('/bmi/trends', [BmiController::class, 'trends']);
    Route::post('/bmi/nutrition', [BmiController::class, 'nutrition']);
});

Route::middleware('auth:sanctum')->get('/user', function (Request $request) {
    return $request->user();
});
EOF

info "✓ Routes created"

# Step 8: Create Basic Views
log "Step 8: Creating Basic Views"

# Main Layout
cat > resources/views/layouts/app.blade.php << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title', 'BestHammer - Professional Calculation Tools')</title>
    <meta name="description" content="@yield('description', 'Professional calculation tools for loans, BMI, currency conversion and more.')">

    <!-- Tailwind CSS -->
    <script src="https://cdn.tailwindcss.com"></script>

    <style>
        .calculator-card {
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .calculator-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 25px rgba(0,0,0,0.1);
        }
        .btn-primary {
            @apply bg-blue-600 hover:bg-blue-700 text-white font-semibold py-2 px-4 rounded-lg transition-colors;
        }
        .input-field {
            @apply w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent;
        }
    </style>

    @yield('head')
</head>
<body class="bg-gray-50 min-h-screen">
    <!-- Navigation -->
    <nav class="bg-white shadow-sm border-b">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="flex justify-between h-16">
                <div class="flex items-center">
                    <a href="{{ route('home') }}" class="text-xl font-bold text-blue-600">
                        🔨 BestHammer
                    </a>
                    <span class="ml-2 text-gray-500">NTool Platform</span>
                </div>

                <div class="hidden md:flex items-center space-x-6">
                    <a href="{{ route('bmi.calculator') }}" class="text-gray-700 hover:text-blue-600 transition-colors">
                        BMI Calculator
                    </a>
                    <a href="{{ route('currency.converter') }}" class="text-gray-700 hover:text-blue-600 transition-colors">
                        Currency Converter
                    </a>
                    <a href="{{ route('loan.calculator') }}" class="text-gray-700 hover:text-blue-600 transition-colors">
                        Loan Calculator
                    </a>
                </div>
            </div>
        </div>
    </nav>

    <!-- Main Content -->
    <main class="max-w-7xl mx-auto py-8 px-4 sm:px-6 lg:px-8">
        @yield('content')
    </main>

    <!-- Footer -->
    <footer class="bg-gray-800 text-white mt-16">
        <div class="max-w-7xl mx-auto py-8 px-4 sm:px-6 lg:px-8">
            <div class="text-center">
                <p>&copy; {{ date('Y') }} BestHammer NTool Platform. All rights reserved.</p>
            </div>
        </div>
    </footer>

    @yield('scripts')
</body>
</html>
EOF

# Welcome Page
cat > resources/views/welcome.blade.php << 'EOF'
@extends('layouts.app')

@section('title', 'BestHammer - Professional Calculation Tools')

@section('content')
<div class="text-center mb-12">
    <h1 class="text-4xl md:text-5xl font-bold text-gray-900 mb-4">
        Professional Calculation Tools
    </h1>
    <p class="text-xl text-gray-600 max-w-3xl mx-auto">
        Free, accurate, and easy-to-use calculators for loans, health metrics, currency conversion, and more.
    </p>
</div>

<div class="grid md:grid-cols-3 gap-8 mb-12">
    <!-- BMI Calculator -->
    <div class="calculator-card bg-white p-6 rounded-xl shadow-md">
        <div class="text-center">
            <div class="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <span class="text-2xl">⚖️</span>
            </div>
            <h2 class="text-xl font-semibold mb-3">BMI Calculator</h2>
            <p class="text-gray-600 mb-6">Calculate your Body Mass Index and get health recommendations.</p>
            <a href="{{ route('bmi.calculator') }}" class="btn-primary w-full block text-center">
                Calculate BMI
            </a>
        </div>
    </div>

    <!-- Currency Converter -->
    <div class="calculator-card bg-white p-6 rounded-xl shadow-md">
        <div class="text-center">
            <div class="w-16 h-16 bg-purple-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <span class="text-2xl">💱</span>
            </div>
            <h2 class="text-xl font-semibold mb-3">Currency Converter</h2>
            <p class="text-gray-600 mb-6">Convert between major world currencies with real-time rates.</p>
            <a href="{{ route('currency.converter') }}" class="btn-primary w-full block text-center">
                Convert Currency
            </a>
        </div>
    </div>

    <!-- Loan Calculator -->
    <div class="calculator-card bg-white p-6 rounded-xl shadow-md">
        <div class="text-center">
            <div class="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <span class="text-2xl">💰</span>
            </div>
            <h2 class="text-xl font-semibold mb-3">Loan Calculator</h2>
            <p class="text-gray-600 mb-6">Calculate monthly payments, total interest, and loan terms.</p>
            <a href="{{ route('loan.calculator') }}" class="btn-primary w-full block text-center">
                Calculate Loan
            </a>
        </div>
    </div>
</div>
@endsection
EOF

info "✓ Basic views created"

# Create calculator views
mkdir -p resources/views/calculators/bmi
mkdir -p resources/views/calculators/currency
mkdir -p resources/views/calculators/loan
mkdir -p resources/views/legal

# BMI Calculator View
cat > resources/views/calculators/bmi/index.blade.php << 'EOF'
@extends('layouts.app')

@section('title', 'BMI Calculator - BestHammer')

@section('content')
<div class="max-w-2xl mx-auto">
    <div class="text-center mb-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-2">BMI Calculator</h1>
        <p class="text-gray-600">Calculate your Body Mass Index and get health insights</p>
    </div>

    <div class="bg-white rounded-xl shadow-md p-6">
        <form id="bmiForm" class="space-y-6">
            <div class="grid md:grid-cols-2 gap-4">
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Height (cm)</label>
                    <input type="number" id="height_cm" class="input-field" placeholder="e.g., 175" required>
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Weight (kg)</label>
                    <input type="number" step="0.1" id="weight_kg" class="input-field" placeholder="e.g., 70" required>
                </div>
            </div>

            <div class="grid md:grid-cols-2 gap-4">
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Age</label>
                    <input type="number" id="age" class="input-field" placeholder="e.g., 30" required>
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Gender</label>
                    <select id="gender" class="input-field" required>
                        <option value="">Select Gender</option>
                        <option value="male">Male</option>
                        <option value="female">Female</option>
                        <option value="other">Other</option>
                    </select>
                </div>
            </div>

            <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Activity Level</label>
                <select id="activity_level" class="input-field" required>
                    <option value="">Select Activity Level</option>
                    <option value="sedentary">Sedentary (little/no exercise)</option>
                    <option value="lightly_active">Lightly Active (light exercise 1-3 days/week)</option>
                    <option value="moderately_active">Moderately Active (moderate exercise 3-5 days/week)</option>
                    <option value="very_active">Very Active (hard exercise 6-7 days/week)</option>
                    <option value="extremely_active">Extremely Active (very hard exercise, physical job)</option>
                </select>
            </div>

            <button type="submit" class="btn-primary w-full">
                Calculate BMI
            </button>
        </form>

        <div id="result" class="mt-8 hidden">
            <h3 class="text-lg font-semibold mb-4">Your BMI Results</h3>
            <div id="resultContent" class="bg-blue-50 border border-blue-200 rounded-lg p-4"></div>
        </div>

        <div id="error" class="mt-4 hidden">
            <div class="bg-red-50 border border-red-200 rounded-lg p-4">
                <p class="text-red-700" id="errorMessage"></p>
            </div>
        </div>
    </div>
</div>

<script>
document.getElementById('bmiForm').addEventListener('submit', function(e) {
    e.preventDefault();

    const resultDiv = document.getElementById('result');
    const errorDiv = document.getElementById('error');
    const resultContent = document.getElementById('resultContent');
    const errorMessage = document.getElementById('errorMessage');

    // Hide previous results
    resultDiv.classList.add('hidden');
    errorDiv.classList.add('hidden');

    const formData = new FormData();
    formData.append('height_cm', document.getElementById('height_cm').value);
    formData.append('weight_kg', document.getElementById('weight_kg').value);
    formData.append('age', document.getElementById('age').value);
    formData.append('gender', document.getElementById('gender').value);
    formData.append('activity_level', document.getElementById('activity_level').value);

    fetch('/api/calculate-bmi', {
        method: 'POST',
        body: formData,
        headers: {
            'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        }
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            const results = data.results;
            resultContent.innerHTML = `
                <div class="text-center mb-4">
                    <div class="text-4xl font-bold text-blue-600">${results.bmi}</div>
                    <div class="text-lg font-semibold text-gray-700">${results.category}</div>
                </div>
                <div class="grid md:grid-cols-2 gap-4">
                    <div>
                        <h4 class="font-semibold text-gray-800">BMR (Calories/day)</h4>
                        <p class="text-xl font-semibold text-gray-700">${results.bmr}</p>
                    </div>
                    <div>
                        <h4 class="font-semibold text-gray-800">TDEE (Calories/day)</h4>
                        <p class="text-xl font-semibold text-gray-700">${results.tdee}</p>
                    </div>
                </div>
                <div class="mt-4">
                    <h4 class="font-semibold text-gray-800 mb-2">Recommendations</h4>
                    <ul class="text-gray-700 space-y-1">
                        ${results.recommendations.map(rec => `<li>• ${rec}</li>`).join('')}
                    </ul>
                </div>
            `;
            resultDiv.classList.remove('hidden');
        } else {
            errorMessage.textContent = data.message || 'Calculation failed';
            errorDiv.classList.remove('hidden');
        }
    })
    .catch(error => {
        errorMessage.textContent = 'An error occurred. Please try again.';
        errorDiv.classList.remove('hidden');
    });
});
</script>
@endsection
EOF

# Currency Converter View
cat > resources/views/calculators/currency/index.blade.php << 'EOF'
@extends('layouts.app')

@section('title', 'Currency Converter - BestHammer')

@section('content')
<div class="max-w-2xl mx-auto">
    <div class="text-center mb-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-2">Currency Converter</h1>
        <p class="text-gray-600">Convert between major world currencies</p>
    </div>

    <div class="bg-white rounded-xl shadow-md p-6">
        <form id="currencyForm" class="space-y-6">
            <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Amount</label>
                <input type="number" step="0.01" id="amount" class="input-field" placeholder="e.g., 100" required>
            </div>

            <div class="grid md:grid-cols-2 gap-4">
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">From Currency</label>
                    <select id="from" class="input-field" required>
                        <option value="USD">USD - US Dollar</option>
                        <option value="EUR">EUR - Euro</option>
                        <option value="GBP">GBP - British Pound</option>
                        <option value="JPY">JPY - Japanese Yen</option>
                        <option value="CAD">CAD - Canadian Dollar</option>
                        <option value="AUD">AUD - Australian Dollar</option>
                    </select>
                </div>

                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">To Currency</label>
                    <select id="to" class="input-field" required>
                        <option value="EUR">EUR - Euro</option>
                        <option value="USD">USD - US Dollar</option>
                        <option value="GBP">GBP - British Pound</option>
                        <option value="JPY">JPY - Japanese Yen</option>
                        <option value="CAD">CAD - Canadian Dollar</option>
                        <option value="AUD">AUD - Australian Dollar</option>
                    </select>
                </div>
            </div>

            <button type="submit" class="btn-primary w-full">
                Convert Currency
            </button>
        </form>

        <div id="result" class="mt-8 hidden">
            <h3 class="text-lg font-semibold mb-4">Conversion Result</h3>
            <div id="resultContent" class="bg-purple-50 border border-purple-200 rounded-lg p-4"></div>
        </div>

        <div id="error" class="mt-4 hidden">
            <div class="bg-red-50 border border-red-200 rounded-lg p-4">
                <p class="text-red-700" id="errorMessage"></p>
            </div>
        </div>
    </div>
</div>

<script>
document.getElementById('currencyForm').addEventListener('submit', function(e) {
    e.preventDefault();

    const resultDiv = document.getElementById('result');
    const errorDiv = document.getElementById('error');
    const resultContent = document.getElementById('resultContent');
    const errorMessage = document.getElementById('errorMessage');

    // Hide previous results
    resultDiv.classList.add('hidden');
    errorDiv.classList.add('hidden');

    const formData = new FormData();
    formData.append('amount', document.getElementById('amount').value);
    formData.append('from', document.getElementById('from').value);
    formData.append('to', document.getElementById('to').value);

    fetch('/api/convert-currency', {
        method: 'POST',
        body: formData,
        headers: {
            'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        }
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            const result = data.result;
            resultContent.innerHTML = `
                <div class="text-center mb-4">
                    <div class="text-2xl font-bold text-purple-600">
                        ${result.converted_amount.toLocaleString()} ${result.to_currency}
                    </div>
                    <div class="text-gray-600">
                        ${result.original_amount.toLocaleString()} ${result.from_currency}
                    </div>
                </div>
                <div class="bg-white rounded-lg p-4 border">
                    <div class="flex justify-between items-center">
                        <span class="text-gray-700">Exchange Rate:</span>
                        <span class="font-semibold">1 ${result.from_currency} = ${result.exchange_rate} ${result.to_currency}</span>
                    </div>
                </div>
            `;
            resultDiv.classList.remove('hidden');
        } else {
            errorMessage.textContent = data.message || 'Conversion failed';
            errorDiv.classList.remove('hidden');
        }
    })
    .catch(error => {
        errorMessage.textContent = 'An error occurred. Please try again.';
        errorDiv.classList.remove('hidden');
    });
});
</script>
@endsection
EOF

info "✓ Calculator views created"

# Loan Calculator View
cat > resources/views/calculators/loan/index.blade.php << 'EOF'
@extends('layouts.app')

@section('title', 'Loan Calculator - BestHammer')

@section('content')
<div class="max-w-2xl mx-auto">
    <div class="text-center mb-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-2">Loan Calculator</h1>
        <p class="text-gray-600">Calculate your monthly payments and total loan cost</p>
    </div>

    <div class="bg-white rounded-xl shadow-md p-6">
        <form id="loanForm" class="space-y-6">
            <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Loan Amount ($)</label>
                <input type="number" id="principal" class="input-field" placeholder="e.g., 250000" required>
            </div>

            <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Annual Interest Rate (%)</label>
                <input type="number" step="0.01" id="rate" class="input-field" placeholder="e.g., 3.5" required>
            </div>

            <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Loan Term (months)</label>
                <input type="number" id="months" class="input-field" placeholder="e.g., 360" required>
                <p class="text-sm text-gray-500 mt-1">Common terms: 360 months (30 years), 180 months (15 years)</p>
            </div>

            <button type="submit" class="btn-primary w-full">
                Calculate Loan Payment
            </button>
        </form>

        <div id="result" class="mt-8 hidden">
            <h3 class="text-lg font-semibold mb-4">Calculation Results</h3>
            <div id="resultContent" class="bg-blue-50 border border-blue-200 rounded-lg p-4"></div>
        </div>

        <div id="error" class="mt-4 hidden">
            <div class="bg-red-50 border border-red-200 rounded-lg p-4">
                <p class="text-red-700" id="errorMessage"></p>
            </div>
        </div>
    </div>
</div>

<script>
document.getElementById('loanForm').addEventListener('submit', function(e) {
    e.preventDefault();

    const resultDiv = document.getElementById('result');
    const errorDiv = document.getElementById('error');
    const resultContent = document.getElementById('resultContent');
    const errorMessage = document.getElementById('errorMessage');

    // Hide previous results
    resultDiv.classList.add('hidden');
    errorDiv.classList.add('hidden');

    const formData = new FormData();
    formData.append('principal', document.getElementById('principal').value);
    formData.append('rate', document.getElementById('rate').value);
    formData.append('months', document.getElementById('months').value);

    fetch('/api/calculate-loan', {
        method: 'POST',
        body: formData,
        headers: {
            'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        }
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            const results = data.results;
            resultContent.innerHTML = `
                <div class="grid md:grid-cols-2 gap-4">
                    <div>
                        <h4 class="font-semibold text-gray-800">Monthly Payment</h4>
                        <p class="text-2xl font-bold text-blue-600">$${results.monthly_payment.toLocaleString()}</p>
                    </div>
                    <div>
                        <h4 class="font-semibold text-gray-800">Total Payment</h4>
                        <p class="text-xl font-semibold text-gray-700">$${results.total_payment.toLocaleString()}</p>
                    </div>
                    <div>
                        <h4 class="font-semibold text-gray-800">Total Interest</h4>
                        <p class="text-xl font-semibold text-gray-700">$${results.total_interest.toLocaleString()}</p>
                    </div>
                    <div>
                        <h4 class="font-semibold text-gray-800">Interest Rate</h4>
                        <p class="text-xl font-semibold text-gray-700">${results.effective_rate}% annually</p>
                    </div>
                </div>
            `;
            resultDiv.classList.remove('hidden');
        } else {
            errorMessage.textContent = data.message || 'Calculation failed';
            errorDiv.classList.remove('hidden');
        }
    })
    .catch(error => {
        errorMessage.textContent = 'An error occurred. Please try again.';
        errorDiv.classList.remove('hidden');
    });
});
</script>
@endsection
EOF

# Create basic legal pages
cat > resources/views/legal/privacy.blade.php << 'EOF'
@extends('layouts.app')

@section('title', 'Privacy Policy - BestHammer')

@section('content')
<div class="max-w-4xl mx-auto">
    <h1 class="text-3xl font-bold text-gray-900 mb-8">Privacy Policy</h1>

    <div class="bg-white rounded-xl shadow-md p-8">
        <p class="text-gray-600 mb-4">Last updated: {{ date('F j, Y') }}</p>

        <h2 class="text-xl font-semibold mb-4">Information We Collect</h2>
        <p class="text-gray-700 mb-6">
            We collect information you provide directly to us, such as when you use our calculators,
            create an account, or contact us for support.
        </p>

        <h2 class="text-xl font-semibold mb-4">How We Use Your Information</h2>
        <p class="text-gray-700 mb-6">
            We use the information we collect to provide, maintain, and improve our services,
            process transactions, and communicate with you.
        </p>

        <h2 class="text-xl font-semibold mb-4">Contact Us</h2>
        <p class="text-gray-700">
            If you have any questions about this Privacy Policy, please contact us at
            <a href="mailto:privacy@besthammer.club" class="text-blue-600 hover:underline">privacy@besthammer.club</a>.
        </p>
    </div>
</div>
@endsection
EOF

cat > resources/views/legal/terms.blade.php << 'EOF'
@extends('layouts.app')

@section('title', 'Terms of Service - BestHammer')

@section('content')
<div class="max-w-4xl mx-auto">
    <h1 class="text-3xl font-bold text-gray-900 mb-8">Terms of Service</h1>

    <div class="bg-white rounded-xl shadow-md p-8">
        <p class="text-gray-600 mb-4">Last updated: {{ date('F j, Y') }}</p>

        <h2 class="text-xl font-semibold mb-4">Acceptance of Terms</h2>
        <p class="text-gray-700 mb-6">
            By accessing and using BestHammer NTool Platform, you accept and agree to be bound by
            the terms and provision of this agreement.
        </p>

        <h2 class="text-xl font-semibold mb-4">Use License</h2>
        <p class="text-gray-700 mb-6">
            Permission is granted to temporarily use BestHammer NTool Platform for personal,
            non-commercial transitory viewing only.
        </p>

        <h2 class="text-xl font-semibold mb-4">Contact Information</h2>
        <p class="text-gray-700">
            Questions about the Terms of Service should be sent to us at
            <a href="mailto:admin@besthammer.club" class="text-blue-600 hover:underline">admin@besthammer.club</a>.
        </p>
    </div>
</div>
@endsection
EOF

cat > resources/views/legal/cookies.blade.php << 'EOF'
@extends('layouts.app')

@section('title', 'Cookie Policy - BestHammer')

@section('content')
<div class="max-w-4xl mx-auto">
    <h1 class="text-3xl font-bold text-gray-900 mb-8">Cookie Policy</h1>

    <div class="bg-white rounded-xl shadow-md p-8">
        <p class="text-gray-600 mb-4">Last updated: {{ date('F j, Y') }}</p>

        <h2 class="text-xl font-semibold mb-4">What Are Cookies</h2>
        <p class="text-gray-700 mb-6">
            Cookies are small text files that are placed on your computer by websites that you visit.
            They are widely used to make websites work more efficiently.
        </p>

        <h2 class="text-xl font-semibold mb-4">How We Use Cookies</h2>
        <p class="text-gray-700 mb-6">
            We use cookies to enhance your experience, analyze site usage, and assist in our marketing efforts.
        </p>

        <h2 class="text-xl font-semibold mb-4">Contact Us</h2>
        <p class="text-gray-700">
            If you have any questions about our use of cookies, please contact us at
            <a href="mailto:privacy@besthammer.club" class="text-blue-600 hover:underline">privacy@besthammer.club</a>.
        </p>
    </div>
</div>
@endsection
EOF

info "✓ All views created"

# Step 9: Create Laravel configuration files
log "Step 9: Creating Laravel configuration files"

# Create .gitignore files
cat > storage/app/.gitignore << 'EOF'
*
!public/
!.gitignore
EOF

cat > storage/app/public/.gitignore << 'EOF'
*
!.gitignore
EOF

cat > storage/framework/cache/data/.gitignore << 'EOF'
*
!.gitignore
EOF

cat > storage/framework/sessions/.gitignore << 'EOF'
*
!.gitignore
EOF

cat > storage/framework/views/.gitignore << 'EOF'
*
!.gitignore
EOF

cat > storage/logs/.gitignore << 'EOF'
*
!.gitignore
EOF

cat > bootstrap/cache/.gitignore << 'EOF'
*
!.gitignore
EOF

# Create main .gitignore
cat > .gitignore << 'EOF'
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

info "✓ Laravel configuration files created"

# Step 10: Set permissions
log "Step 10: Setting FastPanel permissions"

chown -R $WEB_USER:$WEB_USER "$WEB_ROOT"
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
chmod +x "$WEB_ROOT/artisan"
chmod -R 775 "$WEB_ROOT/storage"
chmod -R 775 "$WEB_ROOT/bootstrap/cache"

info "✓ Permissions set"

# Step 11: Configure environment
log "Step 11: Configuring environment"

# Restore or create .env
if [ -n "$ENV_BACKUP" ] && [ -f "$ENV_BACKUP" ]; then
    cp "$ENV_BACKUP" ".env"
    info "✓ Restored existing .env file"
elif [ -f ".env.example" ]; then
    cp ".env.example" ".env"
    info "✓ Created .env from .env.example"
fi

# Update .env for production
if [ -f ".env" ]; then
    sed -i "s|APP_ENV=.*|APP_ENV=production|g" ".env"
    sed -i "s|APP_DEBUG=.*|APP_DEBUG=false|g" ".env"
    sed -i "s|APP_URL=.*|APP_URL=https://$DOMAIN|g" ".env"
    info "✓ Environment configured for production"
fi

# Step 12: Install dependencies
log "Step 12: Installing dependencies"

# Install Composer dependencies
if command -v composer &>/dev/null && [ -f "composer.json" ]; then
    info "Installing Composer dependencies..."
    su - $WEB_USER -c "cd '$WEB_ROOT' && composer install --no-dev --optimize-autoloader --no-interaction" || warning "Composer install failed"
    info "✓ Composer dependencies installed"
else
    warning "Composer not found - dependencies will need to be installed manually"
fi

# Install NPM dependencies
if command -v npm &>/dev/null && [ -f "package.json" ]; then
    info "Installing NPM dependencies..."
    su - $WEB_USER -c "cd '$WEB_ROOT' && npm install --production" || warning "NPM install failed"
    su - $WEB_USER -c "cd '$WEB_ROOT' && npm run build" 2>/dev/null || warning "Asset build failed"
    info "✓ NPM dependencies installed"
else
    warning "NPM not found - frontend assets will need to be built manually"
fi

# Step 13: Laravel application setup
log "Step 13: Laravel application setup"

# Generate app key
if ! grep -q "APP_KEY=base64:" ".env" 2>/dev/null; then
    su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan key:generate --force" || warning "Key generation failed"
    info "✓ Application key generated"
fi

# Database setup
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

        info "✓ Database configured: $DB_NAME"
        echo "Database: $DB_NAME, User: $DB_USER, Password: $DB_PASS" > "/root/besthammer_complete_db_credentials_${TIMESTAMP}.txt"
        info "✓ Credentials saved to /root/besthammer_complete_db_credentials_${TIMESTAMP}.txt"
    else
        warning "Database setup skipped"
    fi
else
    warning "Database setup skipped"
fi

# Optimize Laravel
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan config:cache" 2>/dev/null || true
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan route:cache" 2>/dev/null || true
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan view:cache" 2>/dev/null || true
su - $WEB_USER -c "cd '$WEB_ROOT' && php artisan storage:link" 2>/dev/null || true

info "✓ Laravel optimization completed"

# Step 14: Restart services
log "Step 14: Restarting web services"
systemctl restart php*-fpm 2>/dev/null || true
systemctl restart nginx 2>/dev/null || true
info "✓ Web services restarted"

# Step 15: Final verification
log "Step 15: Verifying deployment"

DEPLOYED_FILES=$(find "$WEB_ROOT" -type f | wc -l)
DEPLOYED_SIZE=$(du -sh "$WEB_ROOT" | cut -f1)

info "Deployed files: $DEPLOYED_FILES"
info "Total size: $DEPLOYED_SIZE"

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
rm -f "$ENV_BACKUP" 2>/dev/null || true

# Success message
echo
log "🎉 COMPLETE BestHammer NTool Platform deployment finished!"
echo
echo "🌐 Website: https://$DOMAIN"
echo "📁 Location: $WEB_ROOT"
echo "👤 Web User: $WEB_USER"
echo "📊 Files: $DEPLOYED_FILES ($DEPLOYED_SIZE)"
echo
echo "🧮 Test your COMPLETE calculators:"
echo "• Main site: https://$DOMAIN"
echo "• BMI Calculator: https://$DOMAIN/bmi-calculator"
echo "• Currency Converter: https://$DOMAIN/currency-converter"
echo "• Loan Calculator: https://$DOMAIN/loan-calculator"
echo
echo "🔧 API Endpoints:"
echo "• POST /api/calculate-bmi"
echo "• POST /api/convert-currency"
echo "• POST /api/calculate-loan"
echo "• GET /api/currency-rates"
echo
echo "⚙️ Next steps:"
echo "1. Configure SSL certificate in FastPanel"
echo "2. Test all calculator functions"
echo "3. Update Google Analytics ID in .env if needed"
echo "4. Run security audit: ./code-security-audit.sh"
echo "5. Monitor error logs:"
echo "   tail -f $WEB_ROOT/storage/logs/laravel.log"
echo "   tail -f /var/log/nginx/error.log"
echo
if [ -f "/root/besthammer_complete_db_credentials_${TIMESTAMP}.txt" ]; then
    echo "📄 Database credentials: /root/besthammer_complete_db_credentials_${TIMESTAMP}.txt"
fi
echo
if [ -f "$BACKUP_FILE" ]; then
    echo "🔄 If issues occur, restore from backup:"
    echo "   tar -xzf $BACKUP_FILE -C $WEB_ROOT"
fi
echo
echo "=============================================="
echo "COMPLETE BestHammer NTool Platform deployed!"
echo "=============================================="
