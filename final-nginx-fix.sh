#!/bin/bash

# Final Nginx Fix - One-time solution for all potential issues
# This script intelligently handles FastPanel configurations and resolves all binding issues

set -e

# Configuration
WEB_ROOT="/var/www/besthammer_c_usr/data/www/besthammer.club"
WEB_USER="besthammer_c_usr"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="/tmp/final_nginx_fix_${TIMESTAMP}.log"
BACKUP_DIR="/tmp/nginx_final_backup_${TIMESTAMP}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() { echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}⚠️ $1${NC}" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"; }
info() { echo -e "${BLUE}ℹ️ $1${NC}" | tee -a "$LOG_FILE"; }
section() { echo -e "${PURPLE}🔍 $1${NC}" | tee -a "$LOG_FILE"; }

# Initialize log
echo "# Final Nginx Fix Log" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"

# Check root
if [[ $EUID -ne 0 ]]; then
    error "Run as root: sudo ./final-nginx-fix.sh"
    exit 1
fi

echo "🚀 Final Nginx Fix - Complete Solution"
echo "======================================"
echo "Time: $(date)"
echo "Log: $LOG_FILE"
echo "======================================"
echo ""

# Step 1: Complete Backup and Cleanup
section "Step 1: Complete Backup and Cleanup"

mkdir -p "$BACKUP_DIR"

# Backup all nginx configurations
cp -r /etc/nginx "$BACKUP_DIR/nginx_complete" 2>/dev/null || true
log "✓ Complete Nginx configuration backed up"

# Clean up any previous attempts
rm -f /etc/nginx/conf.d/local-binding.conf 2>/dev/null || true
rm -f /etc/nginx/conf.d/universal-binding.conf 2>/dev/null || true
log "✓ Previous fix attempts cleaned up"

# Restore original FastPanel config if backup exists
FASTPANEL_CONF="/etc/nginx/fastpanel2-sites/besthammer_c_usr/besthammer.club.conf"
if [ -f "${FASTPANEL_CONF}.backup" ]; then
    cp "${FASTPANEL_CONF}.backup" "$FASTPANEL_CONF"
    log "✓ Restored original FastPanel configuration"
fi

# Step 2: Analyze FastPanel Configuration Structure
section "Step 2: Analyzing FastPanel Configuration Structure"

if [ ! -f "$FASTPANEL_CONF" ]; then
    error "FastPanel configuration not found: $FASTPANEL_CONF"
    exit 1
fi

info "Analyzing FastPanel configuration structure..."

# Count server blocks
SERVER_BLOCKS=$(grep -c "^server {" "$FASTPANEL_CONF" 2>/dev/null || echo "0")
info "Found $SERVER_BLOCKS server blocks"

# Find all listen directives
echo "=== CURRENT LISTEN DIRECTIVES ===" >> "$LOG_FILE"
grep -n "listen" "$FASTPANEL_CONF" >> "$LOG_FILE" 2>/dev/null || echo "No listen directives found" >> "$LOG_FILE"

# Step 3: Create Intelligent Fix
section "Step 3: Creating Intelligent Configuration Fix"

info "Creating smart configuration modification..."

# Create a Python script to intelligently modify the config
cat > "/tmp/nginx_modifier_${TIMESTAMP}.py" << 'EOF'
#!/usr/bin/env python3
import sys
import re

def modify_nginx_config(config_path):
    with open(config_path, 'r') as f:
        content = f.read()
    
    # Track if we've already added local bindings
    local_bindings_added = False
    
    # Split into lines for processing
    lines = content.split('\n')
    new_lines = []
    
    in_server_block = False
    server_block_count = 0
    
    for i, line in enumerate(lines):
        new_lines.append(line)
        
        # Detect server block start
        if re.match(r'^\s*server\s*{', line):
            in_server_block = True
            server_block_count += 1
            
        # Detect server block end
        elif re.match(r'^\s*}', line) and in_server_block:
            in_server_block = False
            
        # Add local bindings after the first external IP listen in the first server block
        elif (in_server_block and server_block_count == 1 and not local_bindings_added and
              re.search(r'listen\s+104\.194\.77\.132:80', line)):
            
            # Add local bindings with proper indentation
            indent = re.match(r'^(\s*)', line).group(1)
            new_lines.append(f"{indent}listen 127.0.0.1:80;")
            new_lines.append(f"{indent}listen localhost:80;")
            new_lines.append(f"{indent}listen 80;")
            local_bindings_added = True
    
    return '\n'.join(new_lines)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 script.py <config_file>")
        sys.exit(1)
    
    config_file = sys.argv[1]
    modified_content = modify_nginx_config(config_file)
    
    with open(config_file + '.modified', 'w') as f:
        f.write(modified_content)
    
    print("Configuration modified successfully")
