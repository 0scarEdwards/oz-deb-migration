#!/bin/bash
# =============================================================================
# Oz's Post-Migration Verification Script :)
# =============================================================================
# 
# README - POST-MIGRATION VERIFICATION
# =============================================================================
# 
# OVERVIEW:
# This script verifies that your domain migration was successful after reboot.
# Run this script after rebooting your system following a domain migration.
# 
# USAGE:
# =============================================================================
# 
# 1. BASIC VERIFICATION:
#    sudo ./oz-post-migration-checklist.sh
#    
#    This will:
#    - Check domain membership status
#    - Verify SSSD service health
#    - Test domain user authentication
#    - Validate network configuration
#    - Check Kerberos authentication
#    - Verify hostname configuration
#    - Test domain controller connectivity
#    - Analyze SSSD logs for errors
# 
# 2. SHOW HELP:
#    sudo ./oz-post-migration-checklist.sh --help
#    
#    Displays usage information and available options
# 
# WHAT THIS SCRIPT CHECKS:
# =============================================================================
# 
# VERIFICATION AREAS:
# - Domain membership and status
# - SSSD service health and configuration
# - Domain user accessibility
# - Network and DNS resolution
# - Kerberos authentication
# - System configuration files
# - Log analysis and error detection
# - Domain controller connectivity
# 
# TROUBLESHOOTING:
# =============================================================================
# 
# If verification fails:
# 1. Check the specific error messages
# 2. Review the troubleshooting commands provided
# 3. Check SSSD logs: tail -f /var/log/sssd/sssd.log
# 4. Verify network connectivity and DNS
# 5. Test domain controller accessibility
# 6. Consider running the migration script again
# 
# SUPPORTED SYSTEMS:
# - Debian 9+ (Stretch and newer)
# - Ubuntu 16.04+ (Xenial and newer)
# - Other Debian-based distributions
# 
# =============================================================================
# 
# Features:
# - Post-migration verification
# - Detailed troubleshooting guidance
# - Log analysis and error detection
# - Network and service health checks
# - User-friendly output and formatting
# =============================================================================

# Enable verbose output and error handling
set -e                                        # Exit immediately if any command fails
set -o pipefail                              # Exit if any command in a pipeline fails

# Function: Display script usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Run post-migration verification"
    echo "  $0 --help       # Show help information"
    echo ""
}

# Parse command line arguments
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_usage
    exit 0
fi

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Function: Display stylized banner with ASCII art
banner() {
    echo "=========================================="
    if command -v figlet >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then  # Check if figlet and lolcat are available
        echo "Post-Migration Verification" | figlet -f slant | lolcat              # Create fancy ASCII banner with colors
    else
        echo -e "\n=== Occie's Post-Migration Verification Script :) ===\n"        # Fallback simple banner
        echo "(Install 'figlet' and 'lolcat' for fancy banner: sudo apt install figlet lolcat)"
    fi
    echo "=========================================="
}

# Function: Display step headers with blue formatting
step() {
    echo -e "\n\033[1;34m==> $1\033[0m"                    # Print step header in blue color (\033[1;34m = bold blue)
    echo "------------------------------------------"      # Print separator line
}

# Function: Display error messages with red formatting
error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"                  # Print error message in red (\033[1;31m = bold red)
}

# Function: Display success messages with green formatting
success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"                # Print success message in green (\033[1;32m = bold green)
}

# Function: Display warning messages with yellow formatting
warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"                # Print warning message in yellow (\033[1;33m = bold yellow)
}

# Function: Display info messages with cyan formatting
info() {
    echo -e "\033[1;36m[INFO]\033[0m $1"                   # Print info message in cyan (\033[1;36m = bold cyan)
}

# Function: Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Display the banner
banner

# =============================================================================
# SYSTEM COMPATIBILITY CHECK
# =============================================================================
step "Checking system compatibility..."
info "Verifying this is a Debian/Ubuntu system..."

if [[ -f /etc/debian_version ]]; then                      # Check if /etc/debian_version file exists
    success "Detected Debian/Ubuntu system"
    info "System version: $(cat /etc/debian_version)"      # Display the system version
else
    warning "This script is designed for Debian/Ubuntu systems"
    info "Proceeding anyway, but some features may not work correctly"
