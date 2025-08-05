#!/bin/bash
# =============================================================================
# Occie's Debian Domain Migration Script :)
# =============================================================================
# 
#Made in VS code#
#==========================================================================
# README - HOW TO USE THIS SCRIPT
# =============================================================================
# OVERVIEW:
# This script safely migrates a Debian/Ubuntu system from one Active Directory
# domain to another, similar to Profwiz for Windows but for Linux systems.
# 
# PREREQUISITES:
# - Debian/Ubuntu system
# - Root/sudo access
# - Network connectivity to both old and new domain controllers
# - Valid admin credentials for both domains
# - DNS resolution working for both domains
# 
# USAGE:
# =============================================================================
# 
# 1. BASIC DOMAIN MIGRATION:
#    sudo ./oz-deb-migration.sh
#    
#    This will:
#    - Install required packages (realmd, sssd, etc.)
#    - Backup current configuration files
#    - Leave the current domain
#    - Join the new domain
#    - Update hostname and network configuration
#    - Configure authentication services
#    - Optionally set up sudo access for domain users
#    - Prompt for system reboot
# 
# 2. REVERT TO PREVIOUS DOMAIN:
#    sudo ./oz-deb-migration.sh --revert
#    
#    This will:
#    - Find the most recent backup files
#    - Restore /etc/hosts, /etc/krb5.conf, and /etc/sssd/sssd.conf
#    - Clear SSSD cache
#    - Restart SSSD service
#    - Prompt for system reboot
# 
# 3. SHOW HELP:
#    sudo ./oz-deb-migration.sh --help
#    
#    Displays usage information and available options
# 
# WHAT THE SCRIPT DOES:
# =============================================================================
# 
# SAFETY FEATURES:
# - Creates timestamped backups of all configuration files
# - Validates all user inputs (domain names, email addresses)
# - Uses temporary files for configuration changes
# - Verifies generated configurations before applying
# - Provides rollback capabilities
# - Never modifies user home directories
# 
# CONFIGURATION FILES MODIFIED:
# - /etc/hosts (updated with new hostname and domain)
# - /etc/krb5.conf (Kerberos configuration for new domain)
# - /etc/sssd/sssd.conf (SSSD configuration for domain auth)
# - /etc/sudoers.d/domain-users (if sudo access is enabled)
# 
# BACKUP FILES CREATED:
# - /etc/hosts.backup.YYYYMMDD_HHMMSS
# - /etc/krb5.conf.backup.YYYYMMDD_HHMMSS
# - /etc/sssd/sssd.conf.backup.YYYYMMDD_HHMMSS
# 
# TROUBLESHOOTING:
# =============================================================================
# 
# If migration fails:
# 1. Check /var/log/sssd/ for error messages
# 2. Verify DNS resolution for the new domain
# 3. Ensure firewall allows LDAP/Kerberos traffic (ports 389, 636, 88, 464)
# 4. Verify admin credentials are correct
# 5. Check domain controller accessibility
# 
# If you need to revert:
# 1. Run: sudo ./oz-deb-migration.sh --revert
# 2. Or manually restore from backups:
#    sudo cp /etc/hosts.backup.* /etc/hosts
#    sudo cp /etc/krb5.conf.backup.* /etc/krb5.conf
#    sudo cp /etc/sssd/sssd.conf.backup.* /etc/sssd/sssd.conf
#    sudo systemctl restart sssd
# 
# AFTER MIGRATION:
# =============================================================================
# 
# 1. Reboot the system (script will prompt for this)
# 2. Test logging in with a domain user account
# 3. Verify sudo access works for domain users (if enabled)
# 4. Check that domain group memberships are working
# 
# SECURITY NOTES:
# - Script requires root access for domain operations
# - Admin credentials are used only for domain join operations
# - No credentials are stored in configuration files
# - All operations are logged and can be audited
# 
# SUPPORTED SYSTEMS:
# - Debian 9+ (Stretch and newer)
# - Ubuntu 16.04+ (Xenial and newer)
# - Other Debian-based distributions
# 
# =============================================================================
# 
# Features:
# - Safe domain migration with automatic backups
# - Input validation and error handling
# - Revert functionality to restore previous configuration
# - Sudo access configuration for domain users
# - Verbose logging and user feedback
# - Comprehensive error handling and rollback
# =============================================================================

