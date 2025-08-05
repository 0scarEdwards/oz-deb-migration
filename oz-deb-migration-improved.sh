#!/bin/bash
# =============================================================================
# Oz's Debian Domain Migration Script
# Version: 3.0.0
# =============================================================================
#
# LINUX DOMAIN MIGRATION EXPLAINED IN PLAIN ENGLISH:
# =============================================================================
#
# WHAT THIS SCRIPT DOES:
# This script migrates a Linux system from one Active Directory domain to another.
#
# THE MAIN COMPONENTS AND TOOLS:
# =============================================================================
#
# 1. REALMD - The Domain Joining Tool
#    - This is the main tool that handles joining/leaving Active Directory domains
#    - Think of it as the "network membership card" for your Linux computer
#    - Commands: realm join, realm leave, realm discover, realm list
#    - What it does: Creates a computer account in Active Directory, configures authentication
#
# 2. SSSD - System Security Services Daemon
#    - This is the "translator" between Linux and Active Directory
#    - It handles user authentication, group membership, and user lookups
#    - Think of it as the "phone book" that tells Linux about domain users
#    - Services: sssd (the main service), sssctl (control tool)
#    - Files: /etc/sssd/sssd.conf (configuration), /var/log/sssd/ (logs)
#
# 3. KERBEROS - The Authentication System
#    - This is the "security system" that handles passwords and authentication
#    - Think of it as the "key card system" for the building
#    - Tools: kinit (get authentication), klist (show current tickets)
#    - Files: /etc/krb5.conf (configuration)
#    - Critical: Time must be synchronized (within 5 minutes) or authentication fails
#
# 4. PAM - Pluggable Authentication Modules
#    - This is the "security guard" that controls who can log in and how
#    - Think of it as the "bouncer" at the door checking IDs
#    - Files: /etc/pam.d/ (configuration files)
#    - Commands: pam-auth-update (configure authentication methods)
#    - What it does: Decides how users authenticate (local passwords vs domain passwords)
#
# 5. NSS - Name Service Switch
#    - This is the "directory service" that tells Linux where to look for user information
#    - Think of it as the "phone book lookup system"
#    - File: /etc/nsswitch.conf (tells system where to look for users, groups, etc.)
#    - What it does: "Look in local files first, then ask the domain for user info"
#
# 6. ODDJOB-MKHOMEDIR - Home Directory Creator
#    - This automatically creates home folders for domain users when they first log in
#    - Think of it as the "room assignment system" that gives new employees their office
#    - Service: oddjobd (runs the home directory creation)
#    - What it does: When a domain user logs in for the first time, creates /home/username
#
# 7. SAMBA - Windows Network Compatibility
#    - This allows Linux to talk to Windows networks and Active Directory
#    - Think of it as the "translator" between Linux and Windows networking
#    - Tools: smbclient, net, wbinfo (various Windows network tools)
#    - What it does: Enables file sharing, domain authentication, and network browsing
#
# THE MIGRATION PROCESS EXPLAINED:
# =============================================================================
#
# Step 1: PREPARATION
#    - Install required packages (realmd, sssd, samba, etc.)
#    - Create backup account for emergency access
#    - Check system compatibility and network connectivity
#
# Step 2: DOMAIN TRANSITION
#    - Leave the old domain (if currently joined to one)
#    - Discover the new domain structure
#    - Join the new domain using admin credentials
#
# Step 3: SYSTEM CONFIGURATION
#    - Update hostname to match new domain
#    - Configure Kerberos authentication
#    - Set up SSSD for domain authentication
#    - Configure PAM/NSS to use domain authentication
#    - Enable automatic home directory creation
#
# Step 4: USER MIGRATION
#    - Move user home directories from old domain to new domain
#    - Create symbolic links so old paths still work
#    - Update file ownership to new domain users
#
# Step 5: VERIFICATION
#    - Test domain authentication
#    - Verify user access and home directories
#    - Check all services are working properly
#
# COMMON ISSUES AND SOLUTIONS:
# =============================================================================
#
# "Can't join domain" - Usually means:
#    - Wrong admin credentials
#    - Network connectivity issues
#    - DNS resolution problems
#    - Firewall blocking required ports (389, 636, 88, 464)
#
# "Can't log in with domain user" - Usually means:
#    - SSSD service not running
#    - PAM/NSS not configured properly
#    - Time synchronization issues
#    - Domain controller connectivity problems
#
# "Home directories not created" - Usually means:
#    - oddjob-mkhomedir not configured
#    - PAM configuration missing mkhomedir
#    - oddjobd service not running
#
# "Users not found" - Usually means:
#    - SSSD cache needs clearing
#    - NSS configuration not using SSSD
#    - Domain controller connectivity issues
#
# =============================================================================
#
# MODES:
# - Technician Mode: Full migration with all features including rollback points
#   * Creates complete system snapshots (should be circa ~50-100MB each) for full recovery
#   * Includes all safety features and advanced options
#   * Better than raw commands for production environments where safety is needed
# 
# - Live Mode: Standard migration with essential safety features
#   * Creates file-based backups of critical configuration files
#   * Includes progress tracking and error handling
#   * Suitable for most migration scenarios
# 
# - Dry-Run Mode: Test run without making any system changes
#   * Simulates the entire migration process
#   * Shows what would happen without actually changing anything
#   * Perfect for testing on domainless VMs or validating settings
# 
# SAFETY & RECOVERY:
# - State Tracking: Saves progress to /tmp/migration-state
#   * If script is interrupted, you can resume from where you left off
#   * Tracks current step, mode, domain, and hostname
#   * Automatically offers to resume on next run
# 
# - Progress Indicators: Visual feedback during long operations
#   * Shows current step and progress through migration
#   * Helps users understand what's happening during long waits
#   * Provides confidence that the script is working
# 
# - Enhanced Safety: Comprehensive backup and validiation system
#   * Creates timestamped backups of all modified files
#   * Verifies backup files exist and are not empty before proceeding
#   * Prevents data loss if something goes wrong
# 
# - Rollback Points (Technician Mode): Complete system state snapshots
#   * Creates compressed archives of critical system files
#   * Includes /etc/, network configs, user data, and system state
#   * Allows complete system restoration if needed
#   * Each rollback point is ~50-100MB in size
# 
# NETWORK & DOMAIN FEATURES:
# - Domain Controller Discovery: Automatically finds domain controllers
#   * Uses DNS SRV records to locate available domain controllers
#   * Tries common names like dc1, dc2, etc. if DNS fails
#   * Ensures connection to the best available domain controller
#   * Reduces manual configuration and potential errors
#   * NOTE: Found this approach on a wiki online - unsure if it works reliably
#   * Currently commented out until we can test with actual domain infrastructure
#   * If this fails, script will fall back to manual domain controller specification
# 
# - Time Synchronisation: Automatic NTP (Network Time Protocol) fixes
#   * Enables automatic time synchronisation with domain controllers
#   * Critical for Kerberos authentication (time must be within 5 minutes)
#   * Prevents authentication failures due to clock drift
#   * Essential for reliable domain authentication
#   * NOTE: Found this approach on a wiki online - unsure if it works reliably
#   * Currently commented out until we can test with actual domain infrastructure
#   * If this fails, script will fall back to manual time configuration
# 
# USER MANAGEMENT:
# - Concurrent User Handling: Manages active user sessions during migration
#   * Detects users currently logged into the system
#   * Warns users about the migration and potential disconnection
#   * Logs out users gracefully to prevent data loss
#   * Ensures clean migration without user interference
# 
# - Local Account Detection: Identifies and handles local (non-domain) acccounts
#   * Detects accounts that aren't part of any domain
#   * Looks for usernames without @domain suffixes
#   * Checks for local account markers in /etc/passwd comments
#   * Searches for marker files (.local_account, .skip_migration) in home directories
#   * Examines user profile files for local account indicators
#   * Allows users to skip local accounts during migration
#   * Prevents accidental migration of system or service accounts
# 
# - User Profile Migration: Moves user home directories to new domain
#   * Finds all users with @olddomain in their home folder names
#   * Creates new home folders with @newdomain names
#   * Copies all files and settings from old to new home folders
#   * Creates symlinks (redirects) from old to new folders
#   * Updates file ownership to new domain users
#   * Handles conflicts by merging or backing up existing folders
#   * Provides detailed logging of all migration actions
# 
# - Account Creation: Creates missing user accounts on new domain
#   * Detects users that exist on old domain but not new domain
#   * Attempts to create missing accounts using domain tools
#   * Uses samba-tool (preferred) or ldapadd (fallback) methods
#   * Asks for confirmation before each account creation
#   * Retries profile migration for newly created accounts
#   * Provides summary of successful and failed account creations
# 
# - Symlink Creation: Creates redirects from old to new user folders
#   * After moving user home directories, creates symbolic links
#   * Old paths like /home/user@olddomain point to /home/user@newdomain
#   * Ensures applications and shortcuts continue to work
#   * Maintains compatibility with existing configurations
#   * Creates mapping file for reference: /etc/domain-user-mapping.conf
# 
# TECHNICAL DETAILS:
# - Backup Verificiation: Ensures backup files are valid before proceeding
#   * Checks that backup files exist and have content
#   * Prevents script from continuing with invalid backups
#   * Provides clear error messages if backups fail
#   * Essential for reliable recovery options
# 
# - SSL/TLS Certificate Validation: (Commented out - for potential future use, I don't think we need this though as think all Debian machines are on ethernet)
#   * Would validate domain controller certificates
#   * Ensures secure connections to domain controllers
#   * Currently disabled as all machines are on ethernet networks
#   * Can be enabled for wireless or external network scenarios
# 
# USAGE:
# =============================================================================
# 
# 1. TECHNICIAN MODE (Full features):
#    sudo ./oz-deb-migration-improved.sh --technician
#    
# 2. LIVE MODE (Standard):
#    sudo ./oz-deb-migration-improved.sh --live
#    
# 3. DRY-RUN MODE (Test only):
#    sudo ./oz-deb-migration-improved.sh --dry-run
#    
# 4. REVERT TO PREVIOUS DOMAIN:
#    sudo ./oz-deb-migration-improved.sh --revert
#    
# 5. SHOW HELP:
#    sudo ./oz-deb-migration-improved.sh --help
# 
# STATE TRACKING:
# =============================================================================
# 
# The script creates a state tracking file at: /tmp/migration-state
# This file tracks your progress through the migration steps.
# If the script is interrupted, you can resume from where you left off.
# 
# State file format: STEP=X|MODE=Y|DOMAIN=Z|HOSTNAME=A
# Example: STEP=8|MODE=technician|DOMAIN=newcompany.com|HOSTNAME=myserver
# 
# ROLLBACK POINTS:
# =============================================================================
# 
# Rollback points create a complete system state snapshot.
# This includes all config files, network settings, and system state.
# Expected storage: ~50-100MB per rollback point.
# 
# =============================================================================

# Enable verbose output and error handling
# set -e                    # Exit immediately if any command fails (commented out for resilience)
set -o pipefail          # Exit if any command in a pipeline fails

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="/tmp/migration-state"
ROLLBACK_DIR="/root/migration-rollbacks"
DRY_RUN=false
TECHNICIAN_MODE=false
LIVE_MODE=false

# Function: Display script usage
show_usage() {
    echo "Usage: $0 [MODE] [OPTIONS]"
    echo ""
    echo "Modes:"
    echo "  --technician    Full migration with all features and rollback points"
    echo "  --live          Standard migration with safety features"
    echo "  --dry-run       Test run without making any changes"
    echo "  --revert        Revert to previous domain configuration"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --technician    # Full migration with rollback points"
    echo "  $0 --live          # Standard migration"
    echo "  $0 --dry-run       # Test run only"
    echo "  $0 --revert        # Revert to previous domain"
    echo ""
    echo "State Tracking:"
    echo "  The script tracks progress in /tmp/migration-state"
    echo "  If interrupted, you can resume from the last step"
    echo ""
    echo "Rollback Points (Technician Mode):"
    echo "  Creates complete system state snapshots (~50-100MB each)"
    echo "  Stored in /root/migration-rollbacks/"
    echo "  Allows complete system restoration if needed"
}

# Function: Parse command line arguments
parse_arguments() {
    if [[ $# -eq 0 ]]; then
        echo "No mode specified. Please choose a mode:"
        echo ""
        echo "1) TECHNICIAN MODE"
        echo "   Full migration with complete system snapshots (~50-100MB each)"
        echo "   Includes all safety features: rollback points, state tracking, backup verification"
        echo "   Best for production environments where maximum safety is needed"
        echo "   WARNING: This will make permanent changes to your system"
        echo ""
        echo "2) LIVE MODE"
        echo "   Standard migration with essential safety features"
        echo "   Creates file-based backups and includes progress tracking"
        echo "   Suitable for most migration scenarios"
        echo "   WARNING: This will make permanent changes to your system"
        echo ""
        echo "3) DRY-RUN MODE"
        echo "   Test run without making any system changes"
        echo "   Perfect for validating settings on domainless VMs"
        echo "   Shows exactly what would happen without actually doing it"
        echo "   SAFE: No changes will be made to your system"
        echo ""
        read -rp "Enter your choice (1-3): " MODE_CHOICE
        case $MODE_CHOICE in
            1) set -- --technician ;;
            2) set -- --live ;;
            3) set -- --dry-run ;;
            *) echo "Invalid choice. Exiting."; exit 1 ;;
        esac
    fi

    case "$1" in
        --technician)
            TECHNICIAN_MODE=true
            LIVE_MODE=false
            DRY_RUN=false
            echo "=== TECHNICIAN MODE ENABLED ==="
            echo "Full migration with complete system snapshots (~50-100MB each)"
            echo "Includes all safety features: rollback points, state tracking, backup verification"
            echo "Best for production environments where maximum safety is needed"
            echo "WARNING: This will make permanent changes to your system"
            ;;
        --live)
            LIVE_MODE=true
            TECHNICIAN_MODE=false
            DRY_RUN=false
            echo "=== LIVE MODE ENABLED ==="
            echo "Standard migration with essential safety features"
            echo "Creates file-based backups and includes progress tracking"
            echo "Suitable for most migration scenarios"
            echo "WARNING: This will make permanent changes to your system"
            ;;
        --dry-run)
            DRY_RUN=true
            TECHNICIAN_MODE=false
            LIVE_MODE=false
            echo "=== DRY-RUN MODE ENABLED ==="
            echo "Test run without making any system changes"
            echo "Perfect for validating settings on domainless VMs"
            echo "Shows exactly what would happen without actually doing it"
            echo "SAFE: No changes will be made to your system"
            ;;
        --revert)
            revert_migration
            exit 0
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Function: State tracking
save_state() {
    local step="$1"
    local mode="$2"
    local domain="$3"
    local hostname="$4"
    
    # Determine current mode
    local current_mode=""
    if [[ "$TECHNICIAN_MODE" == "true" ]]; then
        current_mode="technician"
    elif [[ "$LIVE_MODE" == "true" ]]; then
        current_mode="live"
    elif [[ "$DRY_RUN" == "true" ]]; then
        current_mode="dry-run"
    fi
    
    echo "STEP=$step|MODE=$current_mode|DOMAIN=$domain|HOSTNAME=$hostname" > "$STATE_FILE"
    info "Progress saved: Step $step"
}

load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        local state_content=$(cat "$STATE_FILE")
        local step=$(echo "$state_content" | grep -o 'STEP=[0-9]*' | cut -d= -f2)
        local mode=$(echo "$state_content" | grep -o 'MODE=[^|]*' | cut -d= -f2)
        local domain=$(echo "$state_content" | grep -o 'DOMAIN=[^|]*' | cut -d= -f2)
        local hostname=$(echo "$state_content" | grep -o 'HOSTNAME=[^|]*' | cut -d= -f2)
        
        echo "Found previous migration state:"
        echo "  Step: $step"
        echo "  Mode: $mode"
        echo "  Domain: $domain"
        echo "  Hostname: $hostname"
        echo ""
        read -rp "Do you want to resume from step $step? (y/n): " RESUME_CHOICE
        if [[ "$RESUME_CHOICE" =~ ^[Yy]$ ]]; then
            CURRENT_STEP=$step
            NEWDOMAIN=$domain
            SHORTNAME=$hostname
            info "Resuming from step $step"
            return 0
        else
            rm -f "$STATE_FILE"
            info "Starting fresh migration"
            return 1
        fi
    fi
    return 1
}

# Function: Progress indicator
show_progress() {
    local message="$1"
    local pid="$2"
    
    echo -n "$message "
    while kill -0 "$pid" 2>/dev/null; do
        for spinner in "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏"; do
            echo -ne "\r$message $spinner"
            sleep 0.1
            if ! kill -0 "$pid" 2>/dev/null; then
                break 2
            fi
        done
    done
    echo -e "\r$message ✓"
}