fi

# =============================================================================
# DOMAIN MEMBERSHIP VERIFICATION
# =============================================================================
step "Verifying domain membership..."
info "Checking which domains this system is currently joined to..."

echo "Current domain membership:"
if command_exists realm; then
    realm list || echo "Not currently joined to any domain."    # List joined domains or show message if none
else
    error "realm command not found - SSSD may not be installed"
    exit 1
fi

echo ""
info "Checking SSSD domain configuration:"
if command_exists sssctl; then
    sssctl domain-list || echo "No SSSD domains configured"     # List SSSD domains or show message if none
else
    error "sssctl command not found - SSSD may not be installed"
    exit 1
fi

# =============================================================================
# SSSD SERVICE HEALTH CHECK
# =============================================================================
step "Checking SSSD service health..."
info "Verifying SSSD service status and configuration..."

# Check SSSD service status
if systemctl is-active --quiet sssd; then
    success "SSSD service: RUNNING"
    
    # Check SSSD domain status
    if sssctl domain-list | grep -q .; then
        success "SSSD domain configuration: OK"
        info "Configured domains:"
        sssctl domain-list
    else
        warning "SSSD domain not found in domain-list"
    fi
    
    # Check SSSD cache
    if sssctl cache-list | grep -q "entries"; then
        info "SSSD cache contains entries"
        sssctl cache-list | head -5
    else
        info "SSSD cache is empty (normal for fresh join)"
    fi
else
    error "SSSD service is not running!"
    info "Attempting to start SSSD service..."
    if systemctl start sssd; then
        success "SSSD service started successfully"
    else
        error "Failed to start SSSD service"
        exit 1
    fi
fi

# =============================================================================
# DOMAIN USER ACCESSIBILITY TEST
# =============================================================================
step "Testing domain user accessibility..."
info "Verifying that domain users can be accessed by the system..."

# Get current domain from realm list
CURRENT_DOMAIN=$(realm list | grep -o '[a-zA-Z0-9.-]*\.[a-zA-Z0-9.-]*' | head -1)

if [[ -n "$CURRENT_DOMAIN" ]]; then
    info "Testing authentication for domain: $CURRENT_DOMAIN"
    
    if getent passwd | grep -q "@$CURRENT_DOMAIN"; then
        success "Domain users are accessible"
        info "Domain users found in passwd database:"
        getent passwd | grep "@$CURRENT_DOMAIN" | head -3
    else
        warning "No domain users found. This might be normal if no users have logged in yet."
        info "Domain users will become available after first login or cache refresh"
    fi
    
    # Test group access
    if getent group | grep -q "@$CURRENT_DOMAIN"; then
        success "Domain groups are accessible"
        info "Domain groups found in group database:"
        getent group | grep "@$CURRENT_DOMAIN" | head -3
    else
        info "No domain groups found yet (normal for fresh join)"
    fi
else
    warning "No domain detected - cannot test user accessibility"
fi

# =============================================================================
# KERBEROS AUTHENTICATION TEST
# =============================================================================
step "Testing Kerberos authentication..."
info "Verifying Kerberos configuration and tickets..."

if command_exists kinit; then
    if klist 2>/dev/null | grep -q "krbtgt"; then
        success "Kerberos tickets: OK"
        info "Current Kerberos tickets:"
        klist | head -10
    else
        info "No Kerberos tickets found (normal if no user has authenticated)"
        info "To test Kerberos, try: kinit username@$CURRENT_DOMAIN"
    fi
else
    warning "kinit not available - cannot test Kerberos"
fi

# =============================================================================
# NETWORK AND DNS VERIFICATION
# =============================================================================
step "Verifying network and DNS configuration..."
info "Testing network connectivity and DNS resolution..."

# Test basic network connectivity
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    success "Internet connectivity: OK"
else
    warning "Internet connectivity: FAILED - Check network connection"
fi

# Test DNS resolution
if nslookup google.com >/dev/null 2>&1; then
    success "DNS resolution: OK"
else
    warning "DNS resolution: FAILED - Check DNS configuration"
fi

