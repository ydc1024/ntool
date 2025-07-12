#!/bin/bash

# Debug Script for Source File Detection
# This script helps diagnose why source-deploy-fixed.sh fails to detect Laravel files

set -e

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

echo "🔍 Laravel Source File Detection Debug"
echo "====================================="
echo "Current directory: $(pwd)"
echo "Current user: $(whoami)"
echo "Time: $(date)"
echo "====================================="
echo

# Store original directory
ORIGINAL_DIR=$(pwd)
info "Original directory: $ORIGINAL_DIR"

# Check current directory contents
log "Step 1: Checking current directory contents..."
echo "Files and directories in current directory:"
ls -la | head -20
echo

# Check for Laravel files specifically
log "Step 2: Checking for specific Laravel files..."

# Check composer.json
if [ -f "composer.json" ]; then
    log "✓ composer.json exists"
    info "File size: $(du -h composer.json | cut -f1)"
    info "File permissions: $(ls -l composer.json | cut -d' ' -f1)"
    info "File owner: $(ls -l composer.json | cut -d' ' -f3-4)"
else
    error "✗ composer.json NOT found"
fi

# Check artisan
if [ -f "artisan" ]; then
    log "✓ artisan exists"
    info "File size: $(du -h artisan | cut -f1)"
    info "File permissions: $(ls -l artisan | cut -d' ' -f1)"
    info "File owner: $(ls -l artisan | cut -d' ' -f3-4)"
else
    error "✗ artisan NOT found"
fi

# Check app directory
if [ -d "app" ]; then
    log "✓ app/ directory exists"
    info "Directory permissions: $(ls -ld app | cut -d' ' -f1)"
    info "Directory owner: $(ls -ld app | cut -d' ' -f3-4)"
    info "Contents count: $(find app -type f | wc -l) files"
else
    error "✗ app/ directory NOT found"
fi

echo

# Check Laravel directories
log "Step 3: Checking Laravel directory structure..."
ESSENTIAL_DIRS=("app" "config" "database" "public" "resources" "routes")

for dir in "${ESSENTIAL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        log "✓ $dir/ exists"
        file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
        info "  Contains $file_count files"
    else
        error "✗ $dir/ NOT found"
    fi
done

echo

# Test the exact detection logic from source-deploy-fixed.sh
log "Step 4: Testing exact detection logic..."

# Replicate the exact logic from the script
SOURCE_DIR=""

info "Testing condition 1: Current directory Laravel detection"
echo "Checking: [ -f \"composer.json\" ] && [ -d \"app\" ] && [ -f \"artisan\" ]"

if [ -f "composer.json" ]; then
    info "✓ composer.json test passed"
else
    error "✗ composer.json test failed"
fi

if [ -d "app" ]; then
    info "✓ app directory test passed"
else
    error "✗ app directory test failed"
fi

if [ -f "artisan" ]; then
    info "✓ artisan test passed"
else
    error "✗ artisan test failed"
fi

# Combined test
if [ -f "composer.json" ] && [ -d "app" ] && [ -f "artisan" ]; then
    SOURCE_DIR="$ORIGINAL_DIR"
    log "✅ CURRENT DIRECTORY DETECTION: SUCCESS"
    info "Source directory set to: $SOURCE_DIR"
else
    error "❌ CURRENT DIRECTORY DETECTION: FAILED"
fi

echo

info "Testing condition 2: ntool subdirectory detection"
echo "Checking: [ -d \"ntool\" ] && [ -f \"ntool/composer.json\" ] && [ -d \"ntool/app\" ] && [ -f \"ntool/artisan\" ]"

