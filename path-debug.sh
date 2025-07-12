#!/bin/bash

# Path Debug Script - Find Laravel Source Location
# This script helps identify the exact location of Laravel files

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

echo "🔍 Laravel Source Path Debug"
echo "============================"
echo "Current directory: $(pwd)"
echo "Current user: $(whoami)"
echo "============================"
echo

# Show current directory structure
log "Step 1: Current directory analysis"
info "Current directory: $(pwd)"
info "Absolute path: $(realpath .)"
echo "Contents:"
ls -la
echo

# Check for Laravel files in current directory
log "Step 2: Checking current directory for Laravel files"
echo "Testing: composer.json"
if [ -f "composer.json" ]; then
    log "✓ composer.json exists"
else
    error "✗ composer.json NOT found"
fi

echo "Testing: artisan"
if [ -f "artisan" ]; then
    log "✓ artisan exists"
else
    error "✗ artisan NOT found"
fi

echo "Testing: app directory"
if [ -d "app" ]; then
    log "✓ app directory exists"
else
    error "✗ app directory NOT found"
fi
echo

# Check parent directory
log "Step 3: Checking parent directory"
PARENT_DIR="$(realpath ..)"
info "Parent directory: $PARENT_DIR"
echo "Parent directory contents:"
ls -la .. | head -20
echo

# Check for ntool in parent directory
log "Step 4: Checking for ntool in parent directory"
echo "Testing: ../ntool/"
if [ -d "../ntool" ]; then
    log "✓ ../ntool directory exists"
    info "Path: $(realpath ../ntool)"
    echo "Contents of ../ntool:"
    ls -la ../ntool | head -15
    echo
    
    # Check Laravel files in ../ntool
    echo "Testing Laravel files in ../ntool:"
    
    if [ -f "../ntool/composer.json" ]; then
        log "✓ ../ntool/composer.json exists"
    else
        error "✗ ../ntool/composer.json NOT found"
    fi
    
    if [ -f "../ntool/artisan" ]; then
        log "✓ ../ntool/artisan exists"
    else
        error "✗ ../ntool/artisan NOT found"
    fi
    
    if [ -d "../ntool/app" ]; then
        log "✓ ../ntool/app directory exists"
    else
        error "✗ ../ntool/app directory NOT found"
    fi
else
    error "✗ ../ntool directory NOT found"
fi
echo

# Check for other possible locations
log "Step 5: Searching for Laravel files in nearby directories"

# Search for composer.json files
echo "Searching for composer.json files:"
find .. -name "composer.json" -type f 2>/dev/null | head -10

echo
echo "Searching for artisan files:"
find .. -name "artisan" -type f 2>/dev/null | head -10

echo
echo "Searching for app directories:"
find .. -name "app" -type d 2>/dev/null | head -10
echo

# Check specific paths based on directory listing
log "Step 6: Checking specific paths from directory listing"

# From the previous directory listing, we saw ../ntool with Laravel files
POSSIBLE_PATHS=(
    "../ntool"
    "../../ntool"
    "./ntool"
    "../"
)

for path in "${POSSIBLE_PATHS[@]}"; do
    echo "Testing path: $path"
    if [ -d "$path" ]; then
        info "✓ Directory exists: $(realpath $path 2>/dev/null || echo $path)"
        
        # Check for Laravel files
        if [ -f "$path/composer.json" ] && [ -f "$path/artisan" ] && [ -d "$path/app" ]; then
            log "🎉 FOUND LARAVEL SOURCE: $path"
            info "Absolute path: $(realpath $path)"
            
            # Show Laravel info
            if [ -f "$path/composer.json" ]; then
                echo "Laravel application info:"
                grep -E '"name"|"description"' "$path/composer.json" | head -2
            fi
            
            echo "File count: $(find $path -type f -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/vendor/*" | wc -l)"
            echo
        else
            info "Directory exists but no Laravel files found"
        fi
    else
        info "✗ Directory does not exist: $path"
    fi
    echo
done

# Final recommendation
log "Step 7: Final analysis and recommendation"

# Test the exact conditions from the deploy script
echo "Testing exact deploy script conditions:"

echo "Condition 1: Current directory"
if [ -f "composer.json" ] && [ -d "app" ] && [ -f "artisan" ]; then
    log "✅ Current directory has Laravel files"
    FOUND_SOURCE="$(pwd)"
else
    error "❌ Current directory missing Laravel files"
fi

echo "Condition 2: ../ntool directory"
if [ -f "../ntool/composer.json" ] && [ -d "../ntool/app" ] && [ -f "../ntool/artisan" ]; then
    log "✅ ../ntool has Laravel files"
    FOUND_SOURCE="$(realpath ../ntool)"
else
    error "❌ ../ntool missing Laravel files"
fi

echo
if [ -n "$FOUND_SOURCE" ]; then
    log "🎉 SUCCESS: Laravel source found at: $FOUND_SOURCE"
    echo
    info "To deploy, run:"
    info "cd '$FOUND_SOURCE'"
    info "sudo ./simple-source-deploy.sh"
    echo
    info "Or create a direct deployment command:"
    echo "sudo bash -c 'cd \"$FOUND_SOURCE\" && ./simple-source-deploy.sh'"
else
    error "💥 FAILURE: No Laravel source found"
    echo
    warning "Possible solutions:"
    warning "1. Ensure you have the correct Laravel source files"
    warning "2. Check if files are in a different location"
    warning "3. Verify file permissions"
    warning "4. Check if this is the correct server/directory"
fi

echo
echo "============================"
echo "Path debug completed"
echo "============================"
