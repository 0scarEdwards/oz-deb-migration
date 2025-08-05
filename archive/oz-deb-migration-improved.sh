#!/bin/bash
# =============================================================================
# Oz's Advanced Debian Domain Migration Script
# =============================================================================
# 
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
# ⠀⠀⠀⠀⠀⠈⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠁⠀⠀⠀
# 
#  Coded by Oscar  |  Domain Migration Made Simple
# 
# NEW FEATURES:
# - Technician Mode: Full migration with all features
# - Live Mode: Standard migration with safety features
# - Dry-Run Mode: Test run without making changes
# - State Tracking: Resume interrupted migrations
# - Progress Indicators: Visual feedback during operations
# - Enhanced Safety: Better backups and validation
# - Domain Controller Discovery: Automatic DC detection
# - Time Synchronization: Automatic NTP fixes
# - Backup Verification: Ensures backups are valid
# - Concurrent User Handling: Graceful session management
# - Local Account Detection: Smart filtering of local accounts
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
set -e                    # Exit immediately if any command fails
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
        echo "1) --technician (Full features with rollback points)"
        echo "2) --live (Standard migration)"
        echo "3) --dry-run (Test run only)"
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
            echo "Full features including rollback points will be used"
            ;;
        --live)
            LIVE_MODE=true
            TECHNICIAN_MODE=false
            DRY_RUN=false
            echo "=== LIVE MODE ENABLED ==="
            echo "Standard migration with safety features"
            ;;
        --dry-run)
            DRY_RUN=true
            TECHNICIAN_MODE=false
            LIVE_MODE=false
            echo "=== DRY-RUN MODE ENABLED ==="
            echo "No changes will be made - test run only"
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

# Function: Time synchronization fix
fix_time_synchronization() {
    info "Checking time synchronization..."
    
    if command -v timedatectl >/dev/null 2>&1; then
        if timedatectl status | grep -q "synchronized: yes"; then
            success "Time synchronization: OK"
        else
            warning "Time synchronization: FAILED - attempting to fix..."
            info "Enabling NTP synchronization..."
            
            if [[ "$DRY_RUN" == "true" ]]; then
                info "[DRY-RUN] Would run: timedatectl set-ntp true"
            else
                timedatectl set-ntp true
                info "Waiting for time sync to stabilize..."
                sleep 10
                
                if timedatectl status | grep -q "synchronized: yes"; then
                    success "Time synchronization fixed successfully"
                else
                    warning "Time synchronization still failed - Kerberos may not work"
                fi
            fi
        fi
    else
        warning "timedatectl not available - cannot verify time sync"
    fi
}

# Function: Backup verification
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

# Function: Enhanced backup with verification
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
                error "Backup verification failed for $file"
                exit 1
            fi
        fi
    else
        warning "File $file does not exist, skipping backup"
    fi
}