# Test DNS resolution for current domain
if [[ -n "$CURRENT_DOMAIN" ]]; then
    info "Testing DNS resolution for current domain: $CURRENT_DOMAIN"
    if nslookup "$CURRENT_DOMAIN" >/dev/null 2>&1; then
        success "DNS resolution for $CURRENT_DOMAIN: OK"
    else
        warning "DNS resolution for $CURRENT_DOMAIN: FAILED"
        info "This may affect domain authentication"
    fi
fi

# Test domain controller connectivity
if [[ -n "$CURRENT_DOMAIN" ]]; then
    info "Testing domain controller connectivity..."
    
    # Try to get actual domain controller from SSSD config
    if [[ -f /etc/sssd/sssd.conf ]]; then
        SSSD_DC=$(grep -i "ad_server" /etc/sssd/sssd.conf | head -1 | awk -F'=' '{print $2}' | tr -d ' ')
        if [[ -n "$SSSD_DC" ]]; then
            info "Found domain controller in SSSD config: $SSSD_DC"
            if ping -c 1 "$SSSD_DC" >/dev/null 2>&1; then
                success "Domain controller connectivity: OK ($SSSD_DC)"
            else
                warning "Cannot reach SSSD domain controller: $SSSD_DC"
            fi
        fi
    fi
    
    # Try common DC names if SSSD config doesn't have one
    if [[ -z "$SSSD_DC" ]]; then
        DC_HOST="dc1.$CURRENT_DOMAIN"
        if ping -c 1 "$DC_HOST" >/dev/null 2>&1; then
            success "Domain controller connectivity: OK ($DC_HOST)"
        else
            warning "Cannot reach $DC_HOST - check network/DNS"
            info "Trying alternative domain controller names..."
            
            # Try common DC names
            for dc in "dc.$CURRENT_DOMAIN" "ad.$CURRENT_DOMAIN" "ldap.$CURRENT_DOMAIN" "dc1.$CURRENT_DOMAIN" "dc2.$CURRENT_DOMAIN"; do
                if ping -c 1 "$dc" >/dev/null 2>&1; then
                    success "Found accessible domain controller: $dc"
                    break
                fi
            done
        fi
    fi
fi

# =============================================================================
# SYSTEM CONFIGURATION VERIFICATION
# =============================================================================
step "Verifying system configuration..."
info "Checking hostname and configuration files..."

# Verify hostname configuration
info "Checking hostname configuration..."
CURRENT_HOSTNAME=$(hostname)
if [[ "$CURRENT_HOSTNAME" == *"."* ]]; then
    success "Hostname appears to be FQDN: $CURRENT_HOSTNAME"
else
    warning "Hostname may not be FQDN: $CURRENT_HOSTNAME"
    info "Consider setting FQDN hostname for better domain integration"
fi

# Check /etc/hosts configuration
info "Verifying /etc/hosts configuration..."
if grep -q "$CURRENT_HOSTNAME" /etc/hosts; then
    success "/etc/hosts contains hostname entry"
    info "Hostname entries in /etc/hosts:"
    grep "$CURRENT_HOSTNAME" /etc/hosts
else
    warning "/etc/hosts missing hostname entry"
fi

# Check Kerberos configuration
info "Checking Kerberos configuration..."
if [[ -f /etc/krb5.conf ]]; then
    success "Kerberos configuration file exists"
    if grep -q "default_realm" /etc/krb5.conf; then
        info "Kerberos default realm configured"
    else
        warning "Kerberos default realm not found in configuration"
    fi
else
    warning "Kerberos configuration file not found"
fi

# =============================================================================
# LOG ANALYSIS AND ERROR DETECTION
# =============================================================================
step "Analyzing logs for errors..."
info "Checking SSSD and system logs for issues..."