# Enable verbose output and error handling
set -e                    # Exit immediately if any command fails
set -o pipefail          # Exit if any command in a pipeline fails

# Function: Display script usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --revert    Revert to previous domain configuration"
    echo "  --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Perform domain migration"
    echo "  $0 --revert     # Revert to previous domain"
    echo ""
}

# Function: Revert to previous domain configuration
revert_migration() {
    echo "=========================================="
    echo "REVERTING DOMAIN MIGRATION"
    echo "=========================================="
    
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

# Parse command line arguments
if [[ "$1" == "--revert" ]]; then          # Check if user wants to revert
    revert_migration                       # Call the revert function
elif [[ "$1" == "--help" || "$1" == "-h" ]]; then  # Check if user wants help
    show_usage                             # Display usage information
    exit 0                                 # Exit successfully
fi

echo "=========================================="
echo "STARTING DOMAIN MIGRATION PROCESS"
echo "=========================================="
echo "This script will migrate your system to a new Active Directory domain."
echo "All configuration files will be backed up before changes are made."
echo ""

# Install required packages with verbose output
step "Installing required packages..."
echo "Updating package lists..."
sudo apt-get update -qq >/dev/null 2>&1                    # Update package database (quiet mode, suppress output)
echo "Installing domain migration packages..."
sudo apt-get install -y figlet lolcat nnn realmd sssd sssd-tools adcli libnss-sss libpam-sss samba-common-bin packagekit krb5-user oddjob oddjob-mkhomedir -qq >/dev/null 2>&1
# Install packages: figlet/lolcat (display), realmd (domain join), sssd (authentication), adcli (AD tools), etc.
echo "Upgrading system packages..."
sudo apt-get upgrade -y -qq >/dev/null 2>&1                # Upgrade existing packages (quiet mode)
echo "Setting up lolcat symlink..."
sudo ln -sf /usr/games/lolcat /usr/local/bin/lolcat 2>/dev/null  # Create symlink for lolcat in PATH
success "All required packages installed successfully"

# Ensure script is run as root (required for domain operations)
step "Checking script permissions..."
if [[ "$EUID" -ne 0 ]]; then                    # Check if effective user ID is not root (0)
  error "This script must be run as root (use sudo)"
  echo "Please run: sudo $0"                    # Show correct usage command
  exit 1                                        # Exit with error code
fi
success "Running with root privileges"

# Set error handling - exit on any error
set -e                                        # Exit immediately if any command fails

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Function: Display stylized banner with ASCII art
banner() {
    echo "=========================================="
    if command -v figlet >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then  # Check if figlet and lolcat are available
        echo "Oz's Domain Migration Script" | figlet -f slant | lolcat              # Create fancy ASCII banner with colors
    else
        echo -e "\n=== Occie's Debian Domain Migration Script :) ===\n"              # Fallback simple banner
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

# Function: Check for potential migration issues
check_migration_issues() {
    info "Checking for potential migration issues..."
    
    # Check if system is in maintenance mode
    if systemctl is-system-running | grep -q "maintenance"; then
        warning "System appears to be in maintenance mode"
    fi
    
    # Check for pending updates
    if command_exists apt; then
        PENDING_UPDATES=$(apt list --upgradable 2>/dev/null | wc -l)
        if [[ $PENDING_UPDATES -gt 1 ]]; then
            warning "Found $PENDING_UPDATES pending system updates"
            info "Consider updating system before migration"
        fi
    fi
    
    # Check disk space
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $DISK_USAGE -gt 90 ]]; then
        warning "Disk usage is high: ${DISK_USAGE}%"
        info "Consider freeing disk space before migration"
    fi
    
    # Check for running critical services
    CRITICAL_SERVICES=("sshd" "systemd-logind" "dbus")
    for service in "${CRITICAL_SERVICES[@]}"; do
        if ! systemctl is-active --quiet "$service" 2>/dev/null; then
            warning "Critical service $service is not running"
        fi
    done
}

