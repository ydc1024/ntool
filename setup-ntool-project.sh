#!/bin/bash

# Setup NTool Project Structure Script
# This script creates the complete Laravel project structure in the ntool directory

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Configuration
NTOOL_DIR="/root/ntool"
CURRENT_DIR=$(pwd)

log "Setting up complete NTool Laravel project structure..."

# Check if we're in the right directory (where all the Laravel files are)
if [ ! -f "composer.json" ] || [ ! -f "artisan" ]; then
    error "Please run this script from the directory containing the complete Laravel project files"
fi

# Create ntool directory if it doesn't exist
if [ ! -d "$NTOOL_DIR" ]; then
    mkdir -p "$NTOOL_DIR"
    log "Created ntool directory: $NTOOL_DIR"
fi

# Backup existing ntool directory if it has content
if [ "$(ls -A $NTOOL_DIR 2>/dev/null)" ]; then
    BACKUP_DIR="/root/ntool_backup_$(date +%Y%m%d_%H%M%S)"
    log "Backing up existing ntool directory to: $BACKUP_DIR"
    cp -r "$NTOOL_DIR" "$BACKUP_DIR"
fi

# Copy all Laravel project files to ntool directory
log "Copying Laravel project files to $NTOOL_DIR..."

# Copy all files and directories
cp -r * "$NTOOL_DIR/" 2>/dev/null || true
cp -r .[^.]* "$NTOOL_DIR/" 2>/dev/null || true

# Set proper permissions
log "Setting proper permissions..."
chmod +x "$NTOOL_DIR/artisan"
chmod -R 755 "$NTOOL_DIR"

# Create necessary directories if they don't exist
log "Creating necessary directories..."
mkdir -p "$NTOOL_DIR/storage/app/public"
mkdir -p "$NTOOL_DIR/storage/framework/cache/data"
mkdir -p "$NTOOL_DIR/storage/framework/sessions"
mkdir -p "$NTOOL_DIR/storage/framework/views"
mkdir -p "$NTOOL_DIR/storage/logs"
mkdir -p "$NTOOL_DIR/bootstrap/cache"

# Set storage permissions
chmod -R 775 "$NTOOL_DIR/storage"
chmod -R 775 "$NTOOL_DIR/bootstrap/cache"

# Verify the setup
log "Verifying project structure..."

# Check for essential files
essential_files=(
    "composer.json"
    "package.json"
    "artisan"
    ".env.example"
    "app/Http/Kernel.php"
    "config/app.php"
    "public/index.php"
    "bootstrap/app.php"
)

missing_files=()
for file in "${essential_files[@]}"; do
    if [ ! -f "$NTOOL_DIR/$file" ]; then
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -eq 0 ]; then
    log "✅ All essential files are present"
else
    warning "Missing files: ${missing_files[*]}"
fi

# Check directory structure
essential_dirs=(
    "app"
    "config"
    "database"
    "public"
    "resources"
    "routes"
    "storage"
    "bootstrap"
)

missing_dirs=()
for dir in "${essential_dirs[@]}"; do
    if [ ! -d "$NTOOL_DIR/$dir" ]; then
        missing_dirs+=("$dir")
    fi
done

if [ ${#missing_dirs[@]} -eq 0 ]; then
    log "✅ All essential directories are present"
else
    warning "Missing directories: ${missing_dirs[*]}"
fi

# Display project structure
log "Project structure created in $NTOOL_DIR:"
echo "$(tree -L 2 $NTOOL_DIR 2>/dev/null || ls -la $NTOOL_DIR)"

log "✅ NTool Laravel project setup completed!"
log "You can now run the pre-deployment check: ./pre-deploy-check.sh"