if [ -d "ntool" ]; then
    info "✓ ntool directory exists"
    
    if [ -f "ntool/composer.json" ]; then
        info "✓ ntool/composer.json exists"
    else
        info "✗ ntool/composer.json NOT found"
    fi
    
    if [ -d "ntool/app" ]; then
        info "✓ ntool/app directory exists"
    else
        info "✗ ntool/app directory NOT found"
    fi
    
    if [ -f "ntool/artisan" ]; then
        info "✓ ntool/artisan exists"
    else
        info "✗ ntool/artisan NOT found"
    fi
    
    # Combined test for ntool
    if [ -f "ntool/composer.json" ] && [ -d "ntool/app" ] && [ -f "ntool/artisan" ]; then
        log "✅ NTOOL DIRECTORY DETECTION: SUCCESS"
        if [ -z "$SOURCE_DIR" ]; then
            SOURCE_DIR="$ORIGINAL_DIR/ntool"
            info "Source directory set to: $SOURCE_DIR"
        fi
    else
        info "❌ NTOOL DIRECTORY DETECTION: FAILED"
    fi
else
    info "ℹ️ ntool directory does not exist"
fi

echo

# Final result
log "Step 5: Final detection result..."

if [ -n "$SOURCE_DIR" ]; then
    log "🎉 SUCCESS: Laravel source detected!"
    info "Source directory: $SOURCE_DIR"
    
    # Test file access in source directory
    log "Testing file access in source directory..."
    
    if [ -r "$SOURCE_DIR/composer.json" ]; then
        info "✓ Can read composer.json"
    else
        error "✗ Cannot read composer.json"
    fi
    
    if [ -r "$SOURCE_DIR/artisan" ]; then
        info "✓ Can read artisan"
    else
        error "✗ Cannot read artisan"
    fi
    
    if [ -r "$SOURCE_DIR/app" ]; then
        info "✓ Can read app directory"
    else
        error "✗ Cannot read app directory"
    fi
    
else
    error "💥 FAILURE: Laravel source NOT detected!"
    echo
    error "This indicates a problem with the detection logic or file permissions"
fi

echo

# Additional debugging information
log "Step 6: Additional debugging information..."

info "Current working directory: $(pwd)"
info "Script location: $0"
info "User ID: $(id)"
info "Groups: $(groups)"

# Check if we're in a symbolic link
if [ -L "$(pwd)" ]; then
    warning "Current directory is a symbolic link"
    info "Real path: $(realpath .)"
fi

# Check file system type
info "File system type: $(df -T . | tail -1 | awk '{print $2}')"

# Check for any hidden Laravel files
log "Checking for hidden Laravel files..."
if [ -f ".env" ]; then
    info "✓ .env file exists"
fi

if [ -f ".env.example" ]; then
    info "✓ .env.example file exists"
fi

if [ -f ".gitignore" ]; then
    info "✓ .gitignore file exists"
fi

echo

# Test exact command that would be used in the script
log "Step 7: Testing exact commands from script..."

echo "Testing: [ -f \"composer.json\" ]"
if [ -f "composer.json" ]; then
    echo "Result: TRUE"
else
    echo "Result: FALSE"
fi

echo "Testing: [ -d \"app\" ]"
if [ -d "app" ]; then
    echo "Result: TRUE"
else
    echo "Result: FALSE"
fi

echo "Testing: [ -f \"artisan\" ]"
if [ -f "artisan" ]; then
    echo "Result: TRUE"
else
    echo "Result: FALSE"
fi

echo

# Final recommendation
log "🎯 Diagnosis Summary:"

if [ -n "$SOURCE_DIR" ]; then
    log "✅ Laravel files are properly detected"
    info "The issue may be elsewhere in the script"
    info "Try running the deployment script with verbose output"
else
    error "❌ Laravel files are NOT being detected"
    error "Possible causes:"
    error "1. File permission issues"
    error "2. Symbolic link issues"
    error "3. File system issues"
    error "4. Script logic issues"
    echo
    info "Recommended fixes:"
    info "1. Check file permissions: ls -la"
    info "2. Ensure you're in the correct directory"
    info "3. Try running as different user"
    info "4. Check if files are actually present and readable"
fi

echo
echo "====================================="
echo "Debug completed at $(date)"
echo "====================================="
