#!/bin/bash

# Analyze Existing Website Files in FastPanel
# This script analyzes the current website files and prepares for selective replacement

set -e

# Configuration
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
error() { echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️ $1${NC}"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    error "Run as root: sudo ./analyze-existing-website.sh"
fi

echo "🔍 Analyze Existing Website Files in FastPanel"
echo "=============================================="
echo "Website Root: $WEB_ROOT"
echo "Web User: $WEB_USER"
echo "Analysis Time: $(date)"
echo "=============================================="
echo

# Check if web root exists
if [ ! -d "$WEB_ROOT" ]; then
    error "Website root directory does not exist: $WEB_ROOT"
fi

cd "$WEB_ROOT"

# Step 1: General file analysis
log "Step 1: General file analysis"

TOTAL_FILES=$(find . -type f | wc -l)
TOTAL_DIRS=$(find . -type d | wc -l)
TOTAL_SIZE=$(du -sh . | cut -f1)

info "Total files: $TOTAL_FILES"
info "Total directories: $TOTAL_DIRS"
info "Total size: $TOTAL_SIZE"
echo

# Step 2: Check for Laravel files
log "Step 2: Laravel framework detection"

LARAVEL_FILES=("composer.json" "artisan" ".env" ".env.example")
LARAVEL_DIRS=("app" "config" "database" "public" "resources" "routes" "storage" "bootstrap")

echo "Laravel files:"
for file in "${LARAVEL_FILES[@]}"; do
    if [ -f "$file" ]; then
        log "✓ $file exists"
        
        # Show file info
        FILE_SIZE=$(du -h "$file" | cut -f1)
        FILE_DATE=$(stat -c %y "$file" | cut -d' ' -f1)
        info "  Size: $FILE_SIZE, Modified: $FILE_DATE"
        
        # Show content preview for key files
        if [ "$file" = "composer.json" ]; then
            echo "  Content preview:"
            head -10 "$file" | sed 's/^/    /'
        fi
    else
        warning "✗ $file missing"
    fi
done

echo
echo "Laravel directories:"
for dir in "${LARAVEL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        DIR_FILES=$(find "$dir" -type f | wc -l)
        log "✓ $dir exists ($DIR_FILES files)"
    else
        warning "✗ $dir missing"
    fi
done
echo

# Step 3: Identify Laravel application type
log "Step 3: Laravel application identification"

if [ -f "composer.json" ]; then
    echo "Composer.json analysis:"
    
    # Extract app name
    APP_NAME=$(grep '"name"' composer.json | head -1 | cut -d'"' -f4 2>/dev/null || echo "Unknown")
    info "Application name: $APP_NAME"
    
    # Extract Laravel version
    LARAVEL_VERSION=$(grep '"laravel/framework"' composer.json | cut -d'"' -f4 2>/dev/null || echo "Unknown")
    info "Laravel version: $LARAVEL_VERSION"
    
    # Check for BestHammer specific content
    if grep -q "besthammer\|ntool\|calculator" composer.json; then
        log "✓ BestHammer/NTool content detected in composer.json"
    else
        warning "No BestHammer/NTool content found in composer.json"
    fi
fi

if [ -f ".env" ]; then
    echo
    echo ".env file analysis:"
    
    # Extract app name from .env
    ENV_APP_NAME=$(grep "^APP_NAME=" .env | cut -d'=' -f2 | tr -d '"' 2>/dev/null || echo "Unknown")
    info "App name in .env: $ENV_APP_NAME"
    
    # Check for BestHammer specific config
    if grep -q "besthammer\|ntool\|calculator" .env; then
        log "✓ BestHammer/NTool configuration detected in .env"
    else
        warning "No BestHammer/NTool configuration found in .env"
    fi
    
    # Show database config
    DB_NAME=$(grep "^DB_DATABASE=" .env | cut -d'=' -f2 2>/dev/null || echo "Not set")
    info "Database name: $DB_NAME"
fi
echo

# Step 4: Check for non-Laravel files
log "Step 4: Non-Laravel files detection"

echo "Checking for common non-Laravel files:"

NON_LARAVEL_PATTERNS=("*.html" "*.htm" "wp-*" "wordpress" "index.php" "*.zip" "*.tar.gz")
FOUND_NON_LARAVEL=()

for pattern in "${NON_LARAVEL_PATTERNS[@]}"; do
    if find . -maxdepth 2 -name "$pattern" -type f | head -5 | grep -q .; then
        FOUND_NON_LARAVEL+=("$pattern")
    fi
done

if [ ${#FOUND_NON_LARAVEL[@]} -gt 0 ]; then
    warning "Non-Laravel files found:"
    for pattern in "${FOUND_NON_LARAVEL[@]}"; do
        echo "  Files matching $pattern:"
        find . -maxdepth 2 -name "$pattern" -type f | head -5 | sed 's/^/    /'
    done
else
    log "✓ No obvious non-Laravel files detected"
fi
echo

# Step 5: Check for BestHammer specific files
log "Step 5: BestHammer NTool specific content"

echo "Searching for BestHammer/NTool specific content:"

# Search in PHP files
if find . -name "*.php" -exec grep -l "besthammer\|ntool\|calculator" {} \; | head -5 | grep -q .; then
    log "✓ BestHammer/NTool content found in PHP files:"
    find . -name "*.php" -exec grep -l "besthammer\|ntool\|calculator" {} \; | head -5 | sed 's/^/  /'
else
    warning "No BestHammer/NTool content found in PHP files"
fi

# Search in views
if [ -d "resources/views" ]; then
    if find resources/views -name "*.blade.php" -exec grep -l "calculator\|loan\|bmi\|currency" {} \; | head -5 | grep -q .; then
        log "✓ Calculator views found:"
        find resources/views -name "*.blade.php" -exec grep -l "calculator\|loan\|bmi\|currency" {} \; | head -5 | sed 's/^/  /'
    else
        warning "No calculator views found"
    fi
fi

# Search in routes
if [ -f "routes/web.php" ]; then
    if grep -q "calculator\|loan\|bmi\|currency" routes/web.php; then
        log "✓ Calculator routes found in routes/web.php"
        grep "calculator\|loan\|bmi\|currency" routes/web.php | sed 's/^/  /'
    else
        warning "No calculator routes found in routes/web.php"
    fi
fi
echo

# Step 6: File replacement strategy
log "Step 6: File replacement strategy analysis"

echo "Files that should be replaced with new BestHammer NTool content:"

REPLACE_FILES=(
    "composer.json"
    "package.json"
    ".env.example"
    "routes/web.php"
    "routes/api.php"
    "app/Http/Controllers/*"
    "resources/views/*"
    "resources/js/*"
    "resources/css/*"
    "database/migrations/*"
    "database/seeders/*"
)

for file_pattern in "${REPLACE_FILES[@]}"; do
    if find . -path "./$file_pattern" -type f | head -1 | grep -q .; then
        info "✓ $file_pattern - exists, will be replaced"
    else
        info "○ $file_pattern - doesn't exist, will be created"
    fi
done

echo
echo "Files/directories that should be preserved:"
PRESERVE_ITEMS=(
    ".env (if exists)"
    "storage/logs/*"
    "vendor/ (will be regenerated)"
    "node_modules/ (will be regenerated)"
)

for item in "${PRESERVE_ITEMS[@]}"; do
    info "• $item"
done

echo
echo "Files/directories that should be removed:"
REMOVE_PATTERNS=(
    "*.html (if not Laravel views)"
    "wp-* (WordPress files)"
    "*.zip, *.tar.gz (archive files)"
    "Old backup files"
    "Unused static files"
)

for pattern in "${REMOVE_PATTERNS[@]}"; do
    warning "• $pattern"
done
echo

# Step 7: Generate replacement plan
log "Step 7: Generating replacement plan"

PLAN_FILE="/tmp/replacement_plan_${TIMESTAMP}.txt"

cat > "$PLAN_FILE" << EOF
BestHammer NTool Website Replacement Plan
========================================
Generated: $(date)
Website Root: $WEB_ROOT

Current Status:
- Total files: $TOTAL_FILES
- Total size: $TOTAL_SIZE
- Laravel detected: $([ -f "composer.json" ] && echo "Yes" || echo "No")
- BestHammer content: $(grep -q "besthammer\|ntool" composer.json 2>/dev/null && echo "Yes" || echo "No")

Replacement Strategy:
1. Backup current website
2. Preserve .env file (if exists)
3. Replace all application files with new BestHammer NTool content
4. Remove non-Laravel files
5. Install dependencies
6. Run migrations
7. Set proper permissions

Files to Replace:
$(for file in "${REPLACE_FILES[@]}"; do echo "- $file"; done)

Files to Preserve:
$(for item in "${PRESERVE_ITEMS[@]}"; do echo "- $item"; done)

Files to Remove:
$(for pattern in "${REMOVE_PATTERNS[@]}"; do echo "- $pattern"; done)

Next Steps:
1. Run: sudo ./selective-replace-deploy.sh
2. Test website functionality
3. Configure SSL in FastPanel
EOF

info "Replacement plan saved to: $PLAN_FILE"

# Step 8: Summary and recommendations
echo
log "🎯 Analysis Summary and Recommendations"

if [ -f "composer.json" ] && [ -d "app" ] && [ -f "artisan" ]; then
    log "✅ GOOD: Existing Laravel application detected"
    
    if grep -q "besthammer\|ntool" composer.json 2>/dev/null; then
        log "✅ EXCELLENT: BestHammer/NTool content already present"
        info "Recommendation: Update existing content with new version"
    else
        warning "⚠️ ATTENTION: Generic Laravel app, needs BestHammer content"
        info "Recommendation: Replace with BestHammer NTool content"
    fi
else
    warning "⚠️ ATTENTION: Incomplete or non-Laravel application"
    info "Recommendation: Complete replacement with BestHammer NTool"
fi

echo
info "Recommended next steps:"
info "1. Create selective replacement deployment script"
info "2. Backup existing .env and important data"
info "3. Replace application files with BestHammer NTool content"
info "4. Test functionality"
echo

echo "=============================================="
echo "Website analysis completed"
echo "Plan file: $PLAN_FILE"
echo "=============================================="