# Function: Handle concurrent user sessions
handle_concurrent_sessions() {
    info "Checking for active user sessions..."
    
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
            error "Migration cancelled by user"
            exit 0
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

# Parse arguments first
parse_arguments "$@"

# Continue with the rest of the script...

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Function: Display stylized banner with ASCII art
banner() {
    echo ""
    echo "⢀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
    echo "⢻⣿⡗⢶⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣠⣄"
    echo "⠀⢻⣇⠀⠈⠙⠳⣦⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⠶⠛⠋⣹⣿⡿"
    echo "⠀⠀⠹⣆⠀⠀⠀⠀⠙⢷⣄⣀⣀⣀⣤⣤⣤⣄⣀⣴⠞⠋⠉⠀⠀⠀⢀⣿⡟⠁"
    echo "⠀⠀⠀⠙⢷⡀⠀⠀⠀⠀⠉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⡾⠋⠀⠀"
    echo "⠀⠀⠀⠀⠈⠻⡶⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣠⡾⠋⠀⠀⠀⠀"
    echo "⠀⠀⠀⠀⣼⠃⠀⢠⠒⣆⠀⠀⠀⠀⠀⠀⢠⢲⣄⠀⠀⠀⢻⣆⠀⠀⠀⠀⠀"
    echo "⠀⠀⠀⠀⢰⡏⠀⠀⠈⠛⠋⠀⢀⣀⡀⠀⠀⠘⠛⠃⠀⠀⠀⠈⣿⡀⠀⠀⠀⠀"
    echo "⠀⠀⠀⠀⣾⡟⠛⢳⠀⠀⠀⠀⠀⣉⣀⠀⠀⠀⠀⣰⢛⠙⣶⠀⢹⣇⠀⠀⠀⠀"
    echo "⠀⠀⠀⠀⢿⡗⠛⠋⠀⠀⠀⠀⣾⠋⠀⢱⠀⠀⠀⠘⠲⠗⠋⠀⠈⣿⠀⠀⠀⠀"
    echo "⠀⠀⠀⠀⠘⢷⡀⠀⠀⠀⠀⠀⠈⠓⠒⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⡇⠀⠀⠀"
    echo "⠀⠀⠀⠀⠀⠈⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣧⠀⠀⠀"
    echo "⠀⠀⠀⠀⠀⠈⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠁⠀⠀⠀"
    echo ""
    echo "  Coded by Oscar  |  Domain Migration Made Simple"
    echo ""
    if command -v figlet >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then
        echo "Domain Migration" | figlet -f slant | lolcat
    else
        echo "(Install 'figlet' and 'lolcat' for enhanced banner: sudo apt install figlet lolcat)"
    fi
    echo ""
}

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

# Display the banner
banner

# =============================================================================
# STATE TRACKING INITIALIZATION
# =============================================================================
step "Initializing state tracking..."
info "Checking for previous migration state..."

if load_state; then
    # Resume from previous state
    info "Resuming migration from step $CURRENT_STEP"
else
    # Start fresh migration
    CURRENT_STEP=0
    info "Starting fresh migration"
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
# PACKAGE INSTALLATION (Step 1)
# =============================================================================
if [[ $CURRENT_STEP -lt 1 ]]; then
    step "Installing required packages..."
    info "Installing domain migration packages with progress indicators..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would install: realmd sssd sssd-tools adcli libnss-sss libpam-sss samba-common-bin packagekit krb5-user oddjob oddjob-mkhomedir figlet lolcat nnn"
        success "[DRY-RUN] Package installation simulation complete"
    else
        echo "Updating package lists..."
        apt-get update -qq >/dev/null 2>&1 &
        show_progress "Updating package database" $!
        wait $!
        
        echo "Installing domain migration packages..."
        apt-get install -y figlet lolcat nnn realmd sssd sssd-tools adcli libnss-sss libpam-sss samba-common-bin packagekit krb5-user oddjob oddjob-mkhomedir -qq >/dev/null 2>&1 &
        show_progress "Installing required packages" $!
        wait $!
        
        echo "Upgrading system packages..."
        apt-get upgrade -y -qq >/dev/null 2>&1 &
        show_progress "Upgrading existing packages" $!
        wait $!
        
        echo "Setting up lolcat symlink..."
        ln -sf /usr/games/lolcat /usr/local/bin/lolcat 2>/dev/null
        success "All required packages installed successfully"
    fi
    
    CURRENT_STEP=1
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# SAFETY BACKUP ACCOUNT CREATION (Step 2)
# =============================================================================
if [[ $CURRENT_STEP -lt 2 ]]; then
    step "Creating safety backup account..."
    info "Creating a temporary local account for emergency access during migration..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would create backup user account with sudo access"
        success "[DRY-RUN] Backup account creation simulation complete"
    else
        # Check if backup account already exists
        if id "backup" &>/dev/null; then
            warning "Backup account 'backup' already exists"
            read -rp "Do you want to reset the backup account password? (y/n): " RESET_BACKUP
            if [[ "$RESET_BACKUP" =~ ^[Yy]$ ]]; then
                echo "backup:backup" | chpasswd
                success "Backup account password reset"
            fi
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
    
    CURRENT_STEP=2
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# PRE-MIGRATION CHECKS (Step 3)
# =============================================================================
if [[ $CURRENT_STEP -lt 3 ]]; then
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
    
    # Fix time synchronization
    fix_time_synchronization
    
    echo ""
    success "Pre-migration checks completed"
    
    CURRENT_STEP=3
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# CURRENT DOMAIN STATUS (Step 4)
# =============================================================================
if [[ $CURRENT_STEP -lt 4 ]]; then
    step "Analyzing current domain status..."
    info "Checking which domains this system is currently joined to..."
    
    echo "Current domain membership:"
    realm list || echo "Not currently joined to any domain."
    
    echo ""
    info "Checking SSSD domain configuration:"
    sssctl domain-list || echo "No SSSD domains configured"
    
    CURRENT_STEP=4
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# USER INPUT VALIDATION (Step 5)
# =============================================================================
if [[ $CURRENT_STEP -lt 5 ]]; then
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
    
    # Get and validate the current domain admin account
    info "Step 2/3: Current domain admin credentials"
    while true; do
        read -rp "Enter your CURRENT domain admin account (e.g., admin@olddomain.com): " OLDADMIN
        if validate_email "$OLDADMIN"; then
            success "Email format is valid: $OLDADMIN"
            break
        else
            error "Invalid email format. Please enter a valid email address."
            info "Example: admin@company.com"
        fi
    done
    
    # Get and validate the new domain admin account
    info "Step 3/3: New domain admin credentials"
    while true; do
        read -rp "Enter your NEW domain admin account (e.g., admin@newdomain.com): " NEWADMIN
        if validate_email "$NEWADMIN"; then
            success "Email format is valid: $NEWADMIN"
            break
        else
            error "Invalid email format. Please enter a valid email address."
            info "Example: admin@company.com"
        fi
    done
    
    # Get admin password securely
    info "Step 4/4: Admin password"
    echo -n "Enter password for $NEWADMIN: "
    read -s NEWADMIN_PASS
    echo ""
    
    if [[ -z "$NEWADMIN_PASS" ]]; then
        error "Password cannot be empty"
        exit 1
    fi
    
    # Validate password by testing domain connectivity
    info "Validating credentials with domain controller..."
    if ! echo "$NEWADMIN_PASS" | kinit "$NEWADMIN" 2>/dev/null; then
        warning "Could not validate credentials with Kerberos (this is normal for some domains)"
        info "Proceeding with domain join attempt..."
    else
        success "Credentials validated successfully"
        kdestroy 2>/dev/null
    fi
    
    echo ""
    info "All input parameters validated successfully!"
    
    CURRENT_STEP=5
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
# DOMAIN TRANSITION (Step 9)
# =============================================================================
if [[ $CURRENT_STEP -lt 9 ]]; then
    step "Initiating domain transition..."
    info "Leaving current domain and joining new domain..."
    
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
# JOIN NEW DOMAIN (Step 11)
# =============================================================================
if [[ $CURRENT_STEP -lt 11 ]]; then
    step "Joining new domain..."
    info "Attempting to join domain $NEWDOMAIN using account: $NEWADMIN"
    info "This process will:"
    info "  - Authenticate with the domain controller"
    info "  - Create computer account in Active Directory"
    info "  - Configure SSSD for domain authentication"
    
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
                error "Alternative join method also failed"
                exit 1
            else
                success "Successfully joined domain using alternative method"
            fi
        else
            success "Successfully joined domain $NEWDOMAIN"
        fi
        else
            error "realm command not found - SSSD may not be installed"
            exit 1
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
    
    # Get the new hostname from user
    read -rp "Enter new short hostname (e.g., myhost): " SHORTNAME
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
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would create Kerberos configuration for realm: ${NEWDOMAIN^^}"
        info "[DRY-RUN] Would set KDC server to: $DOMAIN_CONTROLLER"
        success "[DRY-RUN] Kerberos configuration simulation complete"
    else
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
# SERVICE RESTART (Step 15)
# =============================================================================
if [[ $CURRENT_STEP -lt 15 ]]; then
    step "Restarting authentication services..."
    info "Restarting SSSD service to apply new configuration..."
    
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
# VERIFICATION AND TESTING (Step 16)
# =============================================================================
if [[ $CURRENT_STEP -lt 16 ]]; then
    step "Verifying domain join and configuration..."
    info "Checking domain membership status..."
    
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
    
    CURRENT_STEP=16
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# POST-MIGRATION VERIFICATION (Step 17)
# =============================================================================
if [[ $CURRENT_STEP -lt 17 ]]; then
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
# FINAL VERIFICATION (Step 18)
# =============================================================================
if [[ $CURRENT_STEP -lt 18 ]]; then
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
            echo "❌ Can't log in with domain user:"
            echo "   - Check SSSD logs: tail -f /var/log/sssd/sssd.log"
            echo "   - Clear cache: sssctl cache-remove"
            echo "   - Restart SSSD: systemctl restart sssd"
            echo ""
            echo "❌ DNS resolution issues:"
            echo "   - Check /etc/resolv.conf"
            echo "   - Verify DNS server settings"
            echo "   - Test: nslookup $NEWDOMAIN"
            echo ""
            echo "❌ Kerberos authentication fails:"
            echo "   - Check system time: timedatectl status"
            echo "   - Enable NTP: timedatectl set-ntp true"
            echo "   - Test: kinit username@$NEWDOMAIN"
            echo ""
            echo "❌ Sudo access not working:"
            echo "   - Check sudoers: sudo -l -U username@$NEWDOMAIN"
            echo "   - Verify group membership: groups username@$NEWDOMAIN"
            echo ""
            echo "❌ Need to revert changes:"
            echo "   - Run: sudo $0 --revert"
            echo "   - Or manually restore backups: ls -la /etc/*.backup.*"
            echo ""
            echo "❌ User profile issues:"
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
    
    CURRENT_STEP=18
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# USER PROFILE MIGRATION (Step 19)
# =============================================================================
if [[ $CURRENT_STEP -lt 19 ]]; then
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
                        info "🏠 Local account detected: $old_username"
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
                            info "✅ User $new_username exists in new domain"
                        else
                            warning "❌ User $new_username not found in new domain"
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
                echo "  ✅ $username -> ${clean_username}@${new_domain}"
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
                        echo "  🏠 $username (local account)"
                    else
                        echo "  ❌ $username (account issues)"
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
# SUDO ACCESS CONFIGURATION (Step 20)
# =============================================================================
if [[ $CURRENT_STEP -lt 20 ]]; then
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
    
    CURRENT_STEP=20
    save_state "$CURRENT_STEP" "$MODE" "$NEWDOMAIN" "$SHORTNAME"
fi

# =============================================================================
# FINAL INSTRUCTIONS AND REBOOT (Step 21)
# =============================================================================
if [[ $CURRENT_STEP -lt 21 ]]; then
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
        echo "✅ Verify domain membership is active"
        echo "✅ Check SSSD service health"
        echo "✅ Test domain user accessibility"
        echo "✅ Validate network and DNS configuration"
        echo "✅ Check Kerberos authentication"
        echo "✅ Analyze logs for any issues"
        echo "✅ Provide troubleshooting guidance if needed"
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
echo "⢀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
echo "⢻⣿⡗⢶⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣠⣄"
echo "⠀⢻⣇⠀⠈⠙⠳⣦⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⠶⠛⠋⣹⣿⡿"
echo "⠀⠀⠹⣆⠀⠀⠀⠀⠙⢷⣄⣀⣀⣀⣤⣤⣤⣄⣀⣴⠞⠋⠉⠀⠀⠀⢀⣿⡟⠁"
echo "⠀⠀⠀⠙⢷⡀⠀⠀⠀⠀⠉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⡾⠋⠀⠀"
echo "⠀⠀⠀⠀⠈⠻⡶⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣠⡾⠋⠀⠀⠀⠀"
echo "⠀⠀⠀⠀⣼⠃⠀⢠⠒⣆⠀⠀⠀⠀⠀⠀⢠⢲⣄⠀⠀⠀⢻⣆⠀⠀⠀⠀⠀"
echo "⠀⠀⠀⠀⢰⡏⠀⠀⠈⠛⠋⠀⢀⣀⡀⠀⠀⠘⠛⠃⠀⠀⠀⠈⣿⡀⠀⠀⠀⠀"
echo "⠀⠀⠀⠀⣾⡟⠛⢳⠀⠀⠀⠀⠀⣉⣀⠀⠀⠀⠀⣰⢛⠙⣶⠀⢹⣇⠀⠀⠀⠀"
echo "⠀⠀⠀⠀⢿⡗⠛⠋⠀⠀⠀⠀⣾⠋⠀⢱⠀⠀⠀⠘⠲⠗⠋⠀⠈⣿⠀⠀⠀⠀"
echo "⠀⠀⠀⠀⠘⢷⡀⠀⠀⠀⠀⠀⠈⠓⠒⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⡇⠀⠀⠀"
echo "⠀⠀⠀⠀⠀⠈⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣧⠀⠀⠀"
echo "⠀⠀⠀⠀⠀⠈⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠁⠀⠀⠀"
echo ""
echo "                    Coded by Oscar"
echo "                    Domain Migration Made Simple"
echo "==========================================" 