#!/bin/bash

# Master Deployment Script for NTool Platform
# This script orchestrates the complete deployment process

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Make scripts executable
make_scripts_executable() {
    log "Making deployment scripts executable..."
    
    local scripts=("pre-deploy-check.sh" "deploy.sh" "post-deploy-verify.sh" "rollback.sh")
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            chmod +x "$script"
            info "✓ $script is now executable"
        else
            error "Script not found: $script"
        fi
    done
}

# Run pre-deployment check
run_pre_check() {
    log "Running pre-deployment check..."
    
    if ./pre-deploy-check.sh; then
        log "✓ Pre-deployment check passed"
    else
        error "Pre-deployment check failed. Please fix issues before proceeding."
    fi
}

# Run main deployment
run_deployment() {
    log "Starting main deployment..."
    
    if ./deploy.sh; then
        log "✓ Main deployment completed"
    else
        error "Deployment failed. Check logs and consider running rollback."
    fi
}

# Run post-deployment verification
run_verification() {
    log "Running post-deployment verification..."
    
    if ./post-deploy-verify.sh; then
        log "✓ Post-deployment verification passed"
    else
        warning "Post-deployment verification found issues. Review the output."
        
        read -p "Do you want to continue anyway? (y/N): " continue_anyway
        if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
            error "Deployment verification failed. Consider running rollback."
        fi
    fi
}

# Display final instructions
show_final_instructions() {
    log "Deployment process completed!"
    
    echo
    echo "=================================="
    echo "🎉 NTOOL PLATFORM DEPLOYED!"
    echo "=================================="
    echo
    echo "Your NTool Platform is now live at:"
    echo "• HTTP:  http://besthammer.club"
    echo "• HTTPS: https://besthammer.club"
    echo
    echo "Admin Access:"
    echo "• Create admin user: php artisan make:admin"
    echo "• Admin panel: https://besthammer.club/admin"
    echo
    echo "Important Files:"
    echo "• Configuration: /var/www/html/.env"
    echo "• Logs: /var/www/html/storage/logs/"
    echo "• Backups: /var/backups/website/"
    echo
    echo "Useful Commands:"
    echo "• View logs: tail -f /var/www/html/storage/logs/laravel.log"
    echo "• Clear cache: cd /var/www/html && php artisan cache:clear"
    echo "• Run rollback: ./rollback.sh"
    echo "• Check status: ./post-deploy-verify.sh"
    echo
    echo "Next Steps:"
    echo "1. Test all calculator functions"
    echo "2. Configure email settings in .env"
    echo "3. Set up SSL certificate if not already done"
    echo "4. Configure monitoring and alerts"
    echo "5. Set up regular backups"
    echo "6. Review security settings"
    echo
    echo "Support:"
    echo "• Documentation: Check the README.md file"
    echo "• Logs: Monitor /var/www/html/storage/logs/"
    echo "• Rollback: Use ./rollback.sh if issues occur"
    echo
}

# Main function
main() {
    echo
    echo "=================================="
    echo "NTOOL PLATFORM DEPLOYMENT MASTER"
    echo "=================================="
    echo "This script will deploy NTool Platform to your server"
    echo "It will replace any existing website files"
    echo
    
    warning "IMPORTANT: This will:"
    warning "1. Backup existing website and database"
    warning "2. Remove old website files"
    warning "3. Deploy new NTool Platform"
    warning "4. Configure environment and services"
    echo
    
    read -p "Do you want to proceed with the deployment? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        info "Deployment cancelled by user"
        exit 0
    fi
    
    echo
    log "Starting NTool Platform deployment process..."
    
    # Step 1: Make scripts executable
    make_scripts_executable
    
    # Step 2: Pre-deployment check
    run_pre_check
    
    # Step 3: Main deployment
    run_deployment
    
    # Step 4: Post-deployment verification
    run_verification
    
    # Step 5: Show final instructions
    show_final_instructions
    
    log "🚀 Deployment process completed successfully!"
}

# Handle script interruption
trap 'error "Deployment interrupted! Check system state and consider running rollback if needed."' INT TERM

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root for security reasons"
fi

# Check if we're in the right directory
if [ ! -f "deploy.sh" ] || [ ! -f "pre-deploy-check.sh" ]; then
    error "Deployment scripts not found. Please run this script from the directory containing all deployment scripts."
fi

main "$@"