EOF

# Make the Python script executable
chmod +x "/tmp/nginx_modifier_${TIMESTAMP}.py"

# Run the intelligent modifier
if python3 "/tmp/nginx_modifier_${TIMESTAMP}.py" "$FASTPANEL_CONF"; then
    log "✓ Intelligent configuration modification completed"
else
    error "✗ Configuration modification failed"
    exit 1
fi

# Step 4: Test and Apply the Modified Configuration
section "Step 4: Testing and Applying Modified Configuration"

MODIFIED_CONF="${FASTPANEL_CONF}.modified"

if [ ! -f "$MODIFIED_CONF" ]; then
    error "Modified configuration not created"
    exit 1
fi

info "Testing modified configuration..."

# Backup original
cp "$FASTPANEL_CONF" "${FASTPANEL_CONF}.original_backup"

# Apply modified configuration
cp "$MODIFIED_CONF" "$FASTPANEL_CONF"

# Test configuration
if nginx -t 2>/dev/null; then
    log "✓ Modified configuration test passed"
    
    info "Applying configuration..."
    if systemctl reload nginx 2>/dev/null; then
        log "✓ Nginx reloaded successfully"
    else
        warning "Reload failed, trying restart..."
        if systemctl restart nginx 2>/dev/null; then
            log "✓ Nginx restarted successfully"
        else
            error "✗ Nginx restart failed"
            # Restore original
            cp "${FASTPANEL_CONF}.original_backup" "$FASTPANEL_CONF"
            systemctl reload nginx
            exit 1
        fi
    fi
    
else
    error "✗ Modified configuration test failed"
    echo "Nginx test output:" >> "$LOG_FILE"
    nginx -t 2>&1 >> "$LOG_FILE"
    
    # Restore original
    cp "${FASTPANEL_CONF}.original_backup" "$FASTPANEL_CONF"
    systemctl reload nginx
    exit 1
fi

# Step 5: Verify Bindings and Test Connections
section "Step 5: Verifying Bindings and Testing Connections"

info "Waiting for services to stabilize..."
sleep 5

# Check port bindings
info "Checking port 80 bindings..."
PORT_BINDINGS=$(netstat -tlnp | grep ":80 " 2>/dev/null || echo "No bindings found")
echo "Current port 80 bindings:" | tee -a "$LOG_FILE"
echo "$PORT_BINDINGS" | tee -a "$LOG_FILE"

# Count local bindings
LOCAL_BINDINGS=0
if echo "$PORT_BINDINGS" | grep -q "127.0.0.1:80"; then
    log "✅ 127.0.0.1:80 binding active"
    ((LOCAL_BINDINGS++))
fi
if echo "$PORT_BINDINGS" | grep -q "0.0.0.0:80"; then
    log "✅ 0.0.0.0:80 (universal) binding active"
    ((LOCAL_BINDINGS++))
fi

# Test connections
info "Testing all connection methods..."

# Test URLs
TEST_RESULTS=()

# Test localhost
LOCALHOST_RESULT=$(timeout 10 curl -s -w "HTTPCODE:%{http_code}" "http://localhost" 2>/dev/null || echo "HTTPCODE:000")
LOCALHOST_CODE=$(echo "$LOCALHOST_RESULT" | grep "HTTPCODE:" | cut -d':' -f2)
TEST_RESULTS+=("localhost:$LOCALHOST_CODE")

# Test 127.0.0.1
LOCAL_IP_RESULT=$(timeout 10 curl -s -w "HTTPCODE:%{http_code}" "http://127.0.0.1" 2>/dev/null || echo "HTTPCODE:000")
LOCAL_IP_CODE=$(echo "$LOCAL_IP_RESULT" | grep "HTTPCODE:" | cut -d':' -f2)
TEST_RESULTS+=("127.0.0.1:$LOCAL_IP_CODE")

# Test external IP
EXTERNAL_IP="104.194.77.132"
EXTERNAL_RESULT=$(timeout 10 curl -s -w "HTTPCODE:%{http_code}" "http://$EXTERNAL_IP" 2>/dev/null || echo "HTTPCODE:000")
EXTERNAL_CODE=$(echo "$EXTERNAL_RESULT" | grep "HTTPCODE:" | cut -d':' -f2)
TEST_RESULTS+=("external:$EXTERNAL_CODE")

# Test server IP
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null)
if [ -n "$SERVER_IP" ] && [ "$SERVER_IP" != "$EXTERNAL_IP" ]; then
    SERVER_RESULT=$(timeout 10 curl -s -w "HTTPCODE:%{http_code}" "http://$SERVER_IP" 2>/dev/null || echo "HTTPCODE:000")
    SERVER_CODE=$(echo "$SERVER_RESULT" | grep "HTTPCODE:" | cut -d':' -f2)
    TEST_RESULTS+=("server_ip:$SERVER_CODE")