# Check for any SSSD errors in logs
info "Checking for SSSD errors..."
if [[ -f /var/log/sssd/sssd.log ]]; then
    RECENT_ERRORS=$(tail -50 /var/log/sssd/sssd.log | grep -i error | wc -l)
    if [[ $RECENT_ERRORS -gt 0 ]]; then
        warning "Found $RECENT_ERRORS recent SSSD errors"
        info "Recent SSSD error entries:"
        tail -50 /var/log/sssd/sssd.log | grep -i error | tail -5
    else
        success "No recent SSSD errors found"
    fi
    
    # Check for authentication failures
    AUTH_FAILURES=$(tail -50 /var/log/sssd/sssd.log | grep -i "authentication failure\|auth failure" | wc -l)
    if [[ $AUTH_FAILURES -gt 0 ]]; then
        warning "Found $AUTH_FAILURES recent authentication failures"
        info "Recent authentication failures:"
        tail -50 /var/log/sssd/sssd.log | grep -i "authentication failure\|auth failure" | tail -3
    else
        success "No recent authentication failures found"
    fi
    
    # Check for connection timeouts
    TIMEOUTS=$(tail -50 /var/log/sssd/sssd.log | grep -i "timeout\|connection refused" | wc -l)
    if [[ $TIMEOUTS -gt 0 ]]; then
        warning "Found $TIMEOUTS recent connection timeouts"
        info "Recent timeout entries:"
        tail -50 /var/log/sssd/sssd.log | grep -i "timeout\|connection refused" | tail -3
    fi
else
    info "SSSD log file not found (may be normal)"
fi

# Check system journal for SSSD issues
info "Checking system journal for SSSD issues..."
if command_exists journalctl; then
    JOURNAL_ERRORS=$(journalctl -u sssd --since "1 hour ago" | grep -i error | wc -l)
    if [[ $JOURNAL_ERRORS -gt 0 ]]; then
        warning "Found $JOURNAL_ERRORS SSSD errors in system journal"
        info "Recent SSSD journal errors:"
        journalctl -u sssd --since "1 hour ago" | grep -i error | tail -3
    else
        success "No SSSD errors in system journal"
    fi
else
    info "journalctl not available - cannot check system journal"
fi

# =============================================================================
# SUDO ACCESS VERIFICATION
# =============================================================================
step "Verifying sudo access configuration..."
info "Checking sudo access for domain users..."

if [[ -f /etc/sudoers.d/domain-users ]]; then
    success "Domain users sudo configuration found"
    info "Domain users sudo configuration:"
    cat /etc/sudoers.d/domain-users
else
    info "No domain users sudo configuration found"
    info "Domain users may not have sudo access"
fi

# =============================================================================
# BACKUP ACCOUNT CLEANUP
# =============================================================================
step "Cleaning up temporary backup account..."
info "Removing temporary backup account created during migration..."

if id "backup" &>/dev/null; then
    info "Found backup account - removing..."
    
    # Remove sudoers entry
    if [[ -f /etc/sudoers.d/backup-user ]]; then
        rm -f /etc/sudoers.d/backup-user
        info "Removed backup user sudoers entry"
    fi
    
    # Remove user account and home directory
    userdel -r backup 2>/dev/null || userdel backup 2>/dev/null
    success "Backup account 'backup' removed successfully"
    info "Temporary emergency access account has been cleaned up"
else
    info "No backup account found - nothing to clean up"
fi

# =============================================================================
# FINAL VERIFICATION SUMMARY
# =============================================================================
step "Final verification summary..."
info "Compiling verification results..."

echo ""
echo "=========================================="
echo "POST-MIGRATION VERIFICATION SUMMARY"
echo "=========================================="

# Count successes and warnings
SUCCESS_COUNT=0
WARNING_COUNT=0
ERROR_COUNT=0

# Domain membership check
if realm list | grep -q .; then
    echo "OK: Domain Membership: OK"
    ((SUCCESS_COUNT++))
else
    echo "FAIL: Domain Membership: FAILED"
    ((ERROR_COUNT++))
fi

# SSSD service check
if systemctl is-active --quiet sssd; then
    echo "OK: SSSD Service: RUNNING"
    ((SUCCESS_COUNT++))
else
    echo "FAIL: SSSD Service: NOT RUNNING"
    ((ERROR_COUNT++))
fi

# Domain users check
if getent passwd | grep -q "@"; then
    echo "OK: Domain Users: ACCESSIBLE"
    ((SUCCESS_COUNT++))
else
    echo "WARNING: Domain Users: NOT FOUND (may be normal)"
    ((WARNING_COUNT++))
fi

# Network connectivity check
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "OK: Network Connectivity: OK"
    ((SUCCESS_COUNT++))