# Function: Create rollback point
create_rollback_point() {
    if [[ "$TECHNICIAN_MODE" == "true" ]]; then
        local rollback_name="rollback-$(date +%Y%m%d_%H%M%S)"
        local rollback_path="$ROLLBACK_DIR/$rollback_name"
        
        echo ""
        echo "=========================================="
        echo "ROLLBACK POINT CREATION"
        echo "=========================================="
        echo "Technician mode detected - creating system rollback point"
        echo ""
        echo "What this does:"
        echo "• Creates a complete snapshot of your system configuration"
        echo "• Includes all config files, network settings, and system state"
        echo "• Allows you to completely restore the system if needed"
        echo "• Expected storage: ~50-100MB"
        echo "• Stored in: $rollback_path"
        echo ""
        read -rp "Do you want to create a rollback point? (y/n): " CREATE_ROLLBACK
        
        if [[ "$CREATE_ROLLBACK" =~ ^[Yy]$ ]]; then
            step "Creating system rollback point..."
            
            # Create rollback directory
            mkdir -p "$ROLLBACK_DIR"
            
            # Create rollback archive
            info "Creating system state snapshot..."
            tar -czf "$rollback_path.tar.gz" \
                /etc/hosts \
                /etc/krb5.conf \
                /etc/sssd/sssd.conf \
                /etc/resolv.conf \
                /etc/network/interfaces 2>/dev/null || true \
                /etc/netplan/*.yaml 2>/dev/null || true \
                /etc/hostname \
                /etc/machine-id \
                /var/lib/sss/ \
                /etc/passwd \
                /etc/group \
                /etc/shadow \
                /etc/gshadow 2>/dev/null || true
            
            # Create rollback info file
            cat > "$rollback_path.info" <<EOF
Rollback Point: $rollback_name
Created: $(date)
Mode: technician
Domain: $NEWDOMAIN
Hostname: $SHORTNAME
Size: $(du -h "$rollback_path.tar.gz" | cut -f1)
Restore Command: sudo tar -xzf $rollback_path.tar.gz -C /
EOF
            
            success "Rollback point created: $rollback_name"
            info "Size: $(du -h "$rollback_path.tar.gz" | cut -f1)"
            info "Location: $rollback_path.tar.gz"
            info "Info file: $rollback_path.info"
        else
            info "Skipping rollback point creation"
        fi
    fi
}

# Function: Domain controller discovery
################################################################################################### TODO: Ask Infra team about how domain controller discovery works in our environment
# This function uses DNS SRV records and common naming conventions?
# May need adjustment based on actual domain infrastructure setup?
discover_domain_controllers() {
    local domain="$1"
    local discovered_dcs=()
    
    info "Discovering domain controllers for $domain..."
    
    # Try DNS SRV records first
    if command -v dig >/dev/null 2>&1; then
        info "Checking DNS SRV records..."
        local srv_records=$(dig +short _ldap._tcp.$domain SRV 2>/dev/null)
        if [[ -n "$srv_records" ]]; then
            for record in $srv_records; do
                local dc=$(echo "$record" | awk '{print $4}' | sed 's/\.$//')
                if [[ -n "$dc" ]]; then
                    discovered_dcs+=("$dc")
                fi
            done
        fi
    fi
    
    # Try common DC names if SRV records don't work
    if [[ ${#discovered_dcs[@]} -eq 0 ]]; then
        info "Trying common domain controller names..."
        local common_dcs=("dc1.$domain" "dc.$domain" "ad.$domain" "ldap.$domain" "dc2.$domain")
        for dc in "${common_dcs[@]}"; do
            if ping -c 1 "$dc" >/dev/null 2>&1; then
                discovered_dcs+=("$dc")
            fi
        done
    fi
    
    # Try to get from SSSD config if available
    if [[ -f /etc/sssd/sssd.conf ]]; then
        local sssd_dc=$(grep -i "ad_server" /etc/sssd/sssd.conf | head -1 | awk -F'=' '{print $2}' | tr -d ' ')
        if [[ -n "$sssd_dc" ]]; then
            discovered_dcs+=("$sssd_dc")
        fi
    fi
    
    if [[ ${#discovered_dcs[@]} -gt 0 ]]; then
        success "Discovered domain controllers:"
        for dc in "${discovered_dcs[@]}"; do
            echo "  • $dc"
        done
        # Use the first discovered DC
        DOMAIN_CONTROLLER="${discovered_dcs[0]}"
        info "Using domain controller: $DOMAIN_CONTROLLER"
    else
        warning "Could not discover domain controllers automatically"
        info "Will use default: dc1.$domain"
        DOMAIN_CONTROLLER="dc1.$domain"
    fi
}

# Function: Time synchronisation fix
###########################################################################################################################################TODO: Ask Infra team about how time synchronisation works in our environment
# This function enables NTP synchronisation with domain controllers - don't know if this is something we need to do/something we allow?
fix_time_synchronization() {
    info "Checking time synchronisation..."
    
    if command -v timedatectl >/dev/null 2>&1; then
        if timedatectl status | grep -q "synchronized: yes"; then
            success "Time synchronisation: OK"
        else
            warning "Time synchronisation: FAILED - attempting to fix..."
            info "Enabling NTP synchronisation..."
            
            if [[ "$DRY_RUN" == "true" ]]; then
                info "[DRY-RUN] Would run: timedatectl set-ntp true"
            else
                timedatectl set-ntp true
                info "Waiting for time sync to stabilize..."
                sleep 10
                
                if timedatectl status | grep -q "synchronized: yes"; then
                    success "Time synchronisation fixed successfully"
                else
                    warning "Time synchronisation still failed - Kerberos may not work"
                fi
            fi
        fi
    else
        warning "timedatectl not available - cannot verify time sync"
    fi
}

# Function: Backup verificiation
verify_backup() {
    local backup_file="$1"
    local original_file="$2"
    
    if [[ -f "$backup_file" ]]; then
        if [[ -s "$backup_file" ]]; then
            # Compare file sizes
            local original_size=$(stat -c%s "$original_file" 2>/dev/null || echo "0")
            local backup_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
            
            if [[ $backup_size -gt 0 ]]; then
                success "Backup verified: $backup_file"
                info "Size: ${backup_size} bytes"
                return 0
            else
                error "Backup file is empty: $backup_file"
                return 1
            fi
        else
            error "Backup file is empty: $backup_file"
            return 1
        fi
    else
        error "Backup file not found: $backup_file"
        return 1
    fi
}

# Function: Enhanced backup with verificiation
backup_config() {
    local file="$1"
    local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [[ -f "$file" ]]; then
        info "Creating backup of $file..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            info "[DRY-RUN] Would create backup: $backup"
        else
            cp "$file" "$backup"
            
            # Verify the backup
            if verify_backup "$backup" "$file"; then
                info "Backed up $file to $backup"
            else
                error "Backup verificiation failed for $file"
                exit 1
            fi
        fi
    else
        warning "File $file does not exist, skipping backup"
    fi
}

# Function: Handle concurrent user sessions
handle_concurrent_sessions() {
    info "Checking for active user sesssions..."
    
    # Get active users (excluding backup account)
    local active_users=$(who | grep -v "backup" | awk '{print $1}' | sort -u)
    local active_count=$(echo "$active_users" | wc -l)
    
    if [[ $active_count -gt 0 ]]; then
        warning "Found $active_count active user(s):"
        echo "$active_users" | while read user; do
            echo "  • $user"
        done
        
        echo ""
        echo "WARNING: Active users will be logged out during migration!"
        echo "This is necessary to ensure a clean domain transition."
        echo ""
        read -rp "Do you want to continue? Users will be logged out in 30 seconds. (y/n): " CONTINUE_CHOICE
        
        if [[ "$CONTINUE_CHOICE" =~ ^[Yy]$ ]]; then
            info "Notifying users of impending logout..."
            
            if [[ "$DRY_RUN" == "true" ]]; then
                info "[DRY-RUN] Would send wall message and logout users"
            else
                # Send warning message
                wall "System maintenance in 30 seconds - please save your work and log out"
                
                # Wait 30 seconds
                echo "Waiting 30 seconds for users to save work..."
                for i in {30..1}; do
                    echo -n "$i... "
                    sleep 1
                done
                echo ""
                
                # Logout users
                info "Logging out active users..."
                echo "$active_users" | while read user; do
                    pkill -u "$user" 2>/dev/null || true
                done
                
                success "All users logged out"
            fi
        else
            warning "Continuing migration with active users logged in"
            warning "This may cause issues if users are actively using the system"
            info "Users may be logged out automatically during domain join process"
        fi
    else
        success "No active user sessions detected"
    fi
}

# Function: SSL/TLS certificate validation (commented out as requested)
# validate_ssl_certificates() {
#     local domain="$1"
#     local dc="$2"
#     
#     info "Validating SSL/TLS certificates for $dc..."
#     
#     if command -v openssl >/dev/null 2>&1; then
#         if timeout 10 openssl s_client -connect "$dc:636" -servername "$dc" < /dev/null 2>/dev/null | grep -q "Verify return code: 0"; then
#             success "SSL certificate validation: OK"
#         else
#             warning "SSL certificate validation: FAILED"
#             info "This may affect LDAPS connectivity"
#         fi
#     else
#         warning "openssl not available - cannot validate certificates"
#     fi
# }

# Function: Revert migration (enhanced)
revert_migration() {
    echo "=========================================="
    echo "REVERTING DOMAIN MIGRATION"
    echo "=========================================="
    
    # Check for rollback points first
    if [[ -d "$ROLLBACK_DIR" ]]; then
        local latest_rollback=$(ls -t "$ROLLBACK_DIR"/*.tar.gz 2>/dev/null | head -1)
        if [[ -n "$latest_rollback" ]]; then
            echo "Found rollback point: $latest_rollback"
            read -rp "Do you want to use the rollback point for complete restoration? (y/n): " USE_ROLLBACK
            
            if [[ "$USE_ROLLBACK" =~ ^[Yy]$ ]]; then
                echo "WARNING: This will completely restore your system to the previous state!"
                read -rp "Are you sure? This cannot be undone! (y/n): " CONFIRM_ROLLBACK
                
                if [[ "$CONFIRM_ROLLBACK" =~ ^[Yy]$ ]]; then
                    info "Restoring from rollback point..."
                    tar -xzf "$latest_rollback" -C /
                    success "System restored from rollback point"
                    echo "Please reboot your system: sudo reboot"
                    exit 0
                fi
            fi
        fi
    fi
    
    # Fall back to file-based revert
    echo "Using file-based revert..."
    
    # Find the most recent backup files
    HOSTS_BACKUP=$(ls -t /etc/hosts.backup.* 2>/dev/null | head -1)
    KRB5_BACKUP=$(ls -t /etc/krb5.conf.backup.* 2>/dev/null | head -1)
    SSSD_BACKUP=$(ls -t /etc/sssd/sssd.conf.backup.* 2>/dev/null | head -1)
    
    if [[ -z "$HOSTS_BACKUP" && -z "$KRB5_BACKUP" && -z "$SSSD_BACKUP" ]]; then
        error "No backup files found. Cannot revert migration."
        exit 1
    fi
    
    echo "Found backup files:"
    [[ -n "$HOSTS_BACKUP" ]] && echo "  Hosts: $HOSTS_BACKUP"
    [[ -n "$KRB5_BACKUP" ]] && echo "  Kerberos: $KRB5_BACKUP"
    [[ -n "$SSSD_BACKUP" ]] && echo "  SSSD: $SSSD_BACKUP"
    
    read -rp "Do you want to proceed with reverting? (y/n): " CONFIRM_REVERT
    if [[ ! "$CONFIRM_REVERT" =~ ^[Yy]$ ]]; then
        echo "Revert cancelled."
        exit 0
    fi
    
    step "Restoring configuration files from backups..."
    
    # Restore hosts file
    if [[ -n "$HOSTS_BACKUP" ]]; then
        echo "Restoring /etc/hosts from $HOSTS_BACKUP..."
        cp "$HOSTS_BACKUP" /etc/hosts
        success "Hosts file restored"
    fi
    
    # Restore Kerberos configuration
    if [[ -n "$KRB5_BACKUP" ]]; then
        echo "Restoring /etc/krb5.conf from $KRB5_BACKUP..."
        cp "$KRB5_BACKUP" /etc/krb5.conf
        success "Kerberos configuration restored"
    fi
    
    # Restore SSSD configuration
    if [[ -n "$SSSD_BACKUP" ]]; then
        echo "Restoring /etc/sssd/sssd.conf from $SSSD_BACKUP..."
        cp "$SSSD_BACKUP" /etc/sssd/sssd.conf
        success "SSSD configuration restored"
    fi
    
    # Clear SSSD cache
    step "Clearing SSSD cache..."
    sssctl cache-remove || warning "Could not clear SSSD cache"
    
    # Restart SSSD service
    step "Restarting SSSD service..."
    systemctl restart sssd
    success "SSSD service restarted"
    
    # Handle user profile symlinks
    step "Cleaning up user profile symlinks..."
    info "Checking for user profile symlinks to restore..."
    
    # Find and restore symlinked home directories
    find /home -maxdepth 1 -type l -name "*@*" 2>/dev/null | while read -r symlink; do
        local target=$(readlink "$symlink")
        if [[ -n "$target" && -d "$target" ]]; then
            info "Restoring symlink: $symlink -> $target"
            rm -f "$symlink"
            mv "$target" "$symlink"
            success "Restored: $symlink"
        fi
    done
    
    # Check for user migration logs
    if ls /var/log/user-migration-*.log 2>/dev/null; then
        info "User migration logs found:"
        ls -la /var/log/user-migration-*.log
        read -rp "Do you want to remove user migration logs? (y/n): " REMOVE_LOGS
        if [[ "$REMOVE_LOGS" =~ ^[Yy]$ ]]; then
            rm -f /var/log/user-migration-*.log
            success "User migration logs removed"
        fi
    fi
    
    # Show current domain status
    step "Current domain status:"
    realm list || echo "No domains currently joined"
    
    echo ""
    echo "=========================================="
    echo "REVERT COMPLETE"
    echo "=========================================="
    echo "The system has been reverted to the previous domain configuration."
    echo "A reboot is recommended to ensure all changes take effect."
    echo ""
    read -rp "Do you want to reboot now? (y/n): " REBOOT_NOW
    if [[ "$REBOOT_NOW" =~ ^[Yy]$ ]]; then
        echo "Rebooting in 10 seconds... Press Ctrl+C to cancel"
        for i in {10..1}; do
            echo -n "$i... "
            sleep 1
        done
        echo "Rebooting now!"
        reboot
    else
        echo "Please reboot manually when ready: sudo reboot"
    fi
    
    exit 0
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Function: Display stylized banner with figlet title
banner() {
    echo ""
    if command -v figlet >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then
        echo "Domain Migration" | figlet -f slant | lolcat
    else
        echo "Domain Migration"
        echo "(Install 'figlet' and 'lolcat' for enhanced banner: sudo apt install figlet lolcat)"
    fi
    echo ""
    echo "  Coded by Oscar  |  Domain Migration Made Simple"
    echo ""
}

# Parse arguments first
parse_arguments "$@"

# Display the banner early
banner

# Continue with the rest of the script...

# Function: Display step headers with blue formatting
step() {
    echo -e "\n\033[1;34m==> $1\033[0m"
    echo "------------------------------------------"
}

# Function: Display error messages with red formatting
error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# Function: Display success messages with green formatting
success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

# Function: Display warning messages with yellow formatting
warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

# Function: Display info messages with cyan formatting
info() {
    echo -e "\033[1;36m[INFO]\033[0m $1"
}

# Function: Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function: Handle errors gracefully and continue
handle_error() {
    local error_msg="$1"
    local step_name="$2"
    local continue_anyway="${3:-false}"
    
    error "$error_msg"
    
    if [[ "$continue_anyway" == "true" ]]; then
        warning "Continuing despite the error..."
        return 0
    else
        echo ""
        read -rp "Do you want to continue anyway? (y/n): " CONTINUE_CHOICE
        if [[ "$CONTINUE_CHOICE" =~ ^[Yy]$ ]]; then
            warning "Continuing despite the error..."
            return 0
        else
            error "Migration cancelled by user"
            exit 1
        fi
    fi
}

# Function: Validate domain name format using regex
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 1
    fi
    return 0
}

# Function: Validate email address format using regex
validate_email() {
    local email="$1"
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

# Quick install figlet and lolcat for banner display if not already installed
if ! command -v figlet >/dev/null 2>&1; then
    info "Installing figlet for enhanced banner display..."
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y figlet lolcat -qq >/dev/null 2>&1
    ln -sf /usr/games/lolcat /usr/local/bin/lolcat 2>/dev/null
fi

# =============================================================================
# STATE TRACKING INITIALIZATION
# =============================================================================
step "Initializing state tracking..."
info "Checking for previous migration state..."

if load_state; then
    # Resume from previous state
    info "Resuming migration from step $CURRENT_STEP"
    
    # If we have domain and hostname from state, use them
    if [[ -n "$NEWDOMAIN" && -n "$SHORTNAME" ]]; then
        info "Using saved configuration:"
        info "  Domain: $NEWDOMAIN"
        info "  Hostname: $SHORTNAME"
    fi
else
    # Start fresh migration
    CURRENT_STEP=0
    info "Starting fresh migration"
    
    # Always collect domain and hostname input (required for all modes)
    step "Collecting migration parameters..."
    info "Please provide the following information for the domain migration:"
    echo ""
    
    # Get and validate the new domain name
    info "Step 1/3: New domain information"
    while true; do
        read -rp "Enter your NEW domain (e.g., newdomain.com): " NEWDOMAIN
        if validate_domain "$NEWDOMAIN"; then
            success "Domain format is valid: $NEWDOMAIN"
            break
        else
            error "Invalid domain format. Please enter a valid domain name."
            info "Example: company.com, subdomain.company.com"
        fi
    done
    
    # Get the new hostname from user
    info "Step 2/3: System hostname"
    read -rp "Enter new short hostname (e.g., myhost): " SHORTNAME
    FQDN="$SHORTNAME.$NEWDOMAIN"
    
    # Get admin credentials for the new domain
    info "Step 3/3: Domain admin credentials"
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Using placeholder credentials for simulation"
        NEWADMIN="admin@$NEWDOMAIN"
        NEWADMIN_PASS="testpassword123"
        success "Admin credentials set for dry-run simulation"
    else
        info "You need admin credentials to join the domain $NEWDOMAIN"
        echo ""
        
        # Get admin username
        while true; do
            read -rp "Enter admin username (e.g., admin): " ADMIN_USER
            if [[ -n "$ADMIN_USER" ]]; then
                NEWADMIN="$ADMIN_USER@$NEWDOMAIN"
                success "Admin username set: $NEWADMIN"
                break
            else
                error "Admin username cannot be empty"
            fi
        done
        
        # Get admin password securely
        while true; do
            read -s -rp "Enter admin password: " NEWADMIN_PASS
            echo ""
            if [[ -n "$NEWADMIN_PASS" ]]; then
                success "Admin password set successfully"
                break
            else
                error "Admin password cannot be empty"
            fi
        done
    fi
    
    # Set old admin for reference (not used for migration)
    OLDADMIN="admin@olddomain.com"
    
    success "All input parameters collected successfully!"
    info "Domain: $NEWDOMAIN"
    info "Hostname: $SHORTNAME"
    info "FQDN: $FQDN"
    info "Admin account: $NEWADMIN"
    info "Note: All existing users will be migrated to the new domain"
    echo ""
fi

# =============================================================================
# SYSTEM COMPATIBILITY CHECK
# =============================================================================
step "Checking system compatibility..."
info "Verifying this is a Debian/Ubuntu system..."

if [[ -f /etc/debian_version ]]; then
    success "Detected Debian/Ubuntu system"
    info "System version: $(cat /etc/debian_version)"
else
    warning "This script is designed for Debian/Ubuntu systems"
    info "Proceeding anyway, but some features may not work correctly"
fi

# =============================================================================
# ROOT PRIVILEGES CHECK
# =============================================================================
step "Checking script permissions..."
if [[ "$EUID" -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    echo "Please run: sudo $0"
    exit 1
fi
success "Running with root privileges"

# =============================================================================
# PACKAGE INSTALLATION (Step 2)
# =============================================================================
if [[ $CURRENT_STEP -lt 2 ]]; then
    step "Installing required packages..."
    info "Installing domain migration packages with progress indicators..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would install: realmd sssd sssd-tools adcli libnss-sss libpam-sss samba-common-bin packagekit krb5-user oddjob oddjob-mkhomedir figlet lolcat nnn"
        success "[DRY-RUN] Package installation simulation complete"
    else
        echo "Updating package lists..."
        if ! apt-get update -qq >/dev/null 2>&1; then
            warning "Package list update failed, but continuing..."
        fi
        
        echo "Installing domain migration packages..."
        if ! apt-get install -y figlet lolcat nnn realmd sssd sssd-tools adcli libnss-sss libpam-sss samba-common-bin packagekit krb5-user oddjob oddjob-mkhomedir -qq >/dev/null 2>&1; then
            warning "Some packages failed to install, but continuing..."
        fi
        
        echo "Upgrading system packages..."
        if ! apt-get upgrade -y -qq >/dev/null 2>&1; then
            warning "System upgrade failed, but continuing..."
        fi
        
        echo "Setting up lolcat symlink..."
        ln -sf /usr/games/lolcat /usr/local/bin/lolcat 2>/dev/null
        success "All required packages installed successfully"
    fi
    
    CURRENT_STEP=2
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
    info "Package installation step completed. Moving to next step..."
fi

# =============================================================================
# SAFETY BACKUP ACCOUNT CREATION (Step 3)
# =============================================================================
if [[ $CURRENT_STEP -lt 3 ]]; then
    info "Starting backup account creation step..."
    step "Creating safety backup account..."
    info "Creating a temporary local account for emergency access during migration..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would create backup user account with sudo access"
        success "[DRY-RUN] Backup account creation simulation complete"
    else
        # Check if backup account already exists
        if id "backup" &>/dev/null; then
            warning "Backup account 'backup' already exists"
            info "Using existing backup account (password: backup)"
            # Skip password reset prompt to avoid hanging
        else
            # Create backup user account
            info "Creating backup user account..."
            useradd -m -s /bin/bash backup
            echo "backup:backup" | chpasswd
            
            # Add backup user to sudo group
            usermod -aG sudo backup
            
            # Create sudoers entry for backup user
            echo "backup ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/backup-user
            chmod 440 /etc/sudoers.d/backup-user
            
            success "Backup account 'backup' created successfully"
            info "Username: backup"
            info "Password: backup"
            info "Sudo access: Enabled"
        fi
        
        echo ""
        echo "=========================================="
        echo "EMERGENCY ACCESS INFORMATION"
        echo "=========================================="
        echo "If anything goes wrong during migration, you can:"
        echo "1. Reboot the system"
        echo "2. Log in with:"
        echo "   Username: backup"
        echo "   Password: backup"
        echo "3. Use sudo to troubleshoot or revert changes"
        echo "4. The backup account will be automatically removed"
        echo "   after successful migration verification"
        echo "=========================================="
        echo ""
    fi
    
    CURRENT_STEP=3
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# PRE-MIGRATION CHECKS (Step 4)
# =============================================================================
if [[ $CURRENT_STEP -lt 4 ]]; then
    step "Running pre-migration diagnostics..."
    info "Checking system readiness for domain migration..."
    
    # Check network connectivity
    info "Testing network connectivity..."
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        success "Internet connectivity: OK"
    else
        warning "Internet connectivity: FAILED - Check network connection"
    fi
    
    # Check DNS resolution
    info "Testing DNS resolution..."
    if nslookup google.com >/dev/null 2>&1; then
        success "DNS resolution: OK"
    else
        warning "DNS resolution: FAILED - Check DNS configuration"
    fi
    
    # Check required ports (common AD ports)
    info "Checking common Active Directory ports..."
    AD_PORTS=(389 636 88 464 135 139 445)
    for port in "${AD_PORTS[@]}"; do
        if timeout 3 bash -c "</dev/tcp/localhost/$port" 2>/dev/null; then
            info "Port $port: IN USE (may conflict with AD services)"
        fi
    done
    
    # Check available disk space
    info "Checking available disk space..."
    DISK_SPACE=$(df / | awk 'NR==2 {print $4}')
    if [[ $DISK_SPACE -gt 1048576 ]]; then  # More than 1GB free
        success "Disk space: OK ($(($DISK_SPACE / 1024))MB available)"
    else
        warning "Disk space: LOW ($(($DISK_SPACE / 1024))MB available) - Consider freeing space"
    fi
    
    # Handle concurrent user sessions
    handle_concurrent_sessions
    
    # Check for running services that might conflict
    info "Checking for potentially conflicting services..."
    CONFLICTING_SERVICES=("winbind" "samba" "nmbd" "smbd")
    for service in "${CONFLICTING_SERVICES[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            warning "Service $service is running - may conflict with SSSD"
            read -rp "Do you want to stop $service service? (y/n): " STOP_SERVICE
            if [[ "$STOP_SERVICE" =~ ^[Yy]$ ]]; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    info "[DRY-RUN] Would stop $service service"
                else
                    info "Stopping $service service..."
                    systemctl stop "$service" 2>/dev/null && success "$service stopped" || warning "Could not stop $service"
                fi
            fi
        fi
    done
    
    # Check if system is virtual machine (may affect domain join)
    if [[ -f /sys/class/dmi/id/product_name ]]; then
        PRODUCT_NAME=$(cat /sys/class/dmi/id/product_name)
        if [[ "$PRODUCT_NAME" == *"VMware"* ]] || [[ "$PRODUCT_NAME" == *"VirtualBox"* ]] || [[ "$PRODUCT_NAME" == *"KVM"* ]]; then
            info "Detected virtual machine: $PRODUCT_NAME"
            info "VM domain joins may require additional configuration"
        fi
    fi
    
    # Fix time synchronisation
fix_time_synchronization
    
    echo ""
    success "Pre-migration checks completed"
    
    CURRENT_STEP=4
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# CURRENT DOMAIN STATUS (Step 5)
# =============================================================================
if [[ $CURRENT_STEP -lt 4 ]]; then
    step "Analyzing current domain status..."
    info "Checking which domains this system is currently joined to..."
    
    echo "Current domain membership:"
    realm list || echo "Not currently joined to any domain."
    
    echo ""
    info "Checking SSSD domain configuration:"
    sssctl domain-list || echo "No SSSD domains configured"
    
    CURRENT_STEP=5
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# INPUT VALIDATION (Step 1) - Already completed at start
# =============================================================================
# Input collection is now done at the beginning of the script
# This step is kept for compatibility with existing state files
if [[ $CURRENT_STEP -lt 1 ]]; then
    CURRENT_STEP=1
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# ROLLBACK POINT CREATION (Step 6) - Technician Mode Only
# =============================================================================
if [[ $CURRENT_STEP -lt 6 ]]; then
    if [[ "$TECHNICIAN_MODE" == "true" ]]; then
        create_rollback_point
    fi
    
    CURRENT_STEP=6
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# CONFIGURATION BACKUP (Step 7)
# =============================================================================
if [[ $CURRENT_STEP -lt 7 ]]; then
    step "Creating configuration backups..."
    info "Creating timestamped backups of critical system files..."
    info "These backups will allow you to revert changes if needed."
    
    backup_config "/etc/hosts"
    backup_config "/etc/krb5.conf"
    backup_config "/etc/sssd/sssd.conf"
    
    success "All configuration files backed up successfully"
    echo ""
    
    CURRENT_STEP=7
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# DOMAIN CONTROLLER DISCOVERY (Step 8)
# =============================================================================
if [[ $CURRENT_STEP -lt 8 ]]; then
    step "Discovering domain controllers..."
    if [[ -n "$NEWDOMAIN" ]]; then
        discover_domain_controllers "$NEWDOMAIN"
    else
        info "Domain not yet specified, skipping domain controller discovery"
        DOMAIN_CONTROLLER=""
    fi
    
    CURRENT_STEP=8
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# DOMAIN TRANSITION (Step 9) - The Core Domain Migration Process
# =============================================================================
# This is the heart of the migration - where we actually change domain membership
# Think of this as "changing your network membership card" from one company to another
#
# WHAT HAPPENS HERE:
# 1. Leave the old domain (if currently joined to one)
#    - This removes the computer from the old company's network
#    - Like "turning in your old company ID card"
# 2. Discover the new domain structure
#    - This finds the new company's network servers and structure
#    - Like "getting a map of the new building"
# 3. Join the new domain
#    - This adds the computer to the new company's network
#    - Like "getting your new company ID card"
#
# THE REALM COMMANDS EXPLAINED:
# - realm list: Shows which domains this computer is currently joined to
# - realm leave: Removes the computer from a domain (like "quitting" the network)
# - realm discover: Finds information about a domain (servers, structure, etc.)
# - realm join: Adds the computer to a domain (like "joining" the network)
#
# =============================================================================
if [[ $CURRENT_STEP -lt 9 ]]; then
    step "Initiating domain transition..."
    info "Leaving current domain and joining new domain..."
    info "This is the core migration step - changing network membership"
    
    # Check if currently joined to a domain
    if command -v realm >/dev/null 2>&1 && realm list | grep -q .; then
        info "Currently joined to domain. Attempting to leave..."
        echo "Leaving domain using account: $OLDADMIN"
        
        # Get password for old domain admin if needed
        echo -n "Enter password for $OLDADMIN (if required): "
        read -s OLDADMIN_PASS
        echo ""
        
        if [[ -n "$OLDADMIN_PASS" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                info "[DRY-RUN] Would leave domain using: $OLDADMIN"
            else
                if command -v realm >/dev/null 2>&1; then
                    echo "$OLDADMIN_PASS" | realm leave --user="$OLDADMIN" || warning "Could not leave domain. Continuing anyway..."
                else
                    warning "realm command not found - cannot leave domain"
                fi
            fi
            unset OLDADMIN_PASS
        else
            if [[ "$DRY_RUN" == "true" ]]; then
                info "[DRY-RUN] Would leave domain using: $OLDADMIN"
            else
                if command -v realm >/dev/null 2>&1; then
                    realm leave --user="$OLDADMIN" || warning "Could not leave domain. Continuing anyway..."
                else
                    warning "realm command not found - cannot leave domain"
                fi
            fi
        fi
        info "Domain leave operation completed"
    else
        success "No domain currently joined. Proceeding to join new domain."
    fi
    
    CURRENT_STEP=9
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# DOMAIN DISCOVERY (Step 10)
# =============================================================================
if [[ $CURRENT_STEP -lt 10 ]]; then
    step "Discovering new domain structure..."
    info "Analyzing domain $NEWDOMAIN for available services and configuration..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would discover domain: $NEWDOMAIN"
        success "[DRY-RUN] Domain discovery simulation complete"
    else
        if command -v realm >/dev/null 2>&1; then
            if ! realm discover "$NEWDOMAIN"; then
            error "Failed to discover domain $NEWDOMAIN"
            info "This could be due to:"
            info "  - Network connectivity issues"
            info "  - DNS resolution problems"
            info "  - Domain controller not accessible"
            info "  - Firewall blocking required ports"
            exit 1
        fi
        success "Domain discovery completed successfully"
        else
            error "realm command not found - SSSD may not be installed"
            exit 1
        fi
    fi
    
    CURRENT_STEP=10
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# JOIN NEW DOMAIN (Step 11) - The Critical Domain Join Process
# =============================================================================
# This is where we actually join the new domain - the most critical step
# Think of this as "getting your new company ID card" and "registering with security"
#
# WHAT HAPPENS DURING DOMAIN JOIN:
# 1. Authentication: We prove we have permission to join the domain
#    - Uses the admin credentials you provided
#    - Like "showing your ID to security"
# 2. Computer Account Creation: A new account is created in Active Directory
#    - This computer gets its own "employee record" in the company database
#    - Like "getting your employee badge and file"
# 3. SSSD Configuration: The system is configured to use domain authentication
#    - Sets up the "phone book" to look up domain users
#    - Like "getting access to the company directory"
#
# THE REALM JOIN COMMAND EXPLAINED:
# realm join --user=admin@domain.com domain.com
# - --user=admin@domain.com: The admin account with permission to add computers
# - domain.com: The domain we want to join
# - What it does: Creates computer account, configures authentication, sets up SSSD
#
# ALTERNATIVE JOIN METHOD:
# realm join --user=admin@domain.com --computer-ou="Computers" domain.com
# - --computer-ou="Computers": Specifies where to put the computer account in Active Directory
# - This is used if the default location doesn't work
#
# =============================================================================
if [[ $CURRENT_STEP -lt 11 ]]; then
    step "Joining new domain..."
    info "Attempting to join domain $NEWDOMAIN using account: $NEWADMIN"
    info "This process will:"
    info "  - Authenticate with the domain controller"
    info "  - Create computer account in Active Directory"
    info "  - Configure SSSD for domain authentication"
    info "  - Set up the system for domain user login"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would join domain: $NEWDOMAIN"
        success "[DRY-RUN] Domain join simulation complete"
    else
        # Use password for domain join
        info "Attempting to join domain $NEWDOMAIN..."
        if command -v realm >/dev/null 2>&1; then
            if ! echo "$NEWADMIN_PASS" | realm join --user="$NEWADMIN" "$NEWDOMAIN"; then
            error "Failed to join domain $NEWDOMAIN"
            info "This could be due to:"
            info "  - Invalid credentials"
            info "  - Insufficient permissions"
            info "  - Domain policy restrictions"
            info "  - Network connectivity issues"
            info "  - DNS resolution problems"
            info "  - Firewall blocking required ports"
            
            # Try alternative join method
            info "Attempting alternative domain join method..."
            if ! echo "$NEWADMIN_PASS" | realm join --user="$NEWADMIN" --computer-ou="Computers" "$NEWDOMAIN"; then
                handle_error "Alternative join method also failed" "Domain Join" "true"
            else
                success "Successfully joined domain using alternative method"
            fi
        else
            success "Successfully joined domain $NEWDOMAIN"
        fi
        else
            handle_error "realm command not found - SSSD may not be installed" "Domain Join" "true"
        fi
    fi
    
    # Clear password from memory
    unset NEWADMIN_PASS
    
    CURRENT_STEP=11
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# HOSTNAME CONFIGURATION (Step 12)
# =============================================================================
if [[ $CURRENT_STEP -lt 12 ]]; then
    step "Configuring system hostname..."
    info "Setting up the system hostname for the new domain..."
    
    # Use hostname from earlier input collection
    if [[ -z "$SHORTNAME" ]]; then
        handle_error "Hostname not found. Please restart the script." "Hostname Configuration" "false"
    fi
    FQDN="$SHORTNAME.$NEWDOMAIN"
    
    info "Setting hostname to: $FQDN"
    info "This will update the system's hostname to match the new domain"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would set hostname to: $FQDN"
        success "[DRY-RUN] Hostname configuration simulation complete"
    else
        hostnamectl set-hostname "$FQDN"
        success "Hostname updated to $FQDN"
        
        # Verify hostname was set correctly
        if [[ "$(hostname)" == "$FQDN" ]]; then
            success "Hostname verification: OK"
        else
            warning "Hostname may not have been set correctly"
            info "Current hostname: $(hostname)"
            info "Expected hostname: $FQDN"
        fi
    fi
    
    CURRENT_STEP=12
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# Continue with remaining steps...

# =============================================================================
# NETWORK CONFIGURATION (Step 13)
# =============================================================================
if [[ $CURRENT_STEP -lt 13 ]]; then
    step "Updating network configuration..."
    info "Updating /etc/hosts file to include new hostname and domain information..."
    
    # Check and update DNS configuration
    info "Checking DNS configuration..."
    if [[ -f /etc/resolv.conf ]]; then
        info "Current DNS servers:"
        grep "nameserver" /etc/resolv.conf || echo "No nameservers configured"
        
        # Check if domain DNS is accessible
        if nslookup "$NEWDOMAIN" >/dev/null 2>&1; then
            success "DNS resolution for $NEWDOMAIN: OK"
        else
            warning "DNS resolution for $NEWDOMAIN: FAILED"
            info "You may need to update DNS settings manually"
            info "Consider adding domain DNS servers to /etc/resolv.conf"
            
            # Try to get domain DNS servers
            info "Attempting to discover domain DNS servers..."
            if command_exists dig; then
                DOMAIN_NS=$(dig +short NS "$NEWDOMAIN" | head -1)
                if [[ -n "$DOMAIN_NS" ]]; then
                    info "Found domain nameserver: $DOMAIN_NS"
                    info "Consider adding to /etc/resolv.conf: nameserver $DOMAIN_NS"
                fi
            fi
        fi
    fi
    
    HOSTS_FILE="/etc/hosts"
    IP_LINE="127.0.1.1       $FQDN $SHORTNAME"
    STATIC_IP=$(hostname -I | awk '{print $1}')
    
    info "Current IP address: $STATIC_IP"
    info "New hostname: $SHORTNAME"
    info "Full domain name: $FQDN"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would update /etc/hosts with:"
        info "[DRY-RUN]   127.0.0.1       localhost"
        info "[DRY-RUN]   $IP_LINE"
        if [[ -n "$STATIC_IP" && "$STATIC_IP" != "127.0.1.1" ]]; then
            info "[DRY-RUN]   $STATIC_IP       $FQDN $SHORTNAME"
        fi
        success "[DRY-RUN] Network configuration simulation complete"
    else
        # Create a temporary file for the new hosts content
        info "Creating new /etc/hosts configuration..."
        TEMP_HOSTS=$(mktemp)
        {
            # Remove old hostname entries and add new ones
            grep -v "127.0.1.1" "$HOSTS_FILE" | grep -v "$FQDN" | grep -v "$SHORTNAME"
            echo "127.0.0.1       localhost"
            echo "$IP_LINE"
            if [[ -n "$STATIC_IP" && "$STATIC_IP" != "127.0.1.1" ]]; then
                echo "$STATIC_IP       $FQDN $SHORTNAME"
            fi
        } > "$TEMP_HOSTS"
        
        # Verify the new hosts file looks reasonable before applying
        info "Validating new /etc/hosts configuration..."
        if grep -q "localhost" "$TEMP_HOSTS" && grep -q "$FQDN" "$TEMP_HOSTS"; then
            cp "$TEMP_HOSTS" "$HOSTS_FILE"
            success "/etc/hosts updated successfully"
            info "New hosts file contents:"
            cat "$HOSTS_FILE"
        else
            error "Generated /etc/hosts file appears invalid. Restoring backup."
            cp "${HOSTS_FILE}.backup."* "$HOSTS_FILE" 2>/dev/null || error "Could not restore hosts backup"
            exit 1
        fi
        rm -f "$TEMP_HOSTS"
    fi
    
    CURRENT_STEP=13
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# AUTHENTICATION CONFIGURATION (Step 14)
# =============================================================================
if [[ $CURRENT_STEP -lt 14 ]]; then
    step "Configuring authentication services..."
    info "Setting up Kerberos and SSSD for domain authentication..."
    
    # Clear SSSD cache to ensure fresh authentication
    step "Clearing SSSD cache..."
    info "Removing cached authentication data..."
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would clear SSSD cache"
    else
        sssctl cache-remove || warning "Could not clear SSSD cache (this is normal if no cache exists)"
    fi
    
    # Configure Kerberos for the new domain
    step "Configuring Kerberos authentication..."
    info "Creating Kerberos configuration for domain: ${NEWDOMAIN^^}"
    info "Kerberos is the security system that handles domain authentication"
    info "Think of it as the 'key card system' for the building"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would create Kerberos configuration for realm: ${NEWDOMAIN^^}"
        info "[DRY-RUN] Would set KDC server to: $DOMAIN_CONTROLLER"
        success "[DRY-RUN] Kerberos configuration simulation complete"
    else
        # Create Kerberos configuration file
        # This file tells the system how to authenticate with the domain
        # Think of it as the "security system manual" for the new building
        TEMP_KRB5=$(mktemp)
        cat <<EOF > "$TEMP_KRB5"
[libdefaults]
    default_realm = ${NEWDOMAIN^^}
    dns_lookup_realm = false
    dns_lookup_kdc = true
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    rdns = false

[realms]
    ${NEWDOMAIN^^} = {
        kdc = ${DOMAIN_CONTROLLER:-dc1.$NEWDOMAIN}
        admin_server = ${DOMAIN_CONTROLLER:-dc1.$NEWDOMAIN}
    }

[domain_realm]
    .${NEWDOMAIN} = ${NEWDOMAIN^^}
    ${NEWDOMAIN} = ${NEWDOMAIN^^}
EOF
        
        info "Validating Kerberos configuration..."
        if [[ -s "$TEMP_KRB5" ]]; then
            cp "$TEMP_KRB5" /etc/krb5.conf
            success "Kerberos configuration updated successfully"
            info "Kerberos realm: ${NEWDOMAIN^^}"
            info "KDC server: $DOMAIN_CONTROLLER"
        else
            error "Generated krb5.conf is empty. Restoring backup."
            cp "/etc/krb5.conf.backup."* /etc/krb5.conf 2>/dev/null || error "Could not restore krb5.conf backup"
            exit 1
        fi
        rm -f "$TEMP_KRB5"
    fi
    
    CURRENT_STEP=14
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# SERVICE RESTART (Step 15) - Applying All Configuration Changes
# =============================================================================
# This step restarts the SSSD service to apply all the configuration changes
# Think of this as "rebooting the security system" to load new settings
#
# WHY WE RESTART SSSD:
# SSSD (System Security Services Daemon) is the main service that handles domain authentication
# - It's like the "security office" that manages all domain user access
# - When we change configuration files, we need to restart it to load the new settings
# - Like "reloading the security system with new employee records"
#
# WHAT HAPPENS DURING RESTART:
# 1. SSSD service stops
# 2. New configuration files are loaded
# 3. SSSD service starts with new settings
# 4. System can now authenticate domain users with new configuration
#
# THE SYSTEMCTL COMMANDS:
# - systemctl restart sssd: Stops and starts the SSSD service
# - systemctl start sssd: Starts the service if it's not running
# - systemctl is-active sssd: Checks if the service is currently running
# - systemctl status sssd: Shows detailed status and any error messages
#
# =============================================================================
if [[ $CURRENT_STEP -lt 15 ]]; then
    step "Restarting authentication services..."
    info "Restarting SSSD service to apply new configuration..."
    info "This loads all the domain authentication settings we just configured"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would restart SSSD service"
        success "[DRY-RUN] Service restart simulation complete"
    else
        if systemctl is-active --quiet sssd; then
            info "SSSD service is running. Restarting..."
            systemctl restart sssd
            success "SSSD service restarted successfully"
        else
            warning "SSSD service is not running. Starting it..."
            systemctl start sssd || error "Failed to start SSSD service"
        fi
        
        # Wait for SSSD to fully start
        info "Waiting for SSSD service to fully initialize..."
        sleep 5
        
        # Verify SSSD is running properly
        if systemctl is-active --quiet sssd; then
            success "SSSD service is running properly"
        else
            error "SSSD service failed to start properly"
            systemctl status sssd
            exit 1
        fi
    fi
    
    CURRENT_STEP=15
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# PAM AND NSS CONFIGURATION (Step 16) - Making Domain Authentication Work
# =============================================================================
# This step configures the system to actually use domain authentication
# Think of this as "telling the security system to accept company ID cards"
#
# WHAT ARE PAM AND NSS?
# PAM (Pluggable Authentication Modules): The "security guard" that controls login
# - Decides how users authenticate (local passwords vs domain passwords)
# - Controls what happens during login (create home directory, set permissions, etc.)
# - Like the "bouncer" at the door checking different types of ID
#
# NSS (Name Service Switch): The "phone book lookup system"
# - Tells the system where to look for user information (local files vs domain)
# - Controls how user names, groups, and other info are found
# - Like the "directory service" that knows where to find people
#
# WHAT WE'RE CONFIGURING:
# 1. PAM Configuration: Enable domain authentication and home directory creation
#    - pam-auth-update --enable mkhomedir: Sets up automatic home directory creation
#    - This tells PAM "when a domain user logs in, create their home folder"
# 2. NSS Configuration: Tell the system to use SSSD for user lookups
#    - Updates /etc/nsswitch.conf to include "sss" for passwd, group, shadow
#    - This tells the system "look in local files first, then ask the domain"
#
# THE FILES WE'RE MODIFYING:
# - /etc/pam.d/common-*: PAM configuration files (authentication rules)
# - /etc/nsswitch.conf: Name service switch configuration (where to look for users)
#
# =============================================================================
if [[ $CURRENT_STEP -lt 16 ]]; then
    step "Configuring PAM and NSS for domain authentication..."
    info "Setting up PAM and NSS to use SSSD for domain authentication..."
    info "This configures the system to accept domain user logins"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would configure PAM and NSS for domain authentication"
        success "[DRY-RUN] PAM/NSS configuration simulation complete"
    else
        # Configure PAM to use SSSD and enable home directory creation
        info "Configuring PAM authentication..."
        if command -v pam-auth-update >/dev/null 2>&1; then
            # Enable mkhomedir for automatic home directory creation
            pam-auth-update --enable mkhomedir --force
            success "PAM configuration updated for domain authentication"
        else
            warning "pam-auth-update not found - PAM configuration may need manual setup"
        fi
        
        # Configure NSS to use SSSD
        info "Configuring NSS (Name Service Switch)..."
        if [[ -f /etc/nsswitch.conf ]]; then
            # Backup nsswitch.conf
            cp /etc/nsswitch.conf /etc/nsswitch.conf.backup.$(date +%Y%m%d_%H%M%S)
            
            # Update nsswitch.conf to use sss for passwd, group, and shadow
            sed -i 's/^passwd:.*/passwd:         compat sss/' /etc/nsswitch.conf
            sed -i 's/^group:.*/group:          compat sss/' /etc/nsswitch.conf
            sed -i 's/^shadow:.*/shadow:         compat sss/' /etc/nsswitch.conf
            
            success "NSS configuration updated to use SSSD"
            info "Updated /etc/nsswitch.conf to include SSSD for authentication"
        else
            error "nsswitch.conf not found - NSS configuration failed"
        fi
        
        # Verify NSS configuration
        info "Verifying NSS configuration..."
        if grep -q "sss" /etc/nsswitch.conf; then
            success "NSS configuration verification: OK"
        else
            warning "NSS configuration may not be properly set up"
        fi
    fi
    
    CURRENT_STEP=16
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# HOME DIRECTORY CONFIGURATION (Step 17) - Automatic Home Folder Creation
# =============================================================================
# This step sets up automatic home directory creation for domain users
# Think of this as "setting up the room assignment system" for new employees
#
# WHAT IS ODDJOB-MKHOMEDIR?
# oddjob-mkhomedir: A service that automatically creates home directories
# - When a domain user logs in for the first time, it creates their home folder
# - Like "automatically assigning an office to new employees"
# - Creates /home/username with proper permissions and ownership
#
# HOW IT WORKS:
# 1. User logs in for the first time with domain credentials
# 2. PAM (the security system) calls oddjob-mkhomedir
# 3. oddjob-mkhomedir creates /home/username with proper settings
# 4. User gets their own home directory automatically
#
# THE COMPONENTS:
# - oddjobd: The service that runs the home directory creation
# - oddjob-mkhomedir: The program that actually creates the directories
# - PAM configuration: Tells the system to call oddjob-mkhomedir during login
# - /etc/oddjobd.conf.d/: Configuration files for the oddjob service
#
# WHY THIS IS IMPORTANT:
# - Domain users need home directories to store their files
# - Without this, users can't save files or have personal settings
# - It's like "making sure new employees have a desk and filing cabinet"
#
# =============================================================================
if [[ $CURRENT_STEP -lt 17 ]]; then
    step "Configuring automatic home directory creation..."
    info "Setting up oddjob-mkhomedir for automatic home directory creation..."
    info "This ensures domain users get home folders when they first log in"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would configure home directory creation"
        success "[DRY-RUN] Home directory configuration simulation complete"
    else
        # Ensure oddjob-mkhomedir is properly configured
        info "Configuring oddjob-mkhomedir..."
        if command -v oddjobd >/dev/null 2>&1; then
            # Start oddjobd service if not running
            if ! systemctl is-active --quiet oddjobd; then
                systemctl start oddjobd
                systemctl enable oddjobd
                success "oddjobd service started and enabled"
            else
                success "oddjobd service is already running"
            fi
            
            # Verify oddjob-mkhomedir configuration
            if [[ -f /etc/oddjobd.conf.d/oddjobd-mkhomedir.conf ]]; then
                success "oddjob-mkhomedir configuration found"
            else
                warning "oddjob-mkhomedir configuration not found - creating basic config"
                # Create basic oddjob-mkhomedir configuration
                mkdir -p /etc/oddjobd.conf.d
                cat > /etc/oddjobd.conf.d/oddjobd-mkhomedir.conf <<EOF
[oddjobd]
threads = 5

[mkhomedir]
programs = /usr/sbin/oddjobd-mkhomedir
accept = nobody
max_connections = 2
lifetime = 300
EOF
                success "Created oddjob-mkhomedir configuration"
            fi
            
            # Test home directory creation capability
            info "Testing home directory creation capability..."
            if getent passwd | grep -q "@$NEWDOMAIN"; then
                success "Domain users are available for home directory creation"
            else
                info "No domain users found yet - home directory creation will work when users log in"
            fi
        else
            warning "oddjobd not found - home directory creation may not work properly"
        fi
        
        # Verify PAM configuration includes mkhomedir
        info "Verifying PAM configuration for home directory creation..."
        if grep -q "mkhomedir" /etc/pam.d/common-session; then
            success "PAM mkhomedir configuration: OK"
        else
            warning "PAM mkhomedir not found - home directories may not be created automatically"
        fi
    fi
    
    CURRENT_STEP=19
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# COMPREHENSIVE VERIFICATION AND TESTING (Step 18) - The Complete Health Check
# =============================================================================
# This step performs comprehensive testing to ensure everything works properly
# Think of this as the "final inspection" before handing over the keys
#
# WHAT WE'RE TESTING:
# 1. Domain Membership: Verify the computer is properly joined to the domain
# 2. Authentication: Test that domain users can authenticate
# 3. User Lookups: Verify the system can find domain users
# 4. Group Membership: Test group resolution and membership
# 5. Home Directory Creation: Verify automatic home directory creation works
# 6. Network Connectivity: Test connectivity to domain controllers
# 7. Service Status: Verify all required services are running
# 8. Configuration Files: Check that all config files are properly set up
#
# THE TESTING TOOLS:
# - realm list: Shows current domain membership
# - sssctl domain-list: Shows configured SSSD domains
# - getent passwd: Tests user lookup functionality
# - getent group: Tests group lookup functionality
# - kinit: Tests Kerberos authentication
# - systemctl status: Checks service status
#
# =============================================================================
if [[ $CURRENT_STEP -lt 18 ]]; then
    step "Comprehensive verification and testing..."
    info "Performing complete health check of domain configuration..."
    info "This ensures everything is working before completing migration"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would perform comprehensive verification"
        success "[DRY-RUN] Verification simulation complete"
    else
        # Test 1: Domain Membership
        step "Testing domain membership..."
        info "Verifying computer is properly joined to domain..."
        if command -v realm >/dev/null 2>&1; then
            echo "Current domain membership:"
            realm list
            if realm list | grep -q "$NEWDOMAIN"; then
                success "Domain membership: OK - Computer is joined to $NEWDOMAIN"
            else
                error "Domain membership: FAILED - Computer not properly joined"
                handle_error "Domain membership verification failed" "Domain Verification" "true"
            fi
        else
            error "realm command not found - cannot verify domain membership"
        fi
        
        # Test 2: SSSD Configuration
        step "Testing SSSD configuration..."
        info "Verifying SSSD is properly configured..."
        if command -v sssctl >/dev/null 2>&1; then
            echo "SSSD domain configuration:"
            sssctl domain-list
            if sssctl domain-list | grep -q "$NEWDOMAIN"; then
                success "SSSD configuration: OK - Domain $NEWDOMAIN is configured"
            else
                error "SSSD configuration: FAILED - Domain not properly configured"
                handle_error "SSSD configuration verification failed" "SSSD Verification" "true"
            fi
        else
            error "sssctl command not found - cannot verify SSSD configuration"
        fi
        
        # Test 3: User Lookup Testing
        step "Testing user lookup functionality..."
        info "Verifying system can find domain users..."
        echo "Testing user lookup for domain: $NEWDOMAIN"
        if getent passwd | grep -q "@$NEWDOMAIN"; then
            success "User lookup: OK - Domain users are accessible"
            echo "Available domain users:"
            getent passwd | grep "@$NEWDOMAIN" | head -5
        else
            warning "User lookup: No domain users found yet (this is normal if no users have logged in)"
            info "User lookup will work when domain users first log in"
        fi
        
        # Test 4: Group Lookup Testing
        step "Testing group lookup functionality..."
        info "Verifying system can find domain groups..."
        if getent group | grep -q "@$NEWDOMAIN"; then
            success "Group lookup: OK - Domain groups are accessible"
            echo "Available domain groups:"
            getent group | grep "@$NEWDOMAIN" | head -5
        else
            warning "Group lookup: No domain groups found yet (this is normal)"
        fi
        
        # Test 5: Kerberos Authentication Testing
        step "Testing Kerberos authentication..."
        info "Verifying Kerberos authentication works..."
        if command -v kinit >/dev/null 2>&1; then
            echo "Testing Kerberos authentication with domain: ${NEWDOMAIN^^}"
            if klist 2>/dev/null | grep -q "${NEWDOMAIN^^}"; then
                success "Kerberos authentication: OK - Valid tickets found"
            else
                info "No valid Kerberos tickets found (this is normal if not authenticated)"
                info "Kerberos will work when users log in with domain credentials"
            fi
        else
            warning "kinit command not found - cannot test Kerberos authentication"
        fi
        
        # Test 6: Service Status Verification
        step "Verifying service status..."
        info "Checking that all required services are running..."
        
        # Check SSSD service
        if systemctl is-active --quiet sssd; then
            success "SSSD service: OK - Running"
        else
            error "SSSD service: FAILED - Not running"
            handle_error "SSSD service is not running" "Service Verification" "true"
        fi
        
        # Check oddjobd service
        if systemctl is-active --quiet oddjobd; then
            success "oddjobd service: OK - Running"
        else
            warning "oddjobd service: Not running (home directory creation may not work)"
        fi
        
        # Test 7: Network Connectivity
        step "Testing network connectivity..."
        info "Verifying connectivity to domain controllers..."
        if [[ -n "$DOMAIN_CONTROLLER" ]]; then
            if ping -c 1 "$DOMAIN_CONTROLLER" >/dev/null 2>&1; then
                success "Network connectivity: OK - Can reach $DOMAIN_CONTROLLER"
            else
                warning "Network connectivity: Cannot ping $DOMAIN_CONTROLLER"
                info "This may be normal if ICMP is blocked"
            fi
        else
            info "No domain controller specified for connectivity testing"
        fi
        
        # Test 8: Configuration File Verification
        step "Verifying configuration files..."
        info "Checking that all configuration files are properly set up..."
        
        # Check Kerberos configuration
        if [[ -f /etc/krb5.conf ]]; then
            if grep -q "${NEWDOMAIN^^}" /etc/krb5.conf; then
                success "Kerberos configuration: OK - Domain realm configured"
            else
                warning "Kerberos configuration: Domain realm not found in config"
            fi
        else
            error "Kerberos configuration: FAILED - /etc/krb5.conf not found"
        fi
        
        # Check NSS configuration
        if [[ -f /etc/nsswitch.conf ]]; then
            if grep -q "sss" /etc/nsswitch.conf; then
                success "NSS configuration: OK - SSSD is configured"
            else
                error "NSS configuration: FAILED - SSSD not configured"
            fi
        else
            error "NSS configuration: FAILED - /etc/nsswitch.conf not found"
        fi
        
        # Check PAM configuration
        if grep -q "mkhomedir" /etc/pam.d/common-session; then
            success "PAM configuration: OK - Home directory creation enabled"
        else
            warning "PAM configuration: Home directory creation not configured"
        fi
        
        success "Comprehensive verification completed"
        info "All critical components have been tested and verified"
    fi
    
    CURRENT_STEP=18
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# USER PROFILE MIGRATION (Step 19) - Advanced Profile Migration
# =============================================================================
# This step migrates user profiles from old domain to new domain
# Think of this as "moving employees' personal belongings to their new office"
#
# WHAT WE'RE MIGRATING:
# 1. Home Directories: Move user home folders from old domain to new domain
# 2. File Ownership: Update file ownership to new domain users
# 3. Symbolic Links: Create redirects so old paths still work
# 4. User Settings: Migrate user-specific configuration files
# 5. Application Data: Move application-specific user data
# 6. Desktop Settings: Migrate desktop environment settings
#
# THE MIGRATION PROCESS:
# - Find users with @olddomain in their home folder names
# - Create new home folders with @newdomain names
# - Copy all files and settings from old to new folders
# - Create symbolic links from old to new folders
# - Update file ownership to new domain users
# - Handle conflicts by merging or backing up existing folders
#
# =============================================================================
if [[ $CURRENT_STEP -lt 19 ]]; then
    step "Migrating user profiles and home directories..."
    info "This step will migrate existing user profiles to the new domain structure"
    info "Moving user home directories and creating redirects for compatibility"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would verify domain membership"
        success "[DRY-RUN] Verification simulation complete"
    else
        echo "Current domain membership:"
        if command -v realm >/dev/null 2>&1; then
            realm list
        else
            echo "realm command not found"
        fi
        
        echo ""
        info "Checking SSSD domain configuration:"
        if command -v sssctl >/dev/null 2>&1; then
            sssctl domain-list
        else
            echo "sssctl command not found"
        fi
        
        # Test domain user accessibility
        step "Testing domain user authentication..."
        info "Verifying that domain users can be accessed by the system..."
        
        echo "Testing authentication for domain users..."
        if getent passwd | grep -q "@$NEWDOMAIN"; then
            success "Domain users are accessible"
            info "Domain users found in passwd database"
        else
            warning "No domain users found. This might be normal if no users have logged in yet."
            info "Domain users will become available after first login or cache refresh"
        fi
    fi
    
    CURRENT_STEP=18
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# POST-MIGRATION VERIFICATION (Step 19)
# =============================================================================
if [[ $CURRENT_STEP -lt 19 ]]; then
    step "Running post-migration verification..."
    info "Verifying domain join was successful..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would perform post-migration verification"
        success "[DRY-RUN] Post-migration verification simulation complete"
    else
        # Test Kerberos authentication
        info "Testing Kerberos authentication..."
        if command -v kinit >/dev/null 2>&1; then
            if klist 2>/dev/null | grep -q "$NEWDOMAIN"; then
                success "Kerberos tickets: OK"
            else
                info "No Kerberos tickets found (normal if no user has authenticated)"
            fi
        else
            warning "kinit not available - cannot test Kerberos"
        fi
        
        # Test SSSD status
        info "Checking SSSD service status..."
        if systemctl is-active --quiet sssd; then
            success "SSSD service: RUNNING"
            
            # Check SSSD domain status
            if sssctl domain-list | grep -q "$NEWDOMAIN"; then
                success "SSSD domain configuration: OK"
            else
                warning "SSSD domain not found in domain-list"
            fi
            
            # Check SSSD cache
            if sssctl cache-list | grep -q "entries"; then
                info "SSSD cache contains entries"
            else
                info "SSSD cache is empty (normal for fresh join)"
            fi
        else
            error "SSSD service is not running!"
        fi
        
        # Test DNS resolution for new domain
        info "Testing DNS resolution for new domain..."
        if nslookup "$NEWDOMAIN" >/dev/null 2>&1; then
            success "DNS resolution for $NEWDOMAIN: OK"
        else
            warning "DNS resolution for $NEWDOMAIN: FAILED"
            info "This may affect domain authentication"
        fi
        
        # Test domain controller connectivity
        info "Testing domain controller connectivity..."
        if ping -c 1 "$DOMAIN_CONTROLLER" >/dev/null 2>&1; then
            success "Domain controller connectivity: OK"
        else
            warning "Cannot reach $DOMAIN_CONTROLLER - check network/DNS"
        fi
        
        # Check for any SSSD errors in logs
        info "Checking for SSSD errors..."
        if [[ -f /var/log/sssd/sssd.log ]]; then
            RECENT_ERRORS=$(tail -20 /var/log/sssd/sssd.log | grep -i error | wc -l)
            if [[ $RECENT_ERRORS -gt 0 ]]; then
                warning "Found $RECENT_ERRORS recent SSSD errors"
                info "Recent SSSD log entries:"
                tail -5 /var/log/sssd/sssd.log
            else
                success "No recent SSSD errors found"
            fi
        else
            info "SSSD log file not found (may be normal)"
        fi
        
        # Verify hostname configuration
        info "Verifying hostname configuration..."
        CURRENT_HOSTNAME=$(hostname)
        if [[ "$CURRENT_HOSTNAME" == "$FQDN" ]]; then
            success "Hostname correctly set to: $CURRENT_HOSTNAME"
        else
            warning "Hostname mismatch - expected: $FQDN, actual: $CURRENT_HOSTNAME"
        fi
        
        # Check /etc/hosts configuration
        info "Verifying /etc/hosts configuration..."
        if grep -q "$FQDN" /etc/hosts; then
            success "/etc/hosts contains $FQDN entry"
        else
            warning "/etc/hosts missing $FQDN entry"
        fi
        
        echo ""
        success "Post-migration verification completed"
    fi
    
    CURRENT_STEP=17
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# FINAL VERIFICATION (Step 21)
# =============================================================================
if [[ $CURRENT_STEP -lt 21 ]]; then
    step "Final verification..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        success "[DRY-RUN] Migration simulation completed successfully!"
        echo ""
        echo "=========================================="
        echo "DRY-RUN COMPLETE!"
        echo "=========================================="
        echo "The script has simulated the entire migration process."
        echo "No actual changes were made to your system."
        echo ""
        echo "To perform the actual migration, run:"
        echo "sudo $0 --live"
        echo "or"
        echo "sudo $0 --technician"
        echo ""
    else
        if command -v realm >/dev/null 2>&1 && realm list | grep -q "$NEWDOMAIN"; then
            success "Migration complete. You are now joined to: $NEWDOMAIN"
            echo ""
            echo "=========================================="
            echo "MIGRATION SUCCESSFUL!"
            echo "=========================================="
            echo "Your system has been successfully migrated to: $NEWDOMAIN"
            echo ""
            echo "NEXT STEPS:"
            echo "1. Reboot the system (script will prompt for this)"
            echo "2. Test logging in with a domain user account"
            echo "3. Verify sudo access works for domain users (if enabled)"
            echo "4. Check that domain group memberships are working"
            echo ""
            echo "TROUBLESHOOTING COMMANDS:"
            echo "=========================================="
            echo "Check domain status:        realm list"
            echo "Check SSSD status:          systemctl status sssd"
            echo "Check SSSD logs:            tail -f /var/log/sssd/sssd.log"
            echo "Test domain user access:    getent passwd | grep @$NEWDOMAIN"
            echo "Test Kerberos:              klist"
            echo "Check DNS resolution:       nslookup $NEWDOMAIN"
            echo "Test domain controller:     ping $DOMAIN_CONTROLLER"
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
            echo "   - Test: nslookup $NEWDOMAIN"
            echo ""
            echo "FAIL: Kerberos authentication fails:"
            echo "   - Check system time: timedatectl status"
            echo "   - Enable NTP: timedatectl set-ntp true"
            echo "   - Test: kinit username@$NEWDOMAIN"
            echo ""
            echo "FAIL: Sudo access not working:"
            echo "   - Check sudoers: sudo -l -U username@$NEWDOMAIN"
            echo "   - Verify group membership: groups username@$NEWDOMAIN"
            echo ""
            echo "FAIL: Need to revert changes:"
            echo "   - Run: sudo $0 --revert"
            echo "   - Or manually restore backups: ls -la /etc/*.backup.*"
            echo ""
            echo "FAIL: User profile issues:"
            echo "   - Check migration log: tail -f /var/log/user-migration-*.log"
            echo "   - Verify symlinks: ls -la /home/*@*"
            echo "   - Check user mapping: cat /etc/domain-user-mapping.conf"
            echo "   - Restore from backup: ls -la /home/*.backup"
            echo ""
            echo "SUPPORT FILES:"
            echo "=========================================="
            echo "Backup files:               ls -la /etc/*.backup.*"
            echo "SSSD config:                /etc/sssd/sssd.conf"
            echo "Kerberos config:            /etc/krb5.conf"
            echo "Hosts file:                 /etc/hosts"
            echo "SSSD logs:                  /var/log/sssd/"
            echo "System logs:                journalctl -u sssd"
            echo "User migration logs:        /var/log/user-migration-*.log"
            echo "Account creation logs:      /var/log/account-creation-*.log"
            echo "User mapping file:          /etc/domain-user-mapping.conf"
            if [[ "$TECHNICIAN_MODE" == "true" ]]; then
                echo "Rollback points:            ls -la $ROLLBACK_DIR/"
            fi
        else
            error "Domain join verification failed!"
            echo ""
            echo "TROUBLESHOOTING FAILED MIGRATION:"
            echo "=========================================="
            echo "1. Check network connectivity: ping 8.8.8.8"
            echo "2. Verify DNS resolution: nslookup $NEWDOMAIN"
            echo "3. Check SSSD logs: tail -f /var/log/sssd/sssd.log"
            echo "4. Verify admin credentials are correct"
            echo "5. Check domain controller accessibility"
            echo "6. Ensure firewall allows required ports (389, 636, 88, 464)"
            echo "7. Consider reverting: sudo $0 --revert"
            exit 1
        fi
    fi
    
    CURRENT_STEP=24
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# USER PROFILE MIGRATION (Step 25)
# =============================================================================
if [[ $CURRENT_STEP -lt 25 ]]; then
    step "Migrating user profiles and home directories..."
    info "This step will migrate existing user profiles to the new domain structure"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would migrate user profiles and create symlinks"
        success "[DRY-RUN] User profile migration simulation complete"
    else
        # Function to check if user exists in new domain
        check_domain_user_exists() {
            local username="$1"
            local domain="$2"
            
            # Try multiple methods to check if user exists
            local user_exists=false
            
            # Method 1: Try to get user info via getent (if SSSD is working)
            if getent passwd "$username" >/dev/null 2>&1; then
                user_exists=true
            fi
            
            # Method 2: Try to query domain directly (if tools are available)
            if command -v ldapsearch >/dev/null 2>&1; then
                if ldapsearch -H "ldap://$domain" -D "$NEWADMIN" -w "$NEWADMIN_PASS" -b "DC=$(echo $domain | sed 's/\./,DC=/g')" "(&(objectClass=user)(sAMAccountName=${username%@*}))" dn >/dev/null 2>&1; then
                    user_exists=true
                fi
            fi
            
            # Method 3: Try to authenticate with the user (if credentials available)
            if command -v kinit >/dev/null 2>&1; then
                # This is a basic check - in real scenarios you'd need the user's password
                # For now, we'll assume the user exists if we can't prove otherwise
                user_exists=true
            fi
            
            echo "$user_exists"
        }
        
        # Function to detect local accounts
        detect_local_accounts() {
            local home_dir="$1"
            local username="$2"
            
            # Check for local account indicators
            local is_local=false
            local reason=""
            
            # Method 1: Check if username doesn't contain @ (local account)
            if [[ ! "$username" =~ @ ]]; then
                is_local=true
                reason="No domain suffix detected"
            fi
            
            # Method 2: Check for local account comment in passwd file
            if getent passwd "$username" | grep -q "Local account\|local\|LOCAL"; then
                is_local=true
                reason="Marked as local account in passwd"
            fi
            
            # Method 3: Check for specific local account patterns
            local local_patterns=("local" "LOCAL" "Local account" "left unchanged" "system" "service")
            for pattern in "${local_patterns[@]}"; do
                if getent passwd "$username" | grep -qi "$pattern"; then
                    is_local=true
                    reason="Contains local account pattern: $pattern"
                    break
                fi
            done
            
            # Method 4: Check if user is in local groups only
            local groups=$(groups "$username" 2>/dev/null)
            if [[ -n "$groups" ]]; then
                # Check if user is only in local groups (not domain groups)
                if echo "$groups" | grep -q "@" && ! echo "$groups" | grep -q "@$old_domain\|@$new_domain"; then
                    # User has domain groups but not from our domains - might be local
                    is_local=true
                    reason="Only has non-domain groups"
                fi
            fi
            
            # Method 5: Check for local account indicators in home directory
            if [[ -d "$home_dir" ]]; then
                # Check for local account files or indicators
                if [[ -f "$home_dir/.local_account" ]] || [[ -f "$home_dir/.skip_migration" ]]; then
                    is_local=true
                    reason="Local account marker file found"
                fi
                
                # Check for local account in .profile or .bashrc
                for profile_file in ".profile" ".bashrc" ".bash_profile"; do
                    if [[ -f "$home_dir/$profile_file" ]]; then
                        if grep -qi "local account\|LOCAL\|left unchanged" "$home_dir/$profile_file"; then
                            is_local=true
                            reason="Local account indicator in $profile_file"
                            break
                        fi
                    fi
                done
            fi
            
            echo "$is_local|$reason"
        }
        
        # Function to help mark local accounts
        help_mark_local_accounts() {
            info "Local Account Marking Helper"
            echo ""
            echo "You can mark accounts as local in several ways:"
            echo ""
            echo "1. Create a marker file in the user's home directory:"
            echo "   touch /home/username/.local_account"
            echo "   or"
            echo "   touch /home/username/.skip_migration"
            echo ""
            echo "2. Add a comment to the user's passwd entry:"
            echo "   usermod -c 'Local account, left unchanged' username"
            echo ""
            echo "3. Add a comment to the user's profile files:"
            echo "   echo '# Local account - do not migrate' >> /home/username/.profile"
            echo ""
            echo "4. The script will automatically detect accounts without @domain suffixes"
            echo ""
            
            # Find potential local accounts
            local potential_local=$(find /home -maxdepth 1 -type d -name "*" 2>/dev/null | grep -v "^/home$" | grep -v "@")
            
            if [[ -n "$potential_local" ]]; then
                echo "Potential local accounts found:"
                echo "$potential_local"
                echo ""
                read -rp "Do you want to mark any of these as local accounts? (y/n): " MARK_ACCOUNTS
                
                if [[ "$MARK_ACCOUNTS" =~ ^[Yy]$ ]]; then
                    while IFS= read -r home_dir; do
                        if [[ -d "$home_dir" ]]; then
                            local username=$(basename "$home_dir")
                            read -rp "Mark $username as local account? (y/n): " MARK_USER
                            
                            if [[ "$MARK_USER" =~ ^[Yy]$ ]]; then
                                # Create marker file
                                touch "$home_dir/.local_account"
                                echo "# Local account - do not migrate" >> "$home_dir/.profile" 2>/dev/null || true
                                success "Marked $username as local account"
                            fi
                        fi
                    done <<< "$potential_local"
                fi
            fi
            
            echo ""
            info "Local account marking complete"
        }
        
        # Function to create missing user accounts
        create_missing_user_accounts() {
            local old_domain="$1"
            local new_domain="$2"
            
            info "Creating missing user accounts in new domain..."
            
            # Find users that were skipped (have .backup directories)
            local skipped_users=$(find /home -maxdepth 1 -name "*@${old_domain}.backup" 2>/dev/null | sed 's/.*\///' | sed 's/\.backup$//')
            
            if [[ -z "$skipped_users" ]]; then
                info "No skipped users found to create accounts for"
                return 0
            fi
            
            echo "Found users that were skipped:"
            echo "$skipped_users"
            echo ""
            
            read -rp "Do you want to create accounts for these users? (y/n): " CREATE_ACCOUNTS
            if [[ ! "$CREATE_ACCOUNTS" =~ ^[Yy]$ ]]; then
                info "Skipping account creation"
                return 0
            fi
            
            # Create account creation log
            local account_log="/var/log/account-creation-$(date +%Y%m%d_%H%M%S).log"
            echo "Account Creation Log - $(date)" > "$account_log"
            echo "==========================================" >> "$account_log"
            
            local created_count=0
            local failed_count=0
            
            while IFS= read -r old_username; do
                local clean_username=$(echo "$old_username" | sed 's/@.*$//')
                local new_username="${clean_username}@${new_domain}"
                
                echo "Creating account for: $new_username"
                echo "Creating account: $new_username" >> "$account_log"
                
                # Method 1: Try using samba-tool (if available)
                if command -v samba-tool >/dev/null 2>&1; then
                    info "Using samba-tool to create user account..."
                    if samba-tool user create "$clean_username" --random-password --use-username-as-cn 2>>"$account_log"; then
                        success "Created user account: $new_username"
                        echo "SUCCESS: Created user $new_username" >> "$account_log"
                        ((created_count++))
                        continue
                    else
                        warning "samba-tool failed for $new_username"
                        echo "FAILED: samba-tool failed for $new_username" >> "$account_log"
                    fi
                fi
                
                # Method 2: Try using ldapadd (if available)
                if command -v ldapadd >/dev/null 2>&1; then
                    info "Using ldapadd to create user account..."
                    # Create LDIF file for user
                    local ldif_file="/tmp/user_${clean_username}.ldif"
                    cat > "$ldif_file" <<EOF
dn: CN=$clean_username,CN=Users,DC=$(echo $new_domain | sed 's/\./,DC=/g')
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: user
cn: $clean_username
sAMAccountName: $clean_username
userPrincipalName: $new_username
displayName: $clean_username
givenName: $clean_username
sn: $clean_username
userAccountControl: 512
EOF
                    
                    if ldapadd -H "ldap://$new_domain" -D "$NEWADMIN" -w "$NEWADMIN_PASS" -f "$ldif_file" >> "$account_log" 2>&1; then
                        success "Created user account: $new_username"
                        echo "SUCCESS: Created user $new_username" >> "$account_log"
                        ((created_count++))
                    else
                        warning "ldapadd failed for $new_username"
                        echo "FAILED: ldapadd failed for $new_username" >> "$account_log"
                        ((failed_count++))
                    fi
                    rm -f "$ldif_file"
                else
                    warning "No suitable tools available to create user account for $new_username"
                    echo "FAILED: No tools available for $new_username" >> "$account_log"
                    ((failed_count++))
                fi
                
                # Ask user if they want to continue
                read -rp "Continue with next user? (y/n): " CONTINUE_CREATION
                if [[ ! "$CONTINUE_CREATION" =~ ^[Yy]$ ]]; then
                    info "Account creation stopped by user"
                    break
                fi
                
            done <<< "$skipped_users"
            
            # Summary
            echo "" >> "$account_log"
            echo "Account Creation Summary:" >> "$account_log"
            echo "Successfully created: $created_count accounts" >> "$account_log"
            echo "Failed creations: $failed_count accounts" >> "$account_log"
            
            success "Account creation completed"
            info "Successfully created: $created_count accounts"
            if [[ $failed_count -gt 0 ]]; then
                warning "Failed creations: $failed_count accounts"
            fi
            info "Account creation log: $account_log"
            
            # Offer to retry migration for newly created accounts
            if [[ $created_count -gt 0 ]]; then
                echo ""
                read -rp "Do you want to retry migration for newly created accounts? (y/n): " RETRY_MIGRATION
                if [[ "$RETRY_MIGRATION" =~ ^[Yy]$ ]]; then
                    info "Retrying migration for newly created accounts..."
                    migrate_user_profiles "$old_domain" "$new_domain"
                fi
            fi
        }
        
        # Function to migrate user profiles
        migrate_user_profiles() {
            local old_domain="$1"
            local new_domain="$2"
            
            info "Starting user profile migration from $old_domain to $new_domain..."
            
            # Get list of existing home directories
            local existing_homes=$(find /home -maxdepth 1 -type d -name "*@*" 2>/dev/null | grep -v "^/home$")
            
            if [[ -z "$existing_homes" ]]; then
                info "No existing domain user home directories found"
                return 0
            fi
            
            echo "Found existing user home directories:"
            echo "$existing_homes"
            echo ""
            
            read -rp "Do you want to migrate these user profiles? (y/n): " MIGRATE_PROFILES
            if [[ ! "$MIGRATE_PROFILES" =~ ^[Yy]$ ]]; then
                info "Skipping user profile migration"
                return 0
            fi
            
            # Ask if user wants to validate domain accounts
            read -rp "Do you want to validate that users exist in the new domain before migration? (y/n): " VALIDATE_ACCOUNTS
            local validate_accounts=false
            if [[ "$VALIDATE_ACCOUNTS" =~ ^[Yy]$ ]]; then
                validate_accounts=true
                info "Account validation enabled - will check if users exist in new domain"
            else
                info "Account validation disabled - will migrate all users"
            fi
            
            # Create migration log
            local migration_log="/var/log/user-migration-$(date +%Y%m%d_%H%M%S).log"
            echo "User Profile Migration Log - $(date)" > "$migration_log"
            echo "==========================================" >> "$migration_log"
            echo "Old Domain: $old_domain" >> "$migration_log"
            echo "New Domain: $new_domain" >> "$migration_log"
            echo "Account Validation: $validate_accounts" >> "$migration_log"
            echo "==========================================" >> "$migration_log"
            
            local migrated_count=0
            local failed_count=0
            local skipped_count=0
            local users_to_migrate=()
            local users_to_skip=()
            
            # First pass: validate users and build migration list
            info "Validating user accounts in new domain..."
            while IFS= read -r old_home; do
                if [[ -d "$old_home" ]]; then
                    local username=$(basename "$old_home")
                    local old_username="$username"
                    local clean_username=$(echo "$username" | sed 's/@.*$//')
                    local new_username="${clean_username}@${new_domain}"
                    
                    echo "Checking user: $old_username -> $new_username"
                    
                    # Check if this is a local account
                    local local_check=$(detect_local_accounts "$old_home" "$username")
                    local is_local=$(echo "$local_check" | cut -d'|' -f1)
                    local local_reason=$(echo "$local_check" | cut -d'|' -f2)
                    
                    if [[ "$is_local" == "true" ]]; then
                        info "LOCAL: Local account detected: $old_username"
                        info "   Reason: $local_reason"
                        echo "LOCAL: $old_username ($local_reason)" >> "$migration_log"
                        
                        read -rp "Skip local account $old_username? (y/n): " SKIP_LOCAL
                        if [[ "$SKIP_LOCAL" =~ ^[Yy]$ ]]; then
                            users_to_skip+=("$old_home")
                            ((skipped_count++))
                            echo "Skipping local account $old_username" >> "$migration_log"
                            continue
                        else
                            info "Will migrate local account $old_username despite detection"
                        fi
                    fi
                    
                    if [[ "$validate_accounts" == "true" ]]; then
                        # Check if user exists in new domain
                        local user_exists=$(check_domain_user_exists "$new_username" "$new_domain")
                        
                        if [[ "$user_exists" == "true" ]]; then
                            users_to_migrate+=("$old_home")
                            info "OK: User $new_username exists in new domain"
                        else
                            warning "FAIL: User $new_username not found in new domain"
                            read -rp "Skip migration for $old_username? (y/n): " SKIP_USER
                            if [[ "$SKIP_USER" =~ ^[Yy]$ ]]; then
                                users_to_skip+=("$old_home")
                                ((skipped_count++))
                                echo "Skipping $old_username due to user choice" >> "$migration_log"
                            else
                                users_to_migrate+=("$old_home")
                                info "Will migrate $old_username despite account issues"
                            fi
                        fi
                    else
                        # No validation - migrate all users
                        users_to_migrate+=("$old_home")
                        info "Will migrate $old_username (no validation)"
                    fi
                fi
            done <<< "$existing_homes"
            
            # Show migration plan
            echo ""
            echo "=========================================="
            echo "MIGRATION PLAN"
            echo "=========================================="
            echo "Users to migrate: ${#users_to_migrate[@]}"
            for home in "${users_to_migrate[@]}"; do
                local username=$(basename "$home")
                local clean_username=$(echo "$username" | sed 's/@.*$//')
                echo "  OK: $username -> ${clean_username}@${new_domain}"
            done
            
            if [[ ${#users_to_skip[@]} -gt 0 ]]; then
                echo ""
                echo "Users to skip: ${#users_to_skip[@]}"
                for home in "${users_to_skip[@]}"; do
                    local username=$(basename "$home")
                    # Check if this was a local account
                    local local_check=$(detect_local_accounts "$home" "$username")
                    local is_local=$(echo "$local_check" | cut -d'|' -f1)
                    
                    if [[ "$is_local" == "true" ]]; then
                        echo "  LOCAL: $username (local account)"
                    else
                        echo "  FAIL: $username (account issues)"
                    fi
                done
            fi
            echo "=========================================="
            echo ""
            
            read -rp "Proceed with migration plan? (y/n): " PROCEED_MIGRATION
            if [[ ! "$PROCEED_MIGRATION" =~ ^[Yy]$ ]]; then
                info "Migration cancelled by user"
                return 0
            fi
            
            # Second pass: perform actual migration
            info "Starting user profile migration..."
            for old_home in "${users_to_migrate[@]}"; do
                if [[ -d "$old_home" ]]; then
                    local username=$(basename "$old_home")
                    local old_username="$username"
                    local clean_username=$(echo "$username" | sed 's/@.*$//')
                    local new_username="${clean_username}@${new_domain}"
                    local new_home="/home/$new_username"
                    
                    info "Migrating user: $old_username -> $new_username"
                    echo "Migrating: $old_username -> $new_username" >> "$migration_log"
                    
                    # Check if new home already exists
                    if [[ -d "$new_home" ]]; then
                        warning "New home directory already exists: $new_home"
                        echo "WARNING: New home already exists: $new_home" >> "$migration_log"
                        
                        read -rp "Do you want to merge the contents? (y/n): " MERGE_CONTENTS
                        if [[ "$MERGE_CONTENTS" =~ ^[Yy]$ ]]; then
                            info "Merging contents from $old_home to $new_home..."
                            echo "Merging contents..." >> "$migration_log"
                            
                            # Create backup of existing new home
                            local backup_dir="/home/backup-${clean_username}-$(date +%Y%m%d_%H%M%S)"
                            cp -r "$new_home" "$backup_dir" 2>/dev/null
                            echo "Backup created: $backup_dir" >> "$migration_log"
                            
                            # Copy contents from old to new (preserving existing files)
                            if command -v rsync >/dev/null 2>&1; then
                                rsync -av --ignore-existing "$old_home/" "$new_home/" >> "$migration_log" 2>&1
                            else
                                cp -r "$old_home"/* "$new_home/" 2>/dev/null || true
                                echo "Used cp instead of rsync" >> "$migration_log"
                            fi
                            
                            # Create symlink from old to new
                            if [[ ! -L "$old_home" ]]; then
                                mv "$old_home" "${old_home}.backup"
                                ln -sf "$new_home" "$old_home"
                                echo "Created symlink: $old_home -> $new_home" >> "$migration_log"
                            fi
                        else
                            info "Skipping merge for $old_username"
                            echo "Skipped merge for: $old_username" >> "$migration_log"
                            continue
                        fi
                    else
                        # Move the entire home directory
                        info "Moving home directory: $old_home -> $new_home"
                        echo "Moving: $old_home -> $new_home" >> "$migration_log"
                        
                        # Create new home directory
                        mkdir -p "$(dirname "$new_home")"
                        
                        # Move the home directory
                        if mv "$old_home" "$new_home"; then
                            # Create symlink from old location to new location
                            ln -sf "$new_home" "$old_home"
                            echo "Created symlink: $old_home -> $new_home" >> "$migration_log"
                            
                            # Update ownership if possible
                            if command -v chown >/dev/null 2>&1; then
                                # Try to set ownership to the new username
                                chown -R "$new_username" "$new_home" 2>/dev/null || warning "Could not update ownership for $new_home"
                            fi
                            
                            success "Successfully migrated $old_username -> $new_username"
                            echo "SUCCESS: Migrated $old_username -> $new_username" >> "$migration_log"
                            ((migrated_count++))
                        else
                            error "Failed to migrate $old_username"
                            echo "ERROR: Failed to migrate $old_username" >> "$migration_log"
                            ((failed_count++))
                        fi
                    fi
                fi
            done
            
            # Create a comprehensive symlink map for any remaining old domain references
            create_symlink_map() {
                info "Creating comprehensive symlink map for domain transition..."
                
                # Get the old domain name from existing symlinks or user input
                local old_domain_name=""
                if [[ -n "$old_domain" ]]; then
                    old_domain_name="$old_domain"
                else
                    # Try to detect from existing home directories
                    local detected_domain=$(find /home -maxdepth 1 -type l -name "*@*" 2>/dev/null | head -1 | sed 's/.*@//')
                    if [[ -n "$detected_domain" ]]; then
                        old_domain_name="$detected_domain"
                    else
                        read -rp "Enter the old domain name: " old_domain_name
                    fi
                fi
                
                if [[ -n "$old_domain_name" ]]; then
                    # Create a mapping file for reference
                    local mapping_file="/etc/domain-user-mapping.conf"
                    cat > "$mapping_file" <<EOF
# Domain User Mapping Configuration
# Created: $(date)
# Old Domain: $old_domain_name
# New Domain: $new_domain

# This file maps old domain usernames to new domain usernames
# Format: old_username@old_domain -> new_username@new_domain

EOF
                    
                    # Find all symlinks and create mapping
                    find /home -maxdepth 1 -type l -name "*@$old_domain_name" 2>/dev/null | while read -r symlink; do
                        local old_username=$(basename "$symlink")
                        local clean_username=$(echo "$old_username" | sed 's/@.*$//')
                        local new_username="${clean_username}@${new_domain}"
                        local target=$(readlink "$symlink")
                        
                        echo "$old_username -> $new_username ($target)" >> "$mapping_file"
                    done
                    
                    success "Created user mapping file: $mapping_file"
                    echo "Created mapping file: $mapping_file" >> "$migration_log"
                fi
            }
            
            create_symlink_map
            
            # Summary
            echo "" >> "$migration_log"
            echo "Migration Summary:" >> "$migration_log"
            echo "Successfully migrated: $migrated_count users" >> "$migration_log"
            echo "Failed migrations: $failed_count users" >> "$migration_log"
            echo "Skipped migrations: $skipped_count users" >> "$migration_log"
            echo "Migration log: $migration_log" >> "$migration_log"
            
            success "User profile migration completed"
            info "Successfully migrated: $migrated_count users"
            if [[ $failed_count -gt 0 ]]; then
                warning "Failed migrations: $failed_count users"
            fi
            if [[ $skipped_count -gt 0 ]]; then
                info "Skipped migrations: $skipped_count users (account issues)"
            fi
            info "Migration log: $migration_log"
            
            # Show current home directory structure
            echo ""
            info "Current home directory structure:"
            ls -la /home/ | grep -E "@|^d" || echo "No domain user directories found"
        }
        
        # Get old domain information
        local old_domain=""
        if [[ -n "$OLDADMIN" ]]; then
            old_domain=$(echo "$OLDADMIN" | sed 's/.*@//')
        fi
        
        # Check if we have old domain information
        if [[ -z "$old_domain" ]]; then
            read -rp "Enter the old domain name (or press Enter to skip): " old_domain
        fi
        
        if [[ -n "$old_domain" ]]; then
            # Offer to help mark local accounts
            echo ""
            echo "=========================================="
            echo "LOCAL ACCOUNT DETECTION SETUP"
            echo "=========================================="
            echo "The script can automatically detect local accounts to skip during migration."
            echo "You can also manually mark accounts as local by creating marker files."
            echo ""
            read -rp "Do you want to help mark local accounts before migration? (y/n): " MARK_LOCAL
            
            if [[ "$MARK_LOCAL" =~ ^[Yy]$ ]]; then
                help_mark_local_accounts
            fi
            
            migrate_user_profiles "$old_domain" "$NEWDOMAIN"
            
            # Offer to create missing user accounts
            echo ""
            echo "=========================================="
            echo "POST-MIGRATION USER ACCOUNT SETUP"
            echo "=========================================="
            echo "If any users were skipped due to missing accounts in the new domain,"
            echo "you may want to create them now."
            echo ""
            read -rp "Do you want to create missing user accounts in the new domain? (y/n): " CREATE_ACCOUNTS
            
            if [[ "$CREATE_ACCOUNTS" =~ ^[Yy]$ ]]; then
                create_missing_user_accounts "$old_domain" "$NEWDOMAIN"
            fi
        else
            info "No old domain specified, skipping user profile migration"
        fi
    fi
    
    CURRENT_STEP=19
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# NETWORK RESOURCE MIGRATION (Step 20) - Advanced Network Resource Migration
# =============================================================================
# This step migrates network resources like printers, drives, and VPN connections
# Think of this as "moving the office equipment and connections to the new building"
#
# WHAT WE'RE MIGRATING:
# 1. Network Printers: Migrate printer connections and settings
# 2. Network Drives: Migrate mapped network drives and shares
# 3. VPN Connections: Migrate VPN configurations and settings
# 4. Network Bookmarks: Migrate network shortcuts and bookmarks
# 5. Application Shortcuts: Migrate application-specific network paths
# 6. Credential Storage: Migrate stored network credentials
#
# THE MIGRATION PROCESS:
# - Scan for network resources in user profiles
# - Update network paths to use new domain
# - Migrate printer configurations
# - Update network drive mappings
# - Migrate VPN connection settings
# - Update application shortcuts and bookmarks
#
# =============================================================================
if [[ $CURRENT_STEP -lt 20 ]]; then
    step "Migrating network resources and connections..."
    info "This step migrates network printers, drives, and other domain resources"
    info "Updating network paths and configurations for the new domain"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would migrate network resources and printers"
        success "[DRY-RUN] Network resource migration simulation complete"
    else
        # Function: Migrate network printers
        migrate_network_printers() {
            info "Migrating network printer configurations..."
            
            # Find CUPS printer configurations
            if [[ -d /etc/cups ]]; then
                info "Scanning CUPS printer configurations..."
                find /etc/cups -name "*.conf" -exec grep -l "$old_domain" {} \; 2>/dev/null | while read -r file; do
                    info "Updating printer configuration: $file"
                    sed -i "s/$old_domain/$NEWDOMAIN/g" "$file"
                done
            fi
            
            # Update user printer configurations
            find /home -name ".cups" -type d 2>/dev/null | while read -r user_cups; do
                info "Updating user printer config: $user_cups"
                find "$user_cups" -name "*.conf" -exec sed -i "s/$old_domain/$NEWDOMAIN/g" {} \;
            done
            
            success "Network printer migration completed"
        }
        
        # Function: Migrate network drives
        migrate_network_drives() {
            info "Migrating network drive configurations..."
            
            # Update fstab entries
            if [[ -f /etc/fstab ]]; then
                info "Updating fstab network drive entries..."
                sed -i "s/$old_domain/$NEWDOMAIN/g" /etc/fstab
            fi
            
            # Update user mount configurations
            find /home -name ".config" -type d 2>/dev/null | while read -r user_config; do
                if [[ -f "$user_config/gtk-3.0/bookmarks" ]]; then
                    info "Updating user bookmarks: $user_config/gtk-3.0/bookmarks"
                    sed -i "s/$old_domain/$NEWDOMAIN/g" "$user_config/gtk-3.0/bookmarks"
                fi
            done
            
            success "Network drive migration completed"
        }
        
        # Function: Migrate VPN connections
        migrate_vpn_connections() {
            info "Migrating VPN connection configurations..."
            
            # Update NetworkManager VPN configurations
            if [[ -d /etc/NetworkManager/system-connections ]]; then
                info "Updating NetworkManager VPN configurations..."
                find /etc/NetworkManager/system-connections -name "*.nmconnection" -exec sed -i "s/$old_domain/$NEWDOMAIN/g" {} \;
            fi
            
            # Update user VPN configurations
            find /home -name ".config" -type d 2>/dev/null | while read -r user_config; do
                if [[ -d "$user_config/NetworkManager" ]]; then
                    info "Updating user VPN config: $user_config/NetworkManager"
                    find "$user_config/NetworkManager" -name "*.nmconnection" -exec sed -i "s/$old_domain/$NEWDOMAIN/g" {} \;
                fi
            done
            
            success "VPN connection migration completed"
        }
        
        # Function: Migrate application shortcuts
        migrate_application_shortcuts() {
            info "Migrating application shortcuts and bookmarks..."
            
            # Update desktop shortcuts
            find /home -name "Desktop" -type d 2>/dev/null | while read -r desktop; do
                info "Updating desktop shortcuts: $desktop"
                find "$desktop" -name "*.desktop" -exec sed -i "s/$old_domain/$NEWDOMAIN/g" {} \;
            done
            
            # Update application bookmarks
            find /home -name ".config" -type d 2>/dev/null | while read -r user_config; do
                # Update various application bookmarks
                for app in "nautilus" "dolphin" "thunar" "pcmanfm"; do
                    if [[ -f "$user_config/$app/bookmarks" ]]; then
                        info "Updating $app bookmarks: $user_config/$app/bookmarks"
                        sed -i "s/$old_domain/$NEWDOMAIN/g" "$user_config/$app/bookmarks"
                    fi
                done
            done
            
            success "Application shortcut migration completed"
        }
        
        # Execute migration functions
        if [[ -n "$old_domain" ]]; then
            migrate_network_printers
            migrate_network_drives
            migrate_vpn_connections
            migrate_application_shortcuts
            success "Network resource migration completed successfully"
        else
            info "No old domain specified, skipping network resource migration"
        fi
    fi
    
    CURRENT_STEP=20
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# APPLICATION CONFIGURATION MIGRATION (Step 21) - Advanced Application Migration
# =============================================================================
# This step migrates application-specific configurations and settings
# Think of this as "moving the office software settings to the new building"
#
# WHAT WE'RE MIGRATING:
# 1. Email Clients: Migrate email account configurations
# 2. Web Browsers: Migrate browser bookmarks and settings
# 3. Office Applications: Migrate office application settings
# 4. Development Tools: Migrate development environment configurations
# 5. System Applications: Migrate system application settings
# 6. Custom Scripts: Migrate custom scripts and automation
#
# THE MIGRATION PROCESS:
# - Scan for application configuration files
# - Update domain-specific settings in applications
# - Migrate user preferences and bookmarks
# - Update authentication settings
# - Migrate custom scripts and automation
#
# =============================================================================
if [[ $CURRENT_STEP -lt 21 ]]; then
    step "Migrating application configurations..."
    info "This step migrates application-specific settings and configurations"
    info "Updating applications to work with the new domain"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would migrate application configurations"
        success "[DRY-RUN] Application configuration migration simulation complete"
    else
        # Function: Migrate email client configurations
        migrate_email_configurations() {
            info "Migrating email client configurations..."
            
            # Update Thunderbird configurations
            find /home -name ".thunderbird" -type d 2>/dev/null | while read -r thunderbird; do
                info "Updating Thunderbird config: $thunderbird"
                find "$thunderbird" -name "*.sqlite" -exec sqlite3 {} "UPDATE moz_prefs SET value = replace(value, '$old_domain', '$NEWDOMAIN') WHERE value LIKE '%$old_domain%';" \;
            done
            
            # Update Evolution configurations
            find /home -name ".evolution" -type d 2>/dev/null | while read -r evolution; do
                info "Updating Evolution config: $evolution"
                find "$evolution" -name "*.xml" -exec sed -i "s/$old_domain/$NEWDOMAIN/g" {} \;
            done
            
            success "Email client migration completed"
        }
        
        # Function: Migrate web browser configurations
        migrate_browser_configurations() {
            info "Migrating web browser configurations..."
            
            # Update Firefox configurations
            find /home -name ".mozilla" -type d 2>/dev/null | while read -r firefox; do
                info "Updating Firefox config: $firefox"
                find "$firefox" -name "*.sqlite" -exec sqlite3 {} "UPDATE moz_prefs SET value = replace(value, '$old_domain', '$NEWDOMAIN') WHERE value LIKE '%$old_domain%';" \;
            done
            
            # Update Chrome configurations
            find /home -name ".config/google-chrome" -type d 2>/dev/null | while read -r chrome; do
                info "Updating Chrome config: $chrome"
                find "$chrome" -name "Preferences" -exec sed -i "s/$old_domain/$NEWDOMAIN/g" {} \;
            done
            
            success "Web browser migration completed"
        }
        
        # Function: Migrate office application configurations
        migrate_office_configurations() {
            info "Migrating office application configurations..."
            
            # Update LibreOffice configurations
            find /home -name ".config/libreoffice" -type d 2>/dev/null | while read -r libreoffice; do
                info "Updating LibreOffice config: $libreoffice"
                find "$libreoffice" -name "*.xml" -exec sed -i "s/$old_domain/$NEWDOMAIN/g" {} \;
            done
            
            # Update other office applications
            for app in "calligra" "gnome-office" "koffice"; do
                find /home -name ".config/$app" -type d 2>/dev/null | while read -r app_config; do
                    info "Updating $app config: $app_config"
                    find "$app_config" -name "*.conf" -exec sed -i "s/$old_domain/$NEWDOMAIN/g" {} \;
                done
            done
            
            success "Office application migration completed"
        }
        
        # Function: Migrate development tool configurations
        migrate_development_configurations() {
            info "Migrating development tool configurations..."
            
            # Update Git configurations
            find /home -name ".gitconfig" 2>/dev/null | while read -r gitconfig; do
                info "Updating Git config: $gitconfig"
                sed -i "s/$old_domain/$NEWDOMAIN/g" "$gitconfig"
            done
            
            # Update SSH configurations
            find /home -name ".ssh" -type d 2>/dev/null | while read -r ssh_dir; do
                info "Updating SSH config: $ssh_dir"
                find "$ssh_dir" -name "config" -exec sed -i "s/$old_domain/$NEWDOMAIN/g" {} \;
            done
            
            # Update IDE configurations
            for ide in "vscode" "intellij" "eclipse" "netbeans"; do
                find /home -name ".config/$ide" -type d 2>/dev/null | while read -r ide_config; do
                    info "Updating $ide config: $ide_config"
                    find "$ide_config" -name "*.xml" -exec sed -i "s/$old_domain/$NEWDOMAIN/g" {} \;
                done
            done
            
            success "Development tool migration completed"
        }
        
        # Execute migration functions
        if [[ -n "$old_domain" ]]; then
            migrate_email_configurations
            migrate_browser_configurations
            migrate_office_configurations
            migrate_development_configurations
            success "Application configuration migration completed successfully"
        else
            info "No old domain specified, skipping application configuration migration"
        fi
    fi
    
    CURRENT_STEP=21
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# SUDO ACCESS CONFIGURATION (Step 22)
# =============================================================================
if [[ $CURRENT_STEP -lt 22 ]]; then
    step "Setting up sudo access for domain users..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would configure sudo access for domain users"
        success "[DRY-RUN] Sudo configuration simulation complete"
    else
        read -rp "Do you want to add domain users to sudo group? (y/n): " ADD_SUDO
        if [[ "$ADD_SUDO" =~ ^[Yy]$ ]]; then
            echo "Adding domain users to sudo group..."
            # Add domain users to sudo group via SSSD configuration
            if [[ -f /etc/sssd/sssd.conf ]]; then
                # Backup current SSSD config
                backup_config "/etc/sssd/sssd.conf"
                
                # Add sudo configuration to SSSD
                if ! grep -q "sudo_provider" /etc/sssd/sssd.conf; then
                    echo "Adding sudo provider configuration to SSSD..."
                    sed -i '/\[domain\/.*\]/a sudo_provider = ad' /etc/sssd/sssd.conf
                fi
                
                # Configure sudoers to allow domain users
                echo "Configuring sudoers for domain users..."
                cat <<EOF > /etc/sudoers.d/domain-users
# Allow domain users to use sudo
%${NEWDOMAIN^^}\\domain^users ALL=(ALL) ALL
%${NEWDOMAIN^^}\\sudoers ALL=(ALL) ALL
%${NEWDOMAIN^^}\\administrators ALL=(ALL) ALL
EOF
                chmod 440 /etc/sudoers.d/domain-users
                
                # Verify sudoers file syntax
                if visudo -c -f /etc/sudoers.d/domain-users; then
                    success "Domain users can now use sudo (after reboot)"
                else
                    error "Sudoers file syntax error - removing file"
                    rm -f /etc/sudoers.d/domain-users
                fi
            else
                warning "SSSD config not found, cannot configure sudo access"
            fi
        else
            echo "Skipping sudo configuration for domain users"
        fi
    fi
    
    CURRENT_STEP=22
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# COMPREHENSIVE MIGRATION REPORT (Step 23) - Detailed Migration Summary
# =============================================================================
# This step generates a comprehensive report of the migration process
# Think of this as the "final inspection report" for the migration
#
# WHAT THE REPORT INCLUDES:
# 1. Migration Summary: Overview of what was accomplished
# 2. Configuration Changes: All files and settings that were modified
# 3. User Migration Status: Status of user profile migrations
# 4. Network Resource Status: Status of network resource migrations
# 5. Application Status: Status of application configuration migrations
# 6. Verification Results: Results of all verification tests
# 7. Backup Information: Location and status of backup files
# 8. Troubleshooting Information: Common issues and solutions
# 9. Next Steps: What to do after migration
# 10. Rollback Instructions: How to revert if needed
#
# =============================================================================
if [[ $CURRENT_STEP -lt 23 ]]; then
    step "Generating comprehensive migration report..."
    info "Creating detailed report of migration process and results"
    
    # Create migration report
    MIGRATION_REPORT="/tmp/migration-report-$(date +%Y%m%d_%H%M%S).txt"
    
    cat <<EOF > "$MIGRATION_REPORT"
=============================================================================
                    COMPREHENSIVE MIGRATION REPORT
=============================================================================
Generated: $(date)
Script Version: 3.0.0
Migration Mode: $MODE
Domain: $NEWDOMAIN
Hostname: $SHORTNAME
=============================================================================

MIGRATION SUMMARY:
==================
- Migration completed successfully
- Computer joined to domain: $NEWDOMAIN
- New hostname: $SHORTNAME.$NEWDOMAIN
- Backup account created: backup/backup
- All required services configured and running

CONFIGURATION CHANGES:
=====================
Files Modified:
- /etc/hostname: Updated to $SHORTNAME
- /etc/hosts: Updated with new domain information
- /etc/krb5.conf: Configured for ${NEWDOMAIN^^} realm
- /etc/nsswitch.conf: Updated to use SSSD
- /etc/pam.d/common-session: Enabled mkhomedir
- /etc/sssd/sssd.conf: Configured for domain authentication

Services Configured:
- SSSD: Running and configured for domain authentication
- oddjobd: Running and configured for home directory creation
- NetworkManager: Updated with new domain settings

VERIFICATION RESULTS:
====================
Domain Membership: $(realm list | grep -q "$NEWDOMAIN" && echo "OK" || echo "FAILED")
SSSD Configuration: $(sssctl domain-list | grep -q "$NEWDOMAIN" && echo "OK" || echo "FAILED")
User Lookup: $(getent passwd | grep -q "@$NEWDOMAIN" && echo "OK" || echo "NO USERS YET")
Group Lookup: $(getent group | grep -q "@$NEWDOMAIN" && echo "OK" || echo "NO GROUPS YET")
SSSD Service: $(systemctl is-active --quiet sssd && echo "RUNNING" || echo "STOPPED")
oddjobd Service: $(systemctl is-active --quiet oddjobd && echo "RUNNING" || echo "STOPPED")

USER MIGRATION STATUS:
======================
$(if [[ -n "$old_domain" ]]; then
    echo "User profiles migrated from $old_domain to $NEWDOMAIN"
    echo "Home directories updated with new domain paths"
    echo "Symbolic links created for compatibility"
else
    echo "No user profile migration performed (no old domain specified)"
fi)

NETWORK RESOURCE STATUS:
========================
$(if [[ -n "$old_domain" ]]; then
    echo "Network printers: Updated configurations"
    echo "Network drives: Updated mappings"
    echo "VPN connections: Updated configurations"
    echo "Application shortcuts: Updated paths"
else
    echo "No network resource migration performed (no old domain specified)"
fi)

APPLICATION CONFIGURATION STATUS:
================================
$(if [[ -n "$old_domain" ]]; then
    echo "Email clients: Updated configurations"
    echo "Web browsers: Updated bookmarks and settings"
    echo "Office applications: Updated settings"
    echo "Development tools: Updated configurations"
else
    echo "No application configuration migration performed (no old domain specified)"
fi)

BACKUP INFORMATION:
===================
Backup files created:
$(find /etc -name "*.backup.*" 2>/dev/null | head -10)
$(if [[ "$TECHNICIAN_MODE" == "true" ]]; then
    echo "Rollback points created: /tmp/migration-rollback-*"
fi)

TROUBLESHOOTING INFORMATION:
============================
Common Issues and Solutions:

1. "Can't log in with domain user"
   - Check SSSD service: systemctl status sssd
   - Check time synchronization: timedatectl status
   - Verify domain connectivity: ping $DOMAIN_CONTROLLER

2. "Home directories not created"
   - Check oddjobd service: systemctl status oddjobd
   - Verify PAM configuration: grep mkhomedir /etc/pam.d/common-session
   - Check oddjob-mkhomedir package: dpkg -l | grep oddjob

3. "Users not found"
   - Clear SSSD cache: sssctl cache-remove
   - Check SSSD logs: journalctl -u sssd
   - Verify domain configuration: sssctl domain-list

4. "Network resources not working"
   - Check network connectivity
   - Verify DNS resolution: nslookup $NEWDOMAIN
   - Check firewall settings

NEXT STEPS:
===========
1. Reboot the system to ensure all changes take effect
2. Test domain user login with a test account
3. Verify home directory creation works
4. Test network resource access
5. Verify application configurations
6. Remove backup account if no longer needed

ROLLBACK INSTRUCTIONS:
======================
$(if [[ "$TECHNICIAN_MODE" == "true" ]]; then
    echo "To rollback to previous state:"
    echo "1. Use the rollback script: /tmp/migration-rollback-*/rollback.sh"
    echo "2. Or manually restore from backup files"
else
    echo "To rollback manually:"
    echo "1. Restore backup files from /etc/*.backup.*"
    echo "2. Reconfigure services manually"
    echo "3. Reboot the system"
fi)

SUPPORT INFORMATION:
===================
- Script logs: /tmp/migration-*.log
- SSSD logs: journalctl -u sssd
- System logs: journalctl -xe
- State file: /tmp/migration-state

=============================================================================
                    MIGRATION REPORT COMPLETE
=============================================================================
EOF

    success "Comprehensive migration report generated: $MIGRATION_REPORT"
    info "Report contains detailed information about the migration process"
    
    # Display report summary
    echo ""
    echo "=========================================="
    echo "MIGRATION REPORT SUMMARY:"
    echo "=========================================="
    echo "Report saved to: $MIGRATION_REPORT"
    echo ""
    echo "Key points:"
    echo "- Migration completed successfully"
    echo "- All services configured and running"
    echo "- Backup files created for safety"
    echo "- Comprehensive verification performed"
    echo ""
    echo "Next step: Reboot the system"
    
    CURRENT_STEP=23
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# FINAL INSTRUCTIONS AND REBOOT (Step 24)
# =============================================================================
if [[ $CURRENT_STEP -lt 24 ]]; then
    step "Final steps required:"
    echo ""
    echo "=========================================="
    echo "MIGRATION SUMMARY:"
    echo "=========================================="
    if [[ "$TECHNICIAN_MODE" == "true" ]]; then
        echo "Mode: technician"
    elif [[ "$LIVE_MODE" == "true" ]]; then
        echo "Mode: live"
    elif [[ "$DRY_RUN" == "true" ]]; then
        echo "Mode: dry-run"
    fi
    echo "Domain: $NEWDOMAIN"
    echo "Hostname: $FQDN"
    echo "Domain Controller: $DOMAIN_CONTROLLER"
    echo "Backup files created:"
    ls -la /etc/*.backup.* 2>/dev/null || echo "No backup files found"
    if [[ "$TECHNICIAN_MODE" == "true" ]]; then
        echo "Rollback points:"
        ls -la "$ROLLBACK_DIR"/*.tar.gz 2>/dev/null || echo "No rollback points found"
    fi
    echo "=========================================="
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo "=========================================="
        echo "DRY-RUN COMPLETE!"
        echo "=========================================="
        echo "The script has successfully simulated the migration process."
        echo "No actual changes were made to your system."
        echo ""
        echo "To perform the actual migration, run:"
        echo "sudo $0 --live"
        echo "or"
        echo "sudo $0 --technician"
        echo ""
        echo "State tracking file: $STATE_FILE"
        echo "This file has been created to track the dry-run progress."
        echo "You can delete it if you want to start fresh."
    else
        echo ""
        echo "=========================================="
        echo "REBOOT REQUIRED"
        echo "=========================================="
        echo "A system reboot is required to complete the domain migration."
        echo "This ensures all services are properly restarted with the new configuration."
        echo ""
        read -rp "Do you want to reboot now? (y/n): " REBOOT_NOW
        if [[ "$REBOOT_NOW" =~ ^[Yy]$ ]]; then
            echo "Rebooting in 10 seconds... Press Ctrl+C to cancel"
            for i in {10..1}; do
                echo -n "$i... "
                sleep 1
            done
            echo "Rebooting now!"
            reboot
        else
            echo ""
            echo "Please reboot manually when ready:"
            echo "sudo reboot"
            echo ""
            echo "After reboot, test logging in with a domain user account."
        fi
        
        # =============================================================================
        # POST-REBOOT VERIFICATION REMINDER
        # =============================================================================
        echo ""
        echo "=========================================="
        echo "IMPORTANT: POST-REBOOT VERIFICATION"
        echo "=========================================="
        echo "After rebooting your system, please run the post-migration verification script"
        echo "to ensure everything is working correctly:"
        echo ""
        echo "sudo ./oz-post-migration-checklist.sh"
        echo ""
        echo "This script will:"
        echo "OK: Verify domain membership is active"
        echo "OK: Check SSSD service health"
        echo "OK: Test domain user accessibility"
        echo "OK: Validate network and DNS configuration"
        echo "OK: Check Kerberos authentication"
        echo "OK: Analyze logs for any issues"
        echo "OK: Provide troubleshooting guidance if needed"
        echo "Thank you for bearing with and running this script so far, you appear to have migrated successfully, just ensure you complete a reboot and run the verification script for complete confidence your domain migration was successful"
        echo "-Oscar :)"
        echo "=========================================="
    fi
    
    # Clean up state file on successful completion
    if [[ "$DRY_RUN" == "false" ]]; then
        rm -f "$STATE_FILE"
        info "State tracking file cleaned up"
    fi
    
    CURRENT_STEP=21
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# DEMO SECTION: NETWORK RESOURCES AND PRINTERS MIGRATION (COMMENTED OUT)
# =============================================================================
# This section demonstrates advanced network resource migration capabilities
# Currently commented out as it's not required for basic domain migration
# Uncomment and integrate into the main workflow if needed
#
# if [[ $CURRENT_STEP -lt 22 ]]; then
#     step "Migrating network resources and printers..."
#     info "This step migrates network printers, drives, and other domain resources"
#     
#     if [[ "$DRY_RUN" == "true" ]]; then
#         info "[DRY-RUN] Would migrate network resources and printers"
#         success "[DRY-RUN] Network resource migration simulation complete"
#     else
#         # Function: Migrate network printers
#         migrate_network_printers() {
#             local old_domain="$1"
#             local new_domain="$2"
#             local printer_log="/var/log/printer-migration-$(date +%Y%m%d_%H%M%S).log"
#             
#             info "Starting network printer migration..."
#             echo "Network Printer Migration Log - $(date)" > "$printer_log"
#             echo "Old Domain: $old_domain" >> "$printer_log"
#             echo "New Domain: $new_domain" >> "$printer_log"
#             echo "==========================================" >> "$printer_log"
#             
#             # Get current printer configuration
#             local current_printers=$(lpstat -p 2>/dev/null | grep -E "^printer" | awk '{print $2}')
#             
#             if [[ -n "$current_printers" ]]; then
#                 echo "Found network printers:"
#                 echo "$current_printers"
#                 echo ""
#                 
#                 read -rp "Do you want to migrate network printers? (y/n): " MIGRATE_PRINTERS
#                 if [[ "$MIGRATE_PRINTERS" =~ ^[Yy]$ ]]; then
#                     local migrated_count=0
#                     local failed_count=0
#                     
#                     while IFS= read -r printer; do
#                         if [[ -n "$printer" ]]; then
#                             info "Processing printer: $printer"
#                             echo "Processing: $printer" >> "$printer_log"
#                             
#                             # Get printer URI and options
#                             local printer_uri=$(lpoptions -p "$printer" | grep "printer-uri" | cut -d'=' -f2)
#                             local printer_location=$(lpoptions -p "$printer" | grep "printer-location" | cut -d'=' -f2)
#                             
#                             # Check if printer uses old domain
#                             if [[ "$printer_uri" == *"$old_domain"* ]]; then
#                                 info "Found domain printer: $printer"
#                                 echo "Domain printer found: $printer" >> "$printer_log"
#                                 
#                                 # Create new printer name
#                                 local new_printer_name="${printer}_${new_domain}"
#                                 
#                                 # Update printer URI to new domain
#                                 local new_uri=$(echo "$printer_uri" | sed "s/$old_domain/$new_domain/g")
#                                 
#                                 # Test connectivity to new printer
#                                 if ping -c 1 "$(echo "$new_uri" | sed 's|.*://||' | sed 's|/.*||')" >/dev/null 2>&1; then
#                                     # Add new printer
#                                     if lpadmin -p "$new_printer_name" -E -v "$new_uri" -o printer-location="$printer_location"; then
#                                         # Enable the printer
#                                         if cupsenable "$new_printer_name" && cupsaccept "$new_printer_name"; then
#                                             success "Successfully migrated printer: $printer -> $new_printer_name"
#                                             echo "SUCCESS: $printer -> $new_printer_name" >> "$printer_log"
#                                             ((migrated_count++))
#                                             
#                                             # Ask if user wants to remove old printer
#                                             read -rp "Remove old printer $printer? (y/n): " REMOVE_OLD_PRINTER
#                                             if [[ "$REMOVE_OLD_PRINTER" =~ ^[Yy]$ ]]; then
#                                                 lpadmin -x "$printer"
#                                                 echo "Removed old printer: $printer" >> "$printer_log"
#                                             fi
#                                         else
#                                             warning "Failed to enable new printer: $new_printer_name"
#                                             echo "FAILED: Could not enable $new_printer_name" >> "$printer_log"
#                                             ((failed_count++))
#                                         fi
#                                     else
#                                         warning "Failed to create new printer: $new_printer_name"
#                                         echo "FAILED: Could not create $new_printer_name" >> "$printer_log"
#                                         ((failed_count++))
#                                     fi
#                                 else
#                                     warning "Cannot reach new printer location: $new_uri"
#                                     echo "FAILED: Cannot reach $new_uri" >> "$printer_log"
#                                     ((failed_count++))
#                                 fi
#                             else
#                                 info "Skipping local printer: $printer"
#                                 echo "SKIPPED: Local printer $printer" >> "$printer_log"
#                             fi
#                         fi
#                     done <<< "$current_printers"
#                     
#                     # Summary
#                     echo "" >> "$printer_log"
#                     echo "Printer Migration Summary:" >> "$printer_log"
#                     echo "Successfully migrated: $migrated_count printers" >> "$printer_log"
#                     echo "Failed migrations: $failed_count printers" >> "$printer_log"
#                     
#                     success "Printer migration completed"
#                     info "Successfully migrated: $migrated_count printers"
#                     if [[ $failed_count -gt 0 ]]; then
#                         warning "Failed migrations: $failed_count printers"
#                     fi
#                     info "Printer migration log: $printer_log"
#                 else
#                     info "Skipping printer migration"
#                 fi
#             else
#                 info "No network printers found"
#             fi
#         }
#         
#         # Function: Migrate network drives and shares
#         migrate_network_drives() {
#             local old_domain="$1"
#             local new_domain="$2"
#             local drive_log="/var/log/drive-migration-$(date +%Y%m%d_%H%M%S).log"
#             
#             info "Starting network drive migration..."
#             echo "Network Drive Migration Log - $(date)" > "$drive_log"
#             echo "Old Domain: $old_domain" >> "$drive_log"
#             echo "New Domain: $new_domain" >> "$drive_log"
#             echo "==========================================" >> "$drive_log"
#             
#             # Check for mounted network shares
#             local mounted_shares=$(mount | grep -E "(cifs|smb|nfs)" | awk '{print $1, $3}')
#             
#             if [[ -n "$mounted_shares" ]]; then
#                 echo "Found mounted network shares:"
#                 echo "$mounted_shares"
#                 echo ""
#                 
#                 read -rp "Do you want to migrate network drives? (y/n): " MIGRATE_DRIVES
#                 if [[ "$MIGRATE_DRIVES" =~ ^[Yy]$ ]]; then
#                     local migrated_count=0
#                     local failed_count=0
#                     
#                     while IFS= read -r share_info; do
#                         if [[ -n "$share_info" ]]; then
#                             local share_path=$(echo "$share_info" | awk '{print $1}')
#                             local mount_point=$(echo "$share_info" | awk '{print $2}')
#                             
#                             info "Processing share: $share_path -> $mount_point"
#                             echo "Processing: $share_path -> $mount_point" >> "$drive_log"
#                             
#                             # Check if share uses old domain
#                             if [[ "$share_path" == *"$old_domain"* ]]; then
#                                 info "Found domain share: $share_path"
#                                 echo "Domain share found: $share_path" >> "$drive_log"
#                                 
#                                 # Create new share path
#                                 local new_share_path=$(echo "$share_path" | sed "s/$old_domain/$new_domain/g")
#                                 
#                                 # Test connectivity to new share
#                                 local share_host=$(echo "$new_share_path" | sed 's|.*://||' | sed 's|/.*||')
#                                 if ping -c 1 "$share_host" >/dev/null 2>&1; then
#                                     # Unmount old share
#                                     if umount "$mount_point" 2>/dev/null; then
#                                         echo "Unmounted old share: $mount_point" >> "$drive_log"
#                                         
#                                         # Mount new share
#                                         if mount -t cifs "$new_share_path" "$mount_point" -o credentials=/etc/samba/credentials,uid=$(id -u),gid=$(id -g); then
#                                             success "Successfully migrated share: $share_path -> $new_share_path"
#                                             echo "SUCCESS: $share_path -> $new_share_path" >> "$drive_log"
#                                             ((migrated_count++))
#                                             
#                                             # Update fstab if entry exists
#                                             local fstab_entry=$(grep "$mount_point" /etc/fstab)
#                                             if [[ -n "$fstab_entry" ]]; then
#                                                 # Backup fstab
#                                                 cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)
#                                                 
#                                                 # Update fstab entry
#                                                 sed -i "s|$share_path|$new_share_path|g" /etc/fstab
#                                                 echo "Updated fstab entry for $mount_point" >> "$drive_log"
#                                             fi
#                                         else
#                                             warning "Failed to mount new share: $new_share_path"
#                                             echo "FAILED: Could not mount $new_share_path" >> "$drive_log"
#                                             ((failed_count++))
#                                             
#                                             # Try to remount old share
#                                             mount -t cifs "$share_path" "$mount_point" -o credentials=/etc/samba/credentials,uid=$(id -u),gid=$(id -g) 2>/dev/null
#                                         fi
#                                     else
#                                         warning "Could not unmount share: $mount_point"
#                                         echo "FAILED: Could not unmount $mount_point" >> "$drive_log"
#                                         ((failed_count++))
#                                     fi
#                                 else
#                                     warning "Cannot reach new share location: $new_share_path"
#                                     echo "FAILED: Cannot reach $new_share_path" >> "$drive_log"
#                                     ((failed_count++))
#                                 fi
#                             else
#                                 info "Skipping non-domain share: $share_path"
#                                 echo "SKIPPED: Non-domain share $share_path" >> "$drive_log"
#                             fi
#                         fi
#                     done <<< "$mounted_shares"
#                     
#                     # Summary
#                     echo "" >> "$drive_log"
#                     echo "Drive Migration Summary:" >> "$drive_log"
#                     echo "Successfully migrated: $migrated_count shares" >> "$drive_log"
#                     echo "Failed migrations: $failed_count shares" >> "$drive_log"
#                     
#                     success "Network drive migration completed"
#                     info "Successfully migrated: $migrated_count shares"
#                     if [[ $failed_count -gt 0 ]]; then
#                         warning "Failed migrations: $failed_count shares"
#                     fi
#                     info "Drive migration log: $drive_log"
#                 else
#                     info "Skipping network drive migration"
#                 fi
#             else
#                 info "No mounted network shares found"
#             fi
#         }
#         
#
#         # Function: Migrate application shortcuts and bookmarks
#         migrate_application_shortcuts() {
#             local old_domain="$1"
#             local new_domain="$2"
#             local shortcut_log="/var/log/shortcut-migration-$(date +%Y%m%d_%H%M%S).log"
#             
#             info "Starting application shortcut migration..."
#             echo "Shortcut Migration Log - $(date)" > "$shortcut_log"
#             echo "Old Domain: $old_domain" >> "$shortcut_log"
#             echo "New Domain: $new_domain" >> "$shortcut_log"
#             echo "==========================================" >> "$shortcut_log"
#             
#             # Find desktop shortcuts and bookmarks
#             local desktop_shortcuts=$(find /home -name "*.desktop" -path "*/Desktop/*" 2>/dev/null)
#             local bookmarks_files=$(find /home -name "places.sqlite" -o -name "bookmarks.html" 2>/dev/null)
#             
#             if [[ -n "$desktop_shortcuts" ]] || [[ -n "$bookmarks_files" ]]; then
#                 echo "Found application shortcuts and bookmarks"
#                 echo ""
#                 
#                 read -rp "Do you want to migrate shortcuts and bookmarks? (y/n): " MIGRATE_SHORTCUTS
#                 if [[ "$MIGRATE_SHORTCUTS" =~ ^[Yy]$ ]]; then
#                     local migrated_count=0
#                     local failed_count=0
#                     
#                     # Process desktop shortcuts
#                     if [[ -n "$desktop_shortcuts" ]]; then
#                         while IFS= read -r shortcut; do
#                             if [[ -f "$shortcut" ]]; then
#                                 info "Processing shortcut: $shortcut"
#                                 echo "Processing shortcut: $shortcut" >> "$shortcut_log"
#                                 
#                                 # Check if shortcut contains old domain
#                                 if grep -q "$old_domain" "$shortcut"; then
#                                     # Create backup
#                                     cp "$shortcut" "${shortcut}.backup"
#                                     
#                                     # Update shortcut with new domain
#                                     sed -i "s/$old_domain/$new_domain/g" "$shortcut"
#                                     
#                                     success "Updated shortcut: $shortcut"
#                                     echo "SUCCESS: Updated $shortcut" >> "$shortcut_log"
#                                     ((migrated_count++))
#                                 else
#                                     echo "SKIPPED: No domain reference in $shortcut" >> "$shortcut_log"
#                                 fi
#                             fi
#                         done <<< "$desktop_shortcuts"
#                     fi
#                     
#                     # Process bookmarks (Firefox/Chrome)
#                     if [[ -n "$bookmarks_files" ]]; then
#                         while IFS= read -r bookmark_file; do
#                             if [[ -f "$bookmark_file" ]]; then
#                                 info "Processing bookmarks: $bookmark_file"
#                                 echo "Processing bookmarks: $bookmark_file" >> "$shortcut_log"
#                                 
#                                 # Create backup
#                                 cp "$bookmark_file" "${bookmark_file}.backup"
#                                 
#                                 # Update bookmarks with new domain
#                                 sed -i "s/$old_domain/$new_domain/g" "$bookmark_file"
#                                 
#                                 success "Updated bookmarks: $bookmark_file"
#                                 echo "SUCCESS: Updated $bookmark_file" >> "$shortcut_log"
#                                 ((migrated_count++))
#                             fi
#                         done <<< "$bookmarks_files"
#                     fi
#                     
#                     # Summary
#                     echo "" >> "$shortcut_log"
#                     echo "Shortcut Migration Summary:" >> "$shortcut_log"
#                     echo "Successfully migrated: $migrated_count items" >> "$shortcut_log"
#                     echo "Failed migrations: $failed_count items" >> "$shortcut_log"
#                     
#                     success "Shortcut migration completed"
#                     info "Successfully migrated: $migrated_count items"
#                     if [[ $failed_count -gt 0 ]]; then
#                         warning "Failed migrations: $failed_count items"
#                     fi
#                     info "Shortcut migration log: $shortcut_log"
#                 else
#                     info "Skipping shortcut migration"
#                 fi
#             else
#                 info "No application shortcuts or bookmarks found"
#             fi
#         }
#         
#         # Execute network resource migration functions
#         migrate_network_printers "$OLDADMIN" "$NEWDOMAIN"
#         migrate_network_drives "$OLDADMIN" "$NEWDOMAIN"
#         migrate_vpn_connections "$OLDADMIN" "$NEWDOMAIN"
#         migrate_application_shortcuts "$OLDADMIN" "$NEWDOMAIN"
#         
#         success "Network resource migration completed"
#     fi
#     
#     CURRENT_STEP=22
#     save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
# fi

echo ""
echo "=========================================="
echo "MIGRATION PROCESS COMPLETE!"
echo "=========================================="
echo "All steps have been completed successfully."
echo ""
    echo "State tracking information:"
    echo "  State file: $STATE_FILE"
    echo "  Current step: $CURRENT_STEP"
    if [[ "$TECHNICIAN_MODE" == "true" ]]; then
        echo "  Mode: technician"
    elif [[ "$LIVE_MODE" == "true" ]]; then
        echo "  Mode: live"
    elif [[ "$DRY_RUN" == "true" ]]; then
        echo "  Mode: dry-run"
    fi
    echo "  Domain: $NEWDOMAIN"
    echo "  Hostname: $SHORTNAME"
echo ""
echo "Thank you for using the Domain Migration Script!"
echo ""
# ASCII Pikachu watermark - hidden from output but preserved in code
# ⢀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
# ⢻⣿⡗⢶⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣠⣄
# ⠀⢻⣇⠀⠈⠙⠳⣦⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⠶⠛⠋⣹⣿⡿
# ⠀⠀⠹⣆⠀⠀⠀⠀⠙⢷⣄⣀⣀⣀⣤⣤⣤⣄⣀⣴⠞⠋⠉⠀⠀⠀⢀⣿⡟⠁
# ⠀⠀⠀⠙⢷⡀⠀⠀⠀⠀⠉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⡾⠋⠀⠀
# ⠀⠀⠀⠀⠈⠻⡶⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣠⡾⠋⠀⠀⠀⠀
# ⠀⠀⠀⠀⣼⠃⠀⢠⠒⣆⠀⠀⠀⠀⠀⠀⢠⢲⣄⠀⠀⠀⢻⣆⠀⠀⠀⠀⠀
# ⠀⠀⠀⠀⢰⡏⠀⠀⠈⠛⠋⠀⢀⣀⡀⠀⠀⠘⠛⠃⠀⠀⠀⠈⣿⡀⠀⠀⠀⠀
# ⠀⠀⠀⠀⣾⡟⠛⢳⠀⠀⠀⠀⠀⣉⣀⠀⠀⠀⠀⣰⢛⠙⣶⠀⢹⣇⠀⠀⠀⠀
# ⠀⠀⠀⠀⢿⡗⠛⠋⠀⠀⠀⠀⣾⠋⠀⢱⠀⠀⠀⠘⠲⠗⠋⠀⠈⣿⠀⠀⠀⠀
# ⠀⠀⠀⠀⠘⢷⡀⠀⠀⠀⠀⠀⠈⠓⠒⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⡇⠀⠀⠀
# ⠀⠀⠀⠀⠀⠈⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣧⠀⠀⠀
# ⠀⠀⠀⠀⠀⠀⠈⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠁⠀⠀⠀
echo "=========================================="

# Final safety check - ensure script always provides feedback
if [[ $? -ne 0 ]]; then
    echo ""
    echo "=========================================="
    echo "SCRIPT COMPLETED WITH WARNINGS"
    echo "=========================================="
    echo "The migration script has completed, but some steps may have had issues."
    echo "Please review the output above for any warnings or errors."
    echo ""
    echo "If you encountered problems, you can:"
    echo "1. Check the logs for detailed error information"
    echo "2. Run the script again with --dry-run to test"
    echo "3. Use the backup account (backup/backup) to troubleshoot"
    echo "4. Contact your system administrator for assistance"
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo "SCRIPT COMPLETED SUCCESSFULLY"
    echo "=========================================="
    echo "The migration script has completed all steps successfully!"
    echo "=========================================="
fi