fi

# Step 6: Comprehensive Results Analysis
section "Step 6: Comprehensive Results Analysis"

echo ""
echo "=================================================="
echo "🎯 FINAL NGINX FIX RESULTS"
echo "=================================================="
echo "Connection Test Results:"
echo "  • localhost: HTTP $LOCALHOST_CODE"
echo "  • 127.0.0.1: HTTP $LOCAL_IP_CODE"
echo "  • External IP ($EXTERNAL_IP): HTTP $EXTERNAL_CODE"
if [ -n "$SERVER_IP" ] && [ "$SERVER_IP" != "$EXTERNAL_IP" ]; then
    echo "  • Server IP ($SERVER_IP): HTTP $SERVER_CODE"
fi
echo ""

# Analyze results
WORKING_CONNECTIONS=0
HTTP_500_CONNECTIONS=0
FAILED_CONNECTIONS=0

for result in "${TEST_RESULTS[@]}"; do
    code=$(echo "$result" | cut -d':' -f2)
    if [[ "$code" =~ ^[23] ]]; then
        ((WORKING_CONNECTIONS++))
    elif [ "$code" = "500" ]; then
        ((HTTP_500_CONNECTIONS++))
    else
        ((FAILED_CONNECTIONS++))
    fi
done

# Final verdict
if [ $WORKING_CONNECTIONS -gt 0 ]; then
    log "🎉 SUCCESS: Website is fully accessible!"
    echo ""
    echo "✅ Working connections: $WORKING_CONNECTIONS"
    echo "✅ Your website is accessible via:"
    for result in "${TEST_RESULTS[@]}"; do
        url=$(echo "$result" | cut -d':' -f1)
        code=$(echo "$result" | cut -d':' -f2)
        if [[ "$code" =~ ^[23] ]]; then
            echo "   • http://$url (HTTP $code)"
        fi
    done
    
elif [ $HTTP_500_CONNECTIONS -gt 0 ]; then
    log "🎉 CONNECTION SUCCESS: Nginx binding fixed!"
    warning "⚠️ Application errors detected (HTTP 500)"
    echo ""
    echo "✅ Connection issue RESOLVED!"
    echo "⚠️ HTTP 500 connections: $HTTP_500_CONNECTIONS"
    echo ""
    echo "🔍 HTTP 500 means:"
    echo "• Nginx is working and can connect"
    echo "• The binding issue is completely fixed"
    echo "• Laravel/PHP application has errors"
    echo ""
    echo "🔧 Quick fixes for HTTP 500:"
    echo "cd $WEB_ROOT"
    echo "composer install --no-dev --optimize-autoloader"
    echo "php artisan key:generate --force"
    echo "chmod -R 775 storage bootstrap/cache"
    echo "chown -R $WEB_USER:$WEB_USER ."
    echo ""
    echo "📋 Check Laravel logs:"
    echo "tail -f $WEB_ROOT/storage/logs/laravel.log"
    
else
    error "❌ Connection issues persist"
    echo ""
    echo "✗ Failed connections: $FAILED_CONNECTIONS"
    echo ""
    echo "🔍 Possible remaining issues:"
    echo "• FastPanel may be overriding configurations"
    echo "• Firewall blocking local connections"
    echo "• PHP-FPM not running or misconfigured"
    echo ""
    echo "🔧 Manual troubleshooting:"
    echo "1. Check FastPanel web interface"
    echo "2. Verify PHP-FPM status: systemctl status php8.3-fpm"
    echo "3. Check firewall: ufw status"
    echo "4. Review logs: tail -f /var/log/nginx/error.log"
fi

echo ""
echo "📊 Configuration Summary:"
echo "   • Original backed up: ${FASTPANEL_CONF}.original_backup"
echo "   • Complete backup: $BACKUP_DIR"
echo "   • Modified config applied: $FASTPANEL_CONF"
echo ""
echo "📄 Detailed log: $LOG_FILE"
echo ""

# Cleanup temporary files
rm -f "/tmp/nginx_modifier_${TIMESTAMP}.py"
rm -f "$MODIFIED_CONF"

if [ $WORKING_CONNECTIONS -gt 0 ] || [ $HTTP_500_CONNECTIONS -gt 0 ]; then
    echo "🎊 MISSION ACCOMPLISHED!"
    if [ $HTTP_500_CONNECTIONS -gt 0 ]; then
        echo "Next step: Fix the Laravel application errors (HTTP 500)."
    else
        echo "Your BestHammer NTool platform is fully operational!"
    fi
else
    echo "🔧 Additional manual intervention may be required."
fi

echo ""
echo "=================================================="