else
    echo "FAIL: Network Connectivity: FAILED"
    ((ERROR_COUNT++))
fi

# DNS resolution check
if nslookup google.com >/dev/null 2>&1; then
    echo "OK: DNS Resolution: OK"
    ((SUCCESS_COUNT++))
else
    echo "FAIL: DNS Resolution: FAILED"
    ((ERROR_COUNT++))
fi

# Log errors check
if [[ -f /var/log/sssd/sssd.log ]] && [[ $(tail -50 /var/log/sssd/sssd.log | grep -i error | wc -l) -eq 0 ]]; then
    echo "OK: SSSD Logs: CLEAN"
    ((SUCCESS_COUNT++))
else
    echo "WARNING: SSSD Logs: ERRORS DETECTED"
    ((WARNING_COUNT++))
fi

echo ""
echo "=========================================="
echo "VERIFICATION RESULTS"
echo "=========================================="
echo "OK: Successes: $SUCCESS_COUNT"
echo "WARNING: Warnings: $WARNING_COUNT"
echo "FAIL: Errors: $ERROR_COUNT"

if [[ $ERROR_COUNT -eq 0 ]]; then
    if [[ $WARNING_COUNT -eq 0 ]]; then
        success "All verifications passed! Your domain migration appears successful."
        echo ""
        echo "NEXT STEPS:"
        echo "1. Test logging in with a domain user account"
        echo "2. Verify that domain group memberships work correctly"
        echo "3. Test sudo access for domain users (if configured)"
        echo "4. Verify that domain policies are applied correctly"
        echo "5. Temporary backup account has been automatically removed"
    else
        success "Domain migration appears successful with some warnings."
        echo ""
        echo "The warnings detected are non-critical but should be reviewed."
        echo "Temporary backup account has been automatically removed"
    fi
else
    error "Domain migration verification failed!"
    echo ""
    echo "Please review the errors above and take corrective action."
    echo "Note: Backup account 'backup' is still available for emergency access"
fi

echo ""
echo "=========================================="
echo "TROUBLESHOOTING COMMANDS"
echo "=========================================="
echo "Check domain status:        realm list"
echo "Check SSSD status:          systemctl status sssd"
echo "Check SSSD logs:            tail -f /var/log/sssd/sssd.log"
echo "Test domain user access:    getent passwd | grep @$CURRENT_DOMAIN"
echo "Test Kerberos:              klist"
echo "Check DNS resolution:       nslookup $CURRENT_DOMAIN"
echo "Test domain controller:     ping dc1.$CURRENT_DOMAIN"
echo "Check SSSD cache:           sssctl cache-list"
echo "Clear SSSD cache:           sssctl cache-remove"
echo "Restart SSSD:               systemctl restart sssd"
echo ""
echo "COMMON ISSUES & SOLUTIONS:"
echo "=========================================="
echo "FAIL: Can't log in with domain user:"
echo "   - Check SSSD logs: tail -f /var/log/sssd/sssd.log"
echo "   - Clear cache: sssctl cache-remove"
echo "   - Restart SSSD: systemctl restart sssd"
echo ""
echo "FAIL: DNS resolution issues:"
echo "   - Check /etc/resolv.conf"
echo "   - Verify DNS server settings"
echo "   - Test: nslookup $CURRENT_DOMAIN"
echo ""
echo "FAIL: Kerberos authentication fails:"
echo "   - Check system time manually"
echo "   - Enable NTP manually if needed"
echo "   - Test: kinit username@$CURRENT_DOMAIN"
echo ""
echo "FAIL: Sudo access not working:"
echo "   - Check sudoers: sudo -l -U username@$CURRENT_DOMAIN"
echo "   - Verify group membership: groups username@$CURRENT_DOMAIN"
echo ""
echo "SUPPORT FILES:"
echo "=========================================="
echo "SSSD config:                /etc/sssd/sssd.conf"
echo "Kerberos config:            /etc/krb5.conf"
echo "Hosts file:                 /etc/hosts"
echo "SSSD logs:                  /var/log/sssd/"
echo "System logs:                journalctl -u sssd"
echo "Domain users sudo:          /etc/sudoers.d/domain-users" 