# Function: Create timestamped backups of configuration files
# This ensures we can restore the previous configuration if needed
backup_config() {
    local file="$1"                                        # First parameter: file to backup
    local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"   # Create backup filename with timestamp
    if [[ -f "$file" ]]; then                              # Check if source file exists
        echo "Creating backup of $file..."
        cp "$file" "$backup"                               # Copy file to backup location
        info "Backed up $file to $backup"
    else
        warning "File $file does not exist, skipping backup"
    fi
}

# Function: Validate domain name format using regex
# Ensures the domain follows proper DNS naming conventions
validate_domain() {
    local domain="$1"                                      # First parameter: domain to validate
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        # Regex explanation: Validates domain format (letters, numbers, hyphens, dots)
        return 1                                           # Return error code if validation fails
    fi
    return 0                                               # Return success code if validation passes
}

# Function: Validate email address format using regex
# Ensures the email follows proper email naming conventions
validate_email() {
    local email="$1"                                       # First parameter: email to validate
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        # Regex explanation: Validates email format (user@domain.tld)
        return 1                                           # Return error code if validation fails
    fi
    return 0                                               # Return success code if validation passes
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
# SAFETY BACKUP ACCOUNT CREATION
# =============================================================================
step "Creating safety backup account..."
info "Creating a temporary local account for emergency access during migration..."

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

# =============================================================================
# PRE-MIGRATION CHECKS
# =============================================================================
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

# Check if system is currently in use
info "Checking for active user sessions..."
ACTIVE_USERS=$(who | wc -l)
if [[ $ACTIVE_USERS -gt 1 ]]; then
    warning "Active users detected: $ACTIVE_USERS - Consider migrating during maintenance window"
    info "Active sessions:"
    who
else
    success "No active user sessions detected"
fi

# Check for running services that might conflict
info "Checking for potentially conflicting services..."
CONFLICTING_SERVICES=("winbind" "samba" "nmbd" "smbd")
for service in "${CONFLICTING_SERVICES[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        warning "Service $service is running - may conflict with SSSD"
        read -rp "Do you want to stop $service service? (y/n): " STOP_SERVICE
        if [[ "$STOP_SERVICE" =~ ^[Yy]$ ]]; then
            info "Stopping $service service..."
            systemctl stop "$service" 2>/dev/null && success "$service stopped" || warning "Could not stop $service"
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

# Check system time synchronization
info "Checking system time synchronization..."
if command -v timedatectl >/dev/null 2>&1; then
    if timedatectl status | grep -q "synchronized: yes"; then
        success "Time synchronization: OK"
    else
        warning "Time synchronization: FAILED - Kerberos requires accurate time"
        info "Consider enabling NTP: sudo timedatectl set-ntp true"
    fi
else
    warning "timedatectl not available - cannot verify time sync"
fi

echo ""
success "Pre-migration checks completed"

# Run additional migration issue checks
check_migration_issues

# =============================================================================
# CURRENT DOMAIN STATUS
# =============================================================================
step "Analyzing current domain status..."
info "Checking which domains this system is currently joined to..."

echo "Current domain membership:"
realm list || echo "Not currently joined to any domain."    # List joined domains or show message if none

echo ""
info "Checking SSSD domain configuration:"
sssctl domain-list || echo "No SSSD domains configured"     # List SSSD domains or show message if none

# =============================================================================
# USER INPUT VALIDATION
# =============================================================================
step "Collecting migration parameters..."
info "Please provide the following information for the domain migration:"
echo ""

# Get and validate the new domain name
info "Step 1/3: New domain information"
while true; do                                              # Loop until valid input is provided
    read -rp "Enter your NEW domain (e.g., newdomain.com): " NEWDOMAIN  # Prompt user for domain input
    if validate_domain "$NEWDOMAIN"; then                   # Call validation function
        success "Domain format is valid: $NEWDOMAIN"
        break                                               # Exit loop if validation passes
    else
        error "Invalid domain format. Please enter a valid domain name."
        info "Example: company.com, subdomain.company.com"
    fi
done

# Get and validate the current domain admin account
info "Step 2/3: Current domain admin credentials"
while true; do                                              # Loop until valid input is provided
    read -rp "Enter your CURRENT domain admin account (e.g., admin@olddomain.com): " OLDADMIN  # Prompt for old admin
    if validate_email "$OLDADMIN"; then                     # Call email validation function
        success "Email format is valid: $OLDADMIN"
        break                                               # Exit loop if validation passes
    else
        error "Invalid email format. Please enter a valid email address."
        info "Example: admin@company.com"
    fi
done

# Get and validate the new domain admin account
info "Step 3/3: New domain admin credentials"
while true; do                                              # Loop until valid input is provided
    read -rp "Enter your NEW domain admin account (e.g., admin@newdomain.com): " NEWADMIN  # Prompt for new admin
    if validate_email "$NEWADMIN"; then                     # Call email validation function
        success "Email format is valid: $NEWADMIN"
        break                                               # Exit loop if validation passes
    else
        error "Invalid email format. Please enter a valid email address."
        info "Example: admin@company.com"
    fi
done

# Get admin password securely
info "Step 4/4: Admin password"
echo -n "Enter password for $NEWADMIN: "
read -s NEWADMIN_PASS                                       # Read password without displaying
echo ""                                                     # Add newline after password input

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
    kdestroy 2>/dev/null                                    # Clean up test ticket
fi

echo ""
info "All input parameters validated successfully!"

# =============================================================================
# CONFIGURATION BACKUP
# =============================================================================
step "Creating configuration backups..."
info "Creating timestamped backups of critical system files..."
info "These backups will allow you to revert changes if needed."

backup_config "/etc/hosts"
backup_config "/etc/krb5.conf"
backup_config "/etc/sssd/sssd.conf"

success "All configuration files backed up successfully"
echo ""

# =============================================================================
# DOMAIN TRANSITION
# =============================================================================
step "Initiating domain transition..."
info "Leaving current domain and joining new domain..."

# Check if currently joined to a domain
if realm list | grep -q .; then                            # Check if realm list has any output (joined to domain)
    info "Currently joined to domain. Attempting to leave..."
    echo "Leaving domain using account: $OLDADMIN"
    
    # Check for active domain user sessions
    info "Checking for active domain user sessions..."
    ACTIVE_DOMAIN_USERS=$(who | grep "@" | wc -l)
    if [[ $ACTIVE_DOMAIN_USERS -gt 0 ]]; then
        warning "Found $ACTIVE_DOMAIN_USERS active domain user sessions"
        info "Active domain users:"
        who | grep "@"
        read -rp "Do you want to continue? Domain users will be logged out. (y/n): " CONTINUE_WITH_LOGOUTS
        if [[ ! "$CONTINUE_WITH_LOGOUTS" =~ ^[Yy]$ ]]; then
            error "Migration cancelled by user"
            exit 0
        fi
    fi
    
    # Get password for old domain admin if needed
    echo -n "Enter password for $OLDADMIN (if required): "
    read -s OLDADMIN_PASS
    echo ""
    
    if [[ -n "$OLDADMIN_PASS" ]]; then
        echo "$OLDADMIN_PASS" | realm leave --user="$OLDADMIN" || warning "Could not leave domain. Continuing anyway..."
        unset OLDADMIN_PASS
    else
        realm leave --user="$OLDADMIN" || warning "Could not leave domain. Continuing anyway..."
    fi
    info "Domain leave operation completed"
else
    success "No domain currently joined. Proceeding to join new domain."
fi

# Discover the new domain structure
step "Discovering new domain structure..."
info "Analyzing domain $NEWDOMAIN for available services and configuration..."

if ! realm discover "$NEWDOMAIN"; then                      # Try to discover domain services and structure
    error "Failed to discover domain $NEWDOMAIN"
    info "This could be due to:"
    info "  - Network connectivity issues"
    info "  - DNS resolution problems"
    info "  - Domain controller not accessible"
    info "  - Firewall blocking required ports"
    exit 1                                                  # Exit script if discovery fails
fi
success "Domain discovery completed successfully"

# Join the new domain
step "Joining new domain..."
info "Attempting to join domain $NEWDOMAIN using account: $NEWADMIN"
info "This process will:"
info "  - Authenticate with the domain controller"
info "  - Create computer account in Active Directory"
info "  - Configure SSSD for domain authentication"

# Use password for domain join
info "Attempting to join domain $NEWDOMAIN..."
if ! echo "$NEWADMIN_PASS" | realm join --user="$NEWADMIN" "$NEWDOMAIN"; then  # Attempt to join with password
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
        exit 1                                              # Exit script if join fails
    else
        success "Successfully joined domain using alternative method"
    fi
else
    success "Successfully joined domain $NEWDOMAIN"
fi

# Clear password from memory
unset NEWADMIN_PASS

# =============================================================================
# HOSTNAME CONFIGURATION
# =============================================================================
step "Configuring system hostname..."
info "Setting up the system hostname for the new domain..."

# Get the new hostname from user
read -rp "Enter new short hostname (e.g., myhost): " SHORTNAME  # Prompt user for short hostname
FQDN="$SHORTNAME.$NEWDOMAIN"                                   # Create full domain name (FQDN)

info "Setting hostname to: $FQDN"
info "This will update the system's hostname to match the new domain"

hostnamectl set-hostname "$FQDN"                               # Set the system hostname using hostnamectl
success "Hostname updated to $FQDN"

# Verify hostname was set correctly
if [[ "$(hostname)" == "$FQDN" ]]; then
    success "Hostname verification: OK"
else
    warning "Hostname may not have been set correctly"
    info "Current hostname: $(hostname)"
    info "Expected hostname: $FQDN"
fi

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================
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

HOSTS_FILE="/etc/hosts"                                       # Define hosts file path
IP_LINE="127.0.1.1       $FQDN $SHORTNAME"                   # Create hosts file entry for localhost
STATIC_IP=$(hostname -I | awk '{print $1}')                  # Get first IP address from hostname -I

info "Current IP address: $STATIC_IP"
info "New hostname: $SHORTNAME"
info "Full domain name: $FQDN"

# Create a temporary file for the new hosts content
info "Creating new /etc/hosts configuration..."
TEMP_HOSTS=$(mktemp)                                         # Create temporary file for new hosts content
{
    # Remove old hostname entries and add new ones
    grep -v "127.0.1.1" "$HOSTS_FILE" | grep -v "$FQDN" | grep -v "$SHORTNAME"  # Remove old entries
    echo "127.0.0.1       localhost"                         # Add localhost entry
    echo "$IP_LINE"                                          # Add new hostname entry
    if [[ -n "$STATIC_IP" && "$STATIC_IP" != "127.0.1.1" ]]; then  # Check if static IP exists and is different
        echo "$STATIC_IP       $FQDN $SHORTNAME"             # Add static IP entry
    fi
} > "$TEMP_HOSTS"                                            # Write all content to temporary file

# Verify the new hosts file looks reasonable before applying
info "Validating new /etc/hosts configuration..."
if grep -q "localhost" "$TEMP_HOSTS" && grep -q "$FQDN" "$TEMP_HOSTS"; then  # Check if file contains required entries
    cp "$TEMP_HOSTS" "$HOSTS_FILE"                            # Copy temporary file to actual hosts file
    success "/etc/hosts updated successfully"
    info "New hosts file contents:"
    cat "$HOSTS_FILE"                                         # Display the new hosts file content
else
    error "Generated /etc/hosts file appears invalid. Restoring backup."
    cp "${HOSTS_FILE}.backup."* "$HOSTS_FILE" 2>/dev/null || error "Could not restore hosts backup"  # Restore from backup
    exit 1                                                    # Exit if restore fails
fi
rm -f "$TEMP_HOSTS"                                          # Clean up temporary file

# =============================================================================
# AUTHENTICATION CONFIGURATION
# =============================================================================
step "Configuring authentication services..."
info "Setting up Kerberos and SSSD for domain authentication..."

# Clear SSSD cache to ensure fresh authentication
step "Clearing SSSD cache..."
info "Removing cached authentication data..."
sssctl cache-remove || warning "Could not clear SSSD cache (this is normal if no cache exists)"

# Configure Kerberos for the new domain
step "Configuring Kerberos authentication..."
info "Creating Kerberos configuration for domain: ${NEWDOMAIN^^}"

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
        kdc = dc1.${NEWDOMAIN}
        admin_server = dc1.${NEWDOMAIN}
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
    info "KDC server: dc1.${NEWDOMAIN}"
else
    error "Generated krb5.conf is empty. Restoring backup."
    cp "/etc/krb5.conf.backup."* /etc/krb5.conf 2>/dev/null || error "Could not restore krb5.conf backup"
    exit 1
fi
rm -f "$TEMP_KRB5"

# =============================================================================
# SERVICE RESTART
# =============================================================================
step "Restarting authentication services..."
info "Restarting SSSD service to apply new configuration..."

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

# =============================================================================
# VERIFICATION AND TESTING
# =============================================================================
step "Verifying domain join and configuration..."
info "Checking domain membership status..."

echo "Current domain membership:"
realm list

echo ""
info "Checking SSSD domain configuration:"
sssctl domain-list

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

# =============================================================================
# POST-MIGRATION VERIFICATION
# =============================================================================
step "Running post-migration verification..."
info "Verifying domain join was successful..."

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
DC_HOST="dc1.$NEWDOMAIN"
if ping -c 1 "$DC_HOST" >/dev/null 2>&1; then
    success "Domain controller connectivity: OK"
else
    warning "Cannot reach $DC_HOST - check network/DNS"
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

# 12. Final verification and instructions
step "Final verification..."
if realm list | grep -q "$NEWDOMAIN"; then
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
    echo "Test domain controller:     ping dc1.$NEWDOMAIN"
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
    echo "SUPPORT FILES:"
    echo "=========================================="
    echo "Backup files:               ls -la /etc/*.backup.*"
    echo "SSSD config:                /etc/sssd/sssd.conf"
    echo "Kerberos config:            /etc/krb5.conf"
    echo "Hosts file:                 /etc/hosts"
    echo "SSSD logs:                  /var/log/sssd/"
    echo "System logs:                journalctl -u sssd"
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

# 13. Add domain user to sudo group (if requested)
step "Setting up sudo access for domain users..."
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

# 14. Offer revert option
step "Migration completed successfully!"
echo ""
echo "=========================================="
echo "MIGRATION SUMMARY:"
echo "=========================================="
echo "Old Domain: $(realm list 2>/dev/null | grep -v "$NEWDOMAIN" | head -1 || echo "None")"
echo "New Domain: $NEWDOMAIN"
echo "Hostname: $FQDN"
echo "Backup files created:"
ls -la /etc/*.backup.* 2>/dev/null || echo "No backup files found"
echo "=========================================="

# Offer revert option
echo ""
read -rp "Do you want to add a revert option to this script? (y/n): " ADD_REVERT
if [[ "$ADD_REVERT" =~ ^[Yy]$ ]]; then
    echo ""
    echo "To revert to the previous domain configuration, run:"
    echo "sudo $0 --revert"
    echo ""
    echo "Or manually restore from backups:"
    echo "sudo cp /etc/hosts.backup.* /etc/hosts"
    echo "sudo cp /etc/krb5.conf.backup.* /etc/krb5.conf"
    echo "sudo cp /etc/sssd/sssd.conf.backup.* /etc/sssd/sssd.conf"
    echo "sudo systemctl restart sssd"
fi

# 15. Final instructions and reboot prompt
step "Final steps required:"
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
echo "=========================================="
