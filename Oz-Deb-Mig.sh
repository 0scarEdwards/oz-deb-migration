
#!/bin/bash
# =============================================================================
# Oz Domain Migration Script
# Version: 1.0.0
# =============================================================================
#
# This script migrates a Debian system from one Active Directory domain to another.
# It handles domain leaving, system backups, and domain joining with proper validation.
#
# Features:
# - Domain leave and join operations
# - System file backups and restoration
# - Comprehensive error handling and logging
# - Demo mode for testing
# - Revert functionality
#
# =============================================================================

# Global variables
SCRIPT_NAME="Oz-Deb-Mig.sh"
SCRIPT_VERSION="1.0.0"
DEMO_MODE=false
REVERT_MODE=false
BACKUP_DIR="/root/migration-backups"
LOG_FILE=""
OZBACKUP_PASSWORD=""
current_domain=""
new_domain=""
admin_user=""

# Function: Initialize logging
init_logging() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    LOG_FILE="/root/migration-backups/migration_log_${timestamp}.log"
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Initialize log file
    cat > "$LOG_FILE" << EOF
=== Oz Domain Migration Log ===
Script: $SCRIPT_NAME
Version: $SCRIPT_VERSION
Started: $(date)
User: $(whoami)
Hostname: $(hostname)
================================

EOF
    
    echo "Log file initialized: $LOG_FILE"
}

# Function: Log message
# This function handles all logging throughout the script - both to file and console
# It creates structured log entries with timestamps and different log levels
log_message() {
    local level="$1"      # Log level: ERROR, WARNING, INFO, or any other level
    local message="$2"    # The actual message we want to log
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')  # Current time for the log entry
    
    # Write the formatted log entry to our log file
    # Format: [2025-08-06 22:15:20] [INFO] Starting package installation
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Also echo to console for user feedback - this gives immediate visibility
    # Different log levels get different console output formatting
    case "$level" in
        "ERROR")
            echo "ERROR: $message" >&2  # Send errors to stderr (standard error)
            ;;
        "WARNING")
            echo "WARNING: $message"    # Show warnings in normal output
            ;;
        "INFO")
            echo "INFO: $message"       # Show info messages in normal output
            ;;
        *)
            echo "$message"             # For any other level, just show the message
            ;;
    esac
}

# Function: Log command execution
# This function executes system commands and logs everything about them
# It captures both the command output and exit code for debugging purposes
log_command() {
    local command="$1"      # The actual command to execute (e.g., "apt-get install package")
    local description="$2"  # Human-readable description of what the command does
    
    # Log what we're about to do - this helps with troubleshooting
    log_message "INFO" "Executing: $description"
    log_message "INFO" "Command: $command"
    
    # In demo mode, we don't actually run commands - just simulate them
    if [[ "$DEMO_MODE" == true ]]; then
        log_message "INFO" "Demo Mode: Command would be executed"
        return 0  # Exit successfully without doing anything
    fi
    
    # Execute command and capture output
    # We need to capture both the output and the exit code to know if it succeeded
    local output      # Will hold the command's output (stdout and stderr)
    local exit_code   # Will hold the command's exit code (0 = success, non-zero = failure)
    
    # Run the command and capture everything
    # 2>&1 means redirect stderr to stdout so we capture error messages too
    output=$(eval "$command" 2>&1)
    exit_code=$?  # $? contains the exit code of the last command
    
#Coded by Oscar

    # Log the output - but only if there was any output to log
    # This prevents empty log entries cluttering up the log file
    if [[ -n "$output" ]]; then
        log_message "INFO" "Output: $output"
    fi
    
    # Log the exit code - this is crucial for debugging
    # Exit code 0 means success, any other number means failure
    log_message "INFO" "Exit code: $exit_code"
    
    # Return the same exit code so calling functions know if the command succeeded
    # This maintains the chain of success/failure status up the call stack
    return $exit_code
}

# Function: Handle script failure
# This is our emergency response system - it activates when any command fails
# It provides detailed analysis of what went wrong and how to fix it
handle_failure() {
    local exit_code=$?      # $? contains the exit code of the command that just failed
    local line_number=$1    # Which line in the script failed (passed by the trap)
    local command="$2"      # What command was being executed when it failed
    
    # Log the failure details for debugging
    # This information is crucial for troubleshooting issues
    log_message "ERROR" "Script failed at line $line_number"
    log_message "ERROR" "Failed command: $command"
    log_message "ERROR" "Exit code: $exit_code"
    
    echo ""
    echo "=========================================="
    echo "SCRIPT FAILED - TROUBLESHOOTING REQUIRED"
    echo "=========================================="
    echo ""
    echo "A detailed log has been created: $LOG_FILE"
    echo ""
    echo "Opening log file in GNOME text editor for troubleshooting..."
    
    # Try to open the log file in GNOME text editor
    if command -v gedit >/dev/null 2>&1; then
        gedit "$LOG_FILE" &
        log_message "INFO" "Opened log file in gedit"
    elif command -v gnome-text-editor >/dev/null 2>&1; then
        gnome-text-editor "$LOG_FILE" &
        log_message "INFO" "Opened log file in gnome-text-editor"
    else
        echo "GNOME text editor not found. Please manually open: $LOG_FILE"
        log_message "WARNING" "GNOME text editor not found, manual log review required"
    fi
    
    echo ""
    echo "=========================================="
    echo "FAILURE ANALYSIS"
    echo "=========================================="
    echo ""
    
    # Determine what stage we failed at and provide specific guidance
    if [[ -f "$LOG_FILE" ]]; then
        local last_step=$(grep "Starting\|INFO.*completed" "$LOG_FILE" | tail -5 | grep -E "Starting|completed" | tail -1)
        echo "Last completed step: $last_step"
        echo ""
    fi
    
    # Provide specific failure explanations based on common scenarios
    echo "POSSIBLE CAUSES OF FAILURE:"
    echo ""
    
    # Check for specific failure patterns
    if grep -q "dpkg.*interrupted" "$LOG_FILE" 2>/dev/null; then
        echo "PACKAGE INSTALLATION FAILED"
        echo "   The package installation was interrupted or corrupted."
        echo "   This usually happens when another package manager is running."
        echo ""
        echo "   SOLUTION:"
        echo "   1. Run: sudo dpkg --configure -a"
        echo "   2. Run: sudo apt-get install -f"
        echo "   3. Try the script again"
        echo ""
    fi
    
    if grep -q "realm.*Couldn't connect to system bus" "$LOG_FILE" 2>/dev/null; then
        echo "DOMAIN OPERATION FAILED"
        echo "   The system cannot communicate with the domain controller."
        echo "   This usually indicates network connectivity or DNS issues."
        echo ""
        echo "   SOLUTION:"
        echo "   1. Check network connectivity: ping [domain-controller]"
        echo "   2. Verify DNS resolution: nslookup [domain-name]"
        echo "   3. Check firewall settings for ports 88, 389, 636"
        echo "   4. Ensure system time is synchronized"
        echo ""
    fi
    
    if grep -q "Permission denied" "$LOG_FILE" 2>/dev/null; then
        echo "PERMISSION ERROR"
        echo "   The script doesn't have sufficient permissions to perform operations."
        echo "   This usually means the script wasn't run as root."
        echo ""
        echo "   SOLUTION:"
        echo "   1. Run the script with sudo: sudo ./Oz-Deb-Mig.sh"
        echo "   2. Ensure you have root privileges"
        echo ""
    fi
    
    if grep -q "realm join.*failed" "$LOG_FILE" 2>/dev/null; then
        echo "DOMAIN JOIN FAILED"
        echo "   The system failed to join the new domain."
        echo "   This could be due to incorrect credentials or domain configuration."
        echo ""
        echo "   SOLUTION:"
        echo "   1. Verify admin username and password"
        echo "   2. Check domain name spelling"
        echo "   3. Ensure admin account has domain join permissions"
        echo "   4. Check domain controller connectivity"
        echo ""
    fi
    
    echo "=========================================="
    echo "WHAT HAS BEEN COMPLETED"
    echo "=========================================="
    echo ""
    
    # Check what steps have been completed
    if grep -q "Package installation completed" "$LOG_FILE" 2>/dev/null; then
        echo "Required packages installed"
    else
        echo "Package installation incomplete"
    fi
    
    if grep -q "Backup directory created" "$LOG_FILE" 2>/dev/null; then
        echo "Backup directory created"
    else
        echo "Backup directory creation incomplete"
    fi
    
    if grep -q "System backup completed" "$LOG_FILE" 2>/dev/null; then
        echo "System configuration backed up"
    else
        echo "System backup incomplete"
    fi
    
    if grep -q "OZBACKUP account configured" "$LOG_FILE" 2>/dev/null; then
        echo "OZBACKUP emergency account created"
    else
        echo "OZBACKUP account creation incomplete"
    fi
    
    if grep -q "Current domain detected" "$LOG_FILE" 2>/dev/null; then
        echo "Current domain status detected"
    else
        echo "Domain detection incomplete"
    fi
    
#Coded by Oscar

    if grep -q "Successfully left domain" "$LOG_FILE" 2>/dev/null; then
        echo "Successfully left old domain"
    elif grep -q "No domain currently configured" "$LOG_FILE" 2>/dev/null; then
        echo "No domain to leave (system was not domain-joined)"
    else
        echo "Domain leave process incomplete"
    fi
    
    if grep -q "Domain join verification successful" "$LOG_FILE" 2>/dev/null; then
        echo "Successfully joined new domain"
    else
        echo "Domain join incomplete"
    fi
    
    echo ""
    echo "=========================================="
    echo "WHAT IS PENDING"
    echo "=========================================="
    echo ""
    
    # Determine what still needs to be done
    if ! grep -q "Domain join verification successful" "$LOG_FILE" 2>/dev/null; then
        echo "Domain join process"
        echo "Domain user permission setup"
        echo "Domain user profile migration"
        echo "System reboot"
    else
        echo "System reboot (required for changes to take effect)"
    fi
    
    echo ""
    echo "=========================================="
    echo "HOW TO REVERT CHANGES"
    echo "=========================================="
    echo ""
    echo "To revert all changes made so far:"
    echo ""
    echo "1. Run the revert command:"
    echo "   sudo ./Oz-Deb-Mig.sh --revert"
    echo ""
    echo "2. The revert process will:"
    echo "   - Restore system configuration files from backup"
    echo "   - Remove domain user permissions"
    echo "   - Restore original domain settings (if any)"
    echo ""
    echo "3. Backup files are stored in: $BACKUP_DIR"
    echo "   You can manually restore files if needed"
    echo ""
    
    echo "=========================================="
    echo "TROUBLESHOOTING INFORMATION"
    echo "=========================================="
    echo ""
    echo "Full log file location: $LOG_FILE"
    echo ""
    echo "To revert to the previous domain configuration:"
    echo "  sudo $SCRIPT_NAME --revert"
    echo ""
    echo "Current domain status:"
    echo "----------------------------------------"
    if command -v realm >/dev/null 2>&1; then
        realm list
    else
        echo "realm command not available"
    fi
    echo "----------------------------------------"
    echo ""
    echo "For additional help, refer to HELPME.md"
    echo ""
    echo "Press Enter to continue or Ctrl+C to exit..."
    read -r
    
    exit $exit_code
}

# Set up error handling
trap 'handle_failure ${LINENO} "$BASH_COMMAND"' ERR

# Function: Display script banner
# This creates the fancy ASCII art banner at the start of the script
# It uses figlet for ASCII art and lolcat for colors, but falls back to plain text if not available
display_banner() {
    # Check if we have the fancy tools available (figlet for ASCII art, lolcat for colors)
    if command -v figlet >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then
        # We have the fancy tools, so let's make it look good
        if [[ "$DEMO_MODE" == true ]]; then
            # In demo mode, show both the normal banner and a demo indicator
            # This makes it clear to the user that they're in demo mode
            echo "Oz Domain Migration Script" | figlet -f slant | lolcat
            echo ""
            echo "DEMO MODE" | figlet -f slant | lolcat
            echo "No changes will be made to the system" | figlet -f small | lolcat
        else
            # Normal mode - just show the main banner
            echo "Oz Domain Migration Script" | figlet -f slant | lolcat
        fi
    else
        # Fallback to plain text if fancy tools aren't available
        # This ensures the script works even on minimal systems
        if [[ "$DEMO_MODE" == true ]]; then
            echo "=== Oz Domain Migration Script ==="
            echo "=== DEMO MODE ==="
            echo "No changes will be made to the system"
        else
            echo "=== Oz Domain Migration Script ==="
        fi
        # Let the user know they can get the fancy version if they want
        echo "Note: Install 'figlet' and 'lolcat' for enhanced banner display"
        echo "      sudo apt install figlet lolcat"
    fi
    echo ""  # Add a blank line after the banner for better readability
}


# =============================================================================
# =============================================================================

# =============================================================================
# Watermark
# =============================================================================
# ⢀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⣠⣤⣶⣶
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⢰⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⣀⣀⣾⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⡏⠉⠛⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⣿
# ⣿⣿⣿⣿⣿⣿⠀⠀⠀⠈⠛⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠛⠉⠁⠀⣿
# ⣿⣿⣿⣿⣿⣿⣧⡀⠀⠀⠀⠀⠙⠿⠿⠿⠻⠿⠿⠟⠿⠛⠉⠀⠀⠀⠀⠀⣸⣿
# ⣿⣿⣿⣿⣿⣿⣿⣷⣄⠀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣴⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⢰⣹⡆⠀⠀⠀⠀⠀⠀⣭⣷⠀⠀⠀⠸⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠈⠉⠀⠀⠤⠄⠀⠀⠀⠉⠁⠀⠀⠀⠀⢿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⢾⣿⣷⠀⠀⠀⠀⡠⠤⢄⠀⠀⠀⠠⣿⣿⣷⠀⢸⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⡀⠉⠀⠀⠀⠀⠀⢄⠀⢀⠀⠀⠀⠀⠉⠉⠁⠀⠀⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⠀⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿
# Coded By Oscar
# =============================================================================



# Function: Display step header
# This creates the section headers throughout the script (like "Installing Packages", "Creating Backups", etc.)
# It uses the same fancy formatting as the main banner but for individual steps
display_step() {
    local step="$1"  # The step name to display (e.g., "Installing Required Packages")
    
    # Use fancy formatting if available, otherwise fall back to plain text
    if command -v figlet >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then
        # Create a fancy ASCII art header with colors
        echo "$step" | figlet -f slant | lolcat
    else
        # Simple text header with equals signs for emphasis
        echo "=== $step ==="
    fi
    echo ""  # Add spacing after the header
}

# Function: Display help information
show_help() {
    display_banner
    echo "Usage: $SCRIPT_NAME [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --demo          Demo mode - show what would happen without making changes"
    echo "  --revert        Revert to previous domain configuration"
    echo "  --help          Show this help message"
    echo ""
    echo "Standard Usage:"
    echo "  sudo $SCRIPT_NAME"
    echo "  The script will prompt for:"
    echo "    - Current domain name"
    echo "    - New domain name"
    echo "    - Admin username for new domain"
    echo ""
    echo "Examples:"
    echo "  sudo $SCRIPT_NAME                    # Standard migration"
    echo "  sudo $SCRIPT_NAME --demo            # Demo mode"
    echo "  sudo $SCRIPT_NAME --revert          # Revert changes"
    echo ""
    echo "Features:"
    echo "  - Leaves current domain"
    echo "  - Creates system backups"
    echo "  - Joins new domain"
    echo "  - Comprehensive logging and error handling"
    echo "  - Automatic log file opening on failure"
    echo ""
    echo "Requirements:"
    echo "  - Must be run as root (sudo)"
    echo "  - Active Directory domain access"
    echo "  - Admin credentials for new domain"
    echo ""
}

# Function: Check if running as root
# This is a critical safety check - domain operations require root privileges
# Without root access, the script can't modify system files or join domains
check_root() {
    # $EUID contains the effective user ID - 0 means root, anything else means regular user
    if [[ $EUID -ne 0 ]]; then
        # User is not root - show helpful error message and exit
        echo "Error: This script must be run as root (use sudo)"
        echo "Usage: sudo $SCRIPT_NAME [OPTIONS]"
        exit 1  # Exit with error code 1 to indicate failure
    fi
    # If we get here, user is root and we can proceed safely
}

# Function: Install required packages
# This function installs all the necessary packages for domain operations
# It handles both real installation and demo mode simulation
install_packages() {
    display_step "Installing Required Packages"
    
    log_message "INFO" "Starting package installation"
    
    # In demo mode, we simulate the installation process without actually installing anything
    # This lets users see what would happen without making changes
    if [[ "$DEMO_MODE" == true ]]; then
        echo "Demo Mode: Installing required packages..."
        echo "This may take a few moments..."
        
        # Show progress spinner to make it look like real work is happening
        local i=0
        local spin='-\|/'  # Characters for the spinning animation
        
        # Simulate package installation with realistic timing
        echo -n "Installing display packages... "
        sleep 2  # Wait 2 seconds to simulate installation time
        echo "Done"
        
        echo -n "Installing domain packages... "
        sleep 2  # Wait 2 seconds to simulate installation time
        echo "Done"
        
        echo "Packages installed successfully"
        log_message "INFO" "Demo Mode: Package installation completed successfully"
        echo ""
        return 0  # Exit successfully
    fi
    
    echo "Installing required packages..."
    echo "This may take a few moments..."
    
    # Check for dpkg issues first
    if dpkg -l | grep -q "^iU\|^iF"; then
        echo "Warning: dpkg has pending operations. Attempting to fix..."
        log_message "WARNING" "dpkg has pending operations, attempting to fix"
        
        if ! dpkg --configure -a; then
            echo "Error: Failed to fix dpkg issues. Please run manually:"
            echo "  sudo dpkg --configure -a"
            echo "  sudo apt-get install -f"
            log_message "ERROR" "Failed to fix dpkg issues"
            exit 1
        fi
        
        if ! apt-get install -f -qq; then
            echo "Error: Failed to fix package dependencies"
            log_message "ERROR" "Failed to fix package dependencies"
            exit 1
        fi
        
        echo "dpkg issues resolved. Continuing with package installation..."
        log_message "INFO" "dpkg issues resolved"
    fi
    
    # Show progress spinner
    local i=0
    local spin='-\|/'
    
    # Install figlet and lolcat for enhanced display
    echo -n "Installing display packages... "
    DEBIAN_FRONTEND=noninteractive apt-get install -y figlet lolcat -qq >/dev/null 2>&1 &
    local pid=$!
    while kill -0 $pid 2>/dev/null; do
        printf "\b${spin:i++%4:1}"
        sleep 0.1
    done
    printf "\b"
    ln -sf /usr/games/lolcat /usr/local/bin/lolcat 2>/dev/null
    echo "Done"
    
    # Install domain packages with non-interactive mode
    echo -n "Installing domain packages... "
    local packages="realmd sssd sssd-tools adcli libnss-sss libpam-sss samba-common-bin packagekit krb5-user oddjob oddjob-mkhomedir"
    
    # Pre-configure debconf to accept defaults for Kerberos
    echo "krb5-config krb5-config/default_realm string LOCALDOMAIN" | debconf-set-selections
    echo "krb5-config krb5-config/kerberos_servers string" | debconf-set-selections
    echo "krb5-config krb5-config/admin_server string" | debconf-set-selections
    echo "krb5-config krb5-config/add_servers_realm string LOCALDOMAIN" | debconf-set-selections
    echo "krb5-config krb5-config/add_servers boolean false" | debconf-set-selections
    echo "krb5-config krb5-config/read_config boolean true" | debconf-set-selections
    
    DEBIAN_FRONTEND=noninteractive apt-get install -y $packages -qq >/dev/null 2>&1 &
    pid=$!
    i=0
    while kill -0 $pid 2>/dev/null; do
        printf "\b${spin:i++%4:1}"
        sleep 0.1
    done
    printf "\b"
    echo "Done"
    
    log_command "DEBIAN_FRONTEND=noninteractive apt-get install -y $packages" "Install domain packages"
    
    echo "Packages installed successfully"
    log_message "INFO" "Package installation completed successfully"
    echo ""
}

# Function: Create backup directory
create_backup_directory() {
    display_step "Creating Backup Directory"
    
    log_message "INFO" "Creating backup directory"
    
    if [[ "$DEMO_MODE" == true ]]; then
        echo "Demo Mode: Creating backup directory..."
        sleep 1
        echo "Backup directory created: $BACKUP_DIR"
        log_message "INFO" "Demo Mode: Backup directory created successfully"
        echo ""
        return 0
    fi
    
    mkdir -p "$BACKUP_DIR"
    echo "Backup directory created: $BACKUP_DIR"
    log_message "INFO" "Backup directory created: $BACKUP_DIR"
    echo ""
}

# Function: Create system backups
create_system_backups() {
    display_step "Creating System Backups"
    
    log_message "INFO" "Starting system backup creation"
    
    if [[ "$DEMO_MODE" == true ]]; then
        echo "Demo Mode: Creating system backups..."
        sleep 1
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_path="$BACKUP_DIR/backup_$timestamp"
        echo "Creating backup at: $backup_path"
        sleep 1
        echo "  Backed up: /etc/samba/smb.conf"
        echo "  Backed up: /etc/nsswitch.conf"
        echo "  Backed up: /etc/pam.d/common-session"
        echo "  Backed up: /etc/pam.d/common-auth"
        echo "  Backed up: /etc/pam.d/common-account"
        echo "  Backed up: /etc/pam.d/common-password"
        echo "  Backed up: Current domain information"
        echo "Backup completed successfully"
        log_message "INFO" "Demo Mode: System backup completed successfully"
        echo ""
        return 0
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/backup_$timestamp"
    
    mkdir -p "$backup_path"
    echo "Creating backup at: $backup_path"
    log_message "INFO" "Creating backup at: $backup_path"
    
    # Files to backup
    local files_to_backup=(
        "/etc/samba/smb.conf"
        "/etc/nsswitch.conf"
        "/etc/pam.d/common-session"
        "/etc/pam.d/common-auth"
        "/etc/pam.d/common-account"
        "/etc/pam.d/common-password"
    )
    
    # Backup each file
    for file in "${files_to_backup[@]}"; do
        if [[ -f "$file" ]]; then
            cp "$file" "$backup_path/"
            echo "  Backed up: $file"
            log_message "INFO" "Backed up: $file"
        else
            log_message "WARNING" "File not found for backup: $file"
        fi
    done
    
    # Backup current domain information
    if command -v realm >/dev/null 2>&1; then
        realm list > "$backup_path/current_domain_info.txt" 2>&1
        echo "  Backed up: Current domain information"
        log_message "INFO" "Backed up current domain information"
    fi
    
    echo "Backup completed successfully"
    log_message "INFO" "System backup completed successfully"
    echo ""
}

# Function: Get domain information
get_domain_information() {
    display_step "Domain Information"
    
    log_message "INFO" "Starting domain information collection"
    
    if [[ "$DEMO_MODE" == true ]]; then
        echo "Demo Mode: Please provide the following information:"
        echo ""
        
        # Get new domain
        read -p "New domain name: " new_domain
        log_message "INFO" "Demo Mode: New domain: $new_domain"
        
        # Get admin user
        read -p "Admin username for new domain: " admin_user
        log_message "INFO" "Demo Mode: Admin user: $admin_user"
        
        echo ""
        log_message "INFO" "Demo Mode: Domain information collection completed"
        return 0
    fi
    
    echo "Please provide the following information:"
    echo ""
    
    # Get new domain
    read -p "New domain name: " new_domain
    log_message "INFO" "New domain: $new_domain"
    
    # Get admin user
    read -p "Admin username for new domain: " admin_user
    log_message "INFO" "Admin user: $admin_user"
    
    echo ""
    
    # Validate input
    if [[ -z "$new_domain" || -z "$admin_user" ]]; then
        log_message "ERROR" "Missing required domain information"
        echo "Error: All fields are required"
        exit 1
    fi
    
    log_message "INFO" "Domain information collection completed"
}

# Function: Detect current domain
detect_current_domain() {
    log_message "INFO" "Detecting current domain status"
    
    if [[ "$DEMO_MODE" == true ]]; then
        echo "Demo Mode: Would detect current domain status"
        return 0
    fi
    
    # Check if realm command is available
    if ! command -v realm >/dev/null 2>&1; then
        echo "realm command not available. No domain currently configured."
        log_message "INFO" "realm command not available, assuming no domain configured"
        return 1
    fi
    
    # Get current domain information
    local realm_output=$(realm list 2>/dev/null)
    
    if echo "$realm_output" | grep -q "configured"; then
        # Extract the configured domain name
        current_domain=$(echo "$realm_output" | grep "configured" | head -1 | awk '{print $1}')
        echo "Current domain detected: $current_domain"
        log_message "INFO" "Current domain detected: $current_domain"
        return 0
    else
        echo "No domain currently configured"
        log_message "INFO" "No domain currently configured"
        return 1
    fi
}

# Function: Discover domain
discover_domain() {
    display_step "Discovering Domain"
    
    log_message "INFO" "Starting domain discovery for: $new_domain"
    
    if [[ "$DEMO_MODE" == true ]]; then
        echo "Demo Mode: Discovering domain: $new_domain"
        echo "This will check domain connectivity and configuration..."
        echo ""
        sleep 2
        echo "Domain discovery successful"
        echo "Domain configuration verified"
        log_message "INFO" "Demo Mode: Domain discovery successful for: $new_domain"
        echo ""
        return 0
    fi
    
    echo "Discovering domain: $new_domain"
    echo "This will check domain connectivity and configuration..."
    echo ""
    
    if realm discover "$new_domain"; then
        echo "Domain discovery successful"
        echo "Domain configuration verified"
        log_message "INFO" "Domain discovery successful for: $new_domain"
        echo ""
        return 0
    else
        echo "Warning: Domain discovery failed"
        echo "This may indicate connectivity or configuration issues"
        echo "Continuing with domain join attempt..."
        log_message "WARNING" "Domain discovery failed for: $new_domain"
        echo ""
        return 1
    fi
}

# Function: Leave current domain
leave_domain() {
    display_step "Leaving Current Domain"
    
    log_message "INFO" "Starting domain leave process for: $current_domain"
    
    echo "Leaving domain: $current_domain"
    echo ""
    
    if [[ "$DEMO_MODE" == true ]]; then
        sleep 2
        echo "Demo Mode: Successfully left domain: $current_domain"
        log_message "INFO" "Demo Mode: Successfully left domain: $current_domain"
        echo ""
        return 0
    fi
    
    # Try to leave the domain
    if realm leave "$current_domain" 2>/dev/null; then
        echo "Successfully left domain: $current_domain"
        log_message "INFO" "Successfully left domain: $current_domain"
        echo ""
    else
        echo "Warning: Failed to leave domain: $current_domain"
        echo "This may be normal if not currently joined to a domain"
        echo "Continuing with domain join process..."
        log_message "WARNING" "Failed to leave domain: $current_domain"
        echo ""
    fi
}

# Function: Discover and permit domain users
discover_and_permit_users() {
    display_step "Discovering Domain Users"
    
    log_message "INFO" "Starting domain user discovery and permission setup"
    
    echo "Discovering domain users in home directories..."
    echo "Setting up permissions for new domain access..."
    echo ""
    
    if [[ "$DEMO_MODE" == true ]]; then
        # Actually scan for real users on the system (same as real mode)
        local old_domain_users=()
        local local_users=()
        local home_dirs=$(find /home -maxdepth 1 -type d -name "*" 2>/dev/null)
        
        for home_dir in $home_dirs; do
            local username=$(basename "$home_dir")
            
            # Skip if it's not a user directory or is a system directory
            if [[ "$username" == "home" || "$username" == "." || "$username" == ".." ]]; then
                continue
            fi
            
            # Check if it's a domain user (contains @)
            if [[ "$username" =~ @ ]]; then
                if [[ -n "$current_domain" && "$username" =~ @${current_domain}$ ]]; then
                    # Domain user from current domain
                    old_domain_users+=("$username")
                    echo "Demo Mode: Found domain user: $username"
                    log_message "INFO" "Demo Mode: Found domain user: $username"
                else
                    # Other domain users (not from current domain)
                    echo "Demo Mode: Found other domain user: $username (skipped - not from current domain)"
                    log_message "INFO" "Demo Mode: Found other domain user: $username (skipped)"
                fi
            else
                # Local user
                local_users+=("$username")
                echo "Demo Mode: Found local user: $username (skipped - local user)"
                log_message "INFO" "Demo Mode: Found local user: $username (skipped)"
            fi
        done

        echo ""
        
        # Report findings
        if [[ ${#old_domain_users[@]} -gt 0 ]]; then
            echo "Demo Mode: Found ${#old_domain_users[@]} domain user(s) from current domain:"
            for user in "${old_domain_users[@]}"; do
                echo "  - $user"
            done
            echo ""
        fi
        
        if [[ ${#local_users[@]} -gt 0 ]]; then
            echo "Demo Mode: Found ${#local_users[@]} local user(s) (skipped - local users are not affected):"
            for user in "${local_users[@]}"; do
                echo "  - $user"
            done
            echo ""
        fi
        
        if [[ ${#old_domain_users[@]} -eq 0 ]]; then
            echo "Demo Mode: No domain users found from current domain in home directories"
            log_message "INFO" "Demo Mode: No domain users found from current domain"
            return 0
        fi
        
        # Extract usernames and create new domain usernames
        local new_domain_users=()
        echo "Demo Mode: Will permit users for new domain access:"
        for old_user in "${old_domain_users[@]}"; do
            local username_part=$(echo "$old_user" | cut -d'@' -f1)
            local new_user="${username_part}@${new_domain}"
            new_domain_users+=("$new_user")
            echo "  - $new_user"
            log_message "INFO" "Demo Mode: Will permit new domain user: $new_user"
        done
        echo ""
        
        echo "Demo Mode: Setting up realm permissions..."
        for new_user in "${new_domain_users[@]}"; do
            echo "  Successfully permitted: $new_user"
        done
        echo ""
        
        echo "Demo Mode: Adding domain users to sudo group..."
        for new_user in "${new_domain_users[@]}"; do
            echo "  Successfully added to sudo group: $new_user"
        done
        echo ""
        
        echo "Demo Mode: Creating home directories for domain users..."
        for new_user in "${new_domain_users[@]}"; do
            echo "  Successfully created home directory: $new_user"
        done
        echo ""
        
        echo "Demo Mode: Configuring PAM mkhomedir for automatic home directory creation..."
        echo "Demo Mode: Updating PAM authentication configuration..."
        echo "  PAM authentication updated successfully"
        echo ""
        echo "Demo Mode: Domain user permission setup completed"
        log_message "INFO" "Demo Mode: Domain user discovery and permission setup completed"
        return 0
    fi
    
    echo "Discovering domain users in home directories..."
    echo "Setting up permissions for new domain access..."
    echo ""
    
    # Find all home directories
    local old_domain_users=()
    local local_users=()
    local home_dirs=$(find /home -maxdepth 1 -type d -name "*" 2>/dev/null)
    
    for home_dir in $home_dirs; do
        local username=$(basename "$home_dir")
        
        # Skip if it's not a user directory or is a system directory
        if [[ "$username" == "home" || "$username" == "." || "$username" == ".." ]]; then
            continue
        fi
        
        # Check if it's a domain user (contains @)
        if [[ "$username" =~ @ ]]; then
            if [[ -n "$current_domain" && "$username" =~ @${current_domain}$ ]]; then
                # Domain user from current domain
                old_domain_users+=("$username")
                echo "Found domain user: $username"
                log_message "INFO" "Found domain user: $username"
            else
                # Other domain users (not from current domain)
                echo "Found other domain user: $username (skipped - not from current domain)"
                log_message "INFO" "Found other domain user: $username (skipped)"
            fi
        else
            # Local user
            local_users+=("$username")
            echo "Found local user: $username (skipped - local user)"
            log_message "INFO" "Found local user: $username (skipped)"
        fi
    done
    
    echo ""
    
    # Report findings
    if [[ ${#old_domain_users[@]} -gt 0 ]]; then
        echo "Found ${#old_domain_users[@]} domain user(s) from current domain:"
        for user in "${old_domain_users[@]}"; do
            echo "  - $user"
        done
        echo ""
    fi
    
    if [[ ${#local_users[@]} -gt 0 ]]; then
        echo "Found ${#local_users[@]} local user(s) (skipped - local users are not affected):"
        for user in "${local_users[@]}"; do
            echo "  - $user"
        done
        echo ""
    fi
    
    if [[ ${#old_domain_users[@]} -eq 0 ]]; then
        echo "No domain users found from current domain in home directories"
        log_message "INFO" "No domain users found from current domain"
        return 0
    fi
    
    # Extract usernames and create new domain usernames
    local new_domain_users=()
    echo "Will permit users for new domain access:"
    for old_user in "${old_domain_users[@]}"; do
        local username_part=$(echo "$old_user" | cut -d'@' -f1)
        local new_user="${username_part}@${new_domain}"
        new_domain_users+=("$new_user")
        echo "  - $new_user"
        log_message "INFO" "Will permit new domain user: $new_user"
    done
    echo ""
    
    echo "Setting up realm permissions..."
    
    # Permit all new domain users
    for new_user in "${new_domain_users[@]}"; do
        echo "Permitting user: $new_user"
        if realm permit "$new_user"; then
            echo "  Successfully permitted: $new_user"
            log_message "INFO" "Successfully permitted user: $new_user"
        else
            echo "  Warning: Failed to permit: $new_user"
            log_message "WARNING" "Failed to permit user: $new_user"
        fi
    done
    
    echo ""
    echo "Adding domain users to sudo group..."
    
    # Add each permitted user to sudo group
    for new_user in "${new_domain_users[@]}"; do
        echo "Adding sudo access for: $new_user"
        
        # Try adduser first, then usermod as fallback
        if adduser "$new_user" sudo 2>/dev/null; then
            echo "  Successfully added to sudo group: $new_user"
            log_message "INFO" "Successfully added to sudo group: $new_user"
        elif usermod -aG sudo "$new_user" 2>/dev/null; then
            echo "  Successfully added to sudo group: $new_user"
            log_message "INFO" "Successfully added to sudo group: $new_user"
        else
            echo "  Warning: Failed to add to sudo group: $new_user"
            log_message "WARNING" "Failed to add to sudo group: $new_user"
        fi
    done
    
    echo ""
    echo "Creating home directories for domain users..."
    
    # Create home directories for each user
    for new_user in "${new_domain_users[@]}"; do
        echo "Creating home directory for: $new_user"
        
        if mkhomedir_helper "$new_user"; then
            echo "  Successfully created home directory: $new_user"
            log_message "INFO" "Successfully created home directory: $new_user"
        else
            echo "  Warning: Failed to create home directory: $new_user"
            log_message "WARNING" "Failed to create home directory: $new_user"
        fi
    done
    
    echo ""
    echo "Configuring PAM mkhomedir for automatic home directory creation..."
    
    # Create PAM mkhomedir configuration
    local pam_config_file="/usr/share/pam-configs/mkhomedir"
    
    if [[ ! -f "$pam_config_file" ]]; then
        echo "Creating PAM mkhomedir configuration..."
        cat > "$pam_config_file" << EOF
Name: activate mkhomedir
Default: yes
Priority: 900
Session-Type: Additional
Session:

        required pam_mkhomedir.so umask=0022 skel=/etc/skel
EOF
        log_message "INFO" "Created PAM mkhomedir configuration: $pam_config_file"
    else
        echo "PAM mkhomedir configuration already exists"
        log_message "INFO" "PAM mkhomedir configuration already exists"
    fi
    
    echo ""
    echo "Updating PAM authentication configuration..."
    
    # Run pam-auth-update to ensure proper authentication setup
    if command -v pam-auth-update >/dev/null 2>&1; then
        echo "Running pam-auth-update..."
        if pam-auth-update --force; then
            echo "  PAM authentication updated successfully"
            log_message "INFO" "PAM authentication updated successfully"
        else
            echo "  Warning: PAM authentication update may have had issues"
            log_message "WARNING" "PAM authentication update may have had issues"
        fi
    else
        echo "  Warning: pam-auth-update command not found"
        log_message "WARNING" "pam-auth-update command not found"
    fi
    
    echo ""
    echo "Domain user permission setup completed"
    log_message "INFO" "Domain user permission setup completed"
    echo ""
}

# Function: Migrate domain user profiles
migrate_domain_profiles() {
    display_step "Domain User Profile Migration"
    
    log_message "INFO" "Starting domain user profile migration"
    
    echo "Domain user profile migration"
    echo "This will move user files from old domain accounts to new domain accounts"
    echo "Files will be copied to new domain user home directories and symlinks created"
    echo "for compatibility with applications that reference the old paths."
    echo ""
    
    if [[ "$DEMO_MODE" == true ]]; then
        echo "Demo Mode: Would prompt: Do you want to migrate domain user profiles? (y/N)"
        echo "Demo Mode: User would choose: y"
        echo ""
        echo "Demo Mode: Starting domain user profile migration..."
        echo ""
        # Actually scan for real users to migrate (same as real mode)
        local old_domain_users=()
        local home_dirs=$(find /home -maxdepth 1 -type d -name "*@*" 2>/dev/null)
        
        for home_dir in $home_dirs; do
            local username=$(basename "$home_dir")
            if [[ "$username" =~ @${current_domain}$ ]]; then
                old_domain_users+=("$username")
            fi
        done
        
        if [[ ${#old_domain_users[@]} -eq 0 ]]; then
            echo "Demo Mode: No domain users found to migrate"
            log_message "INFO" "Demo Mode: No domain users found to migrate"
            return 0
        fi
        
        echo "Demo Mode: Found ${#old_domain_users[@]} domain user(s) to migrate:"
        for user in "${old_domain_users[@]}"; do
            echo "  - $user"
        done
        echo ""
        
        # Process each domain user
        for old_user in "${old_domain_users[@]}"; do
            local username_part=$(echo "$old_user" | cut -d'@' -f1)
            local new_user="${username_part}@${new_domain}"
            local old_home="/home/$old_user"
            local new_home="/home/$new_user"
            
            echo "Demo Mode: Processing user: $old_user -> $new_user"
            echo "  Creating new home directory: $new_home"
            echo "  Copying user files..."
            echo "  Successfully copied user files"
            echo "  Creating symlink from old to new home directory..."
            echo "  Successfully created symlink"
            echo "  User migration completed: $old_user -> $new_user"
            echo ""
        done
        echo ""
        echo "Demo Mode: Domain user profile migration completed"
        echo "Note: Local user accounts have been left untouched as requested"
        echo "Domain user files have been moved and symlinks created for compatibility"
        log_message "INFO" "Demo Mode: Domain user profile migration completed"
        return 0
    fi
    
    echo "Domain user profile migration"
    echo "This will move user files from old domain accounts to new domain accounts"
    echo "Files will be copied to new domain user home directories and symlinks created"
    echo "for compatibility with applications that reference the old paths."
    echo ""
    
    read -p "Do you want to migrate domain user profiles? (y/N): " migrate_profiles
    if [[ ! "$migrate_profiles" =~ ^[Yy]$ ]]; then
        echo "Skipping domain user profile migration"
        log_message "INFO" "Domain user profile migration skipped by user"
        echo ""
        return 0
    fi
    
    echo ""
    echo "Starting domain user profile migration..."
    echo ""
    
    # Find all home directories with @olddomain.com usernames
    local old_domain_users=()
    local home_dirs=$(find /home -maxdepth 1 -type d -name "*@*" 2>/dev/null)
    
    for home_dir in $home_dirs; do
        local username=$(basename "$home_dir")
        if [[ "$username" =~ @${current_domain}$ ]]; then
            old_domain_users+=("$username")
        fi
    done
    
    if [[ ${#old_domain_users[@]} -eq 0 ]]; then
        echo "No domain users found to migrate"
        log_message "INFO" "No domain users found to migrate"
        return 0
    fi
    
    echo "Found ${#old_domain_users[@]} domain user(s) to migrate:"
    for user in "${old_domain_users[@]}"; do
        echo "  - $user"
    done
    echo ""
    
    # Process each domain user
    for old_user in "${old_domain_users[@]}"; do
        local username_part=$(echo "$old_user" | cut -d'@' -f1)
        local new_user="${username_part}@${new_domain}"
        local old_home="/home/$old_user"
        local new_home="/home/$new_user"
        
        echo "Processing user: $old_user -> $new_user"
        log_message "INFO" "Processing user migration: $old_user -> $new_user"
        
        # Check if old home directory exists and has content
        if [[ ! -d "$old_home" ]]; then
            echo "  Skipping: Old home directory does not exist"
            log_message "WARNING" "Old home directory does not exist: $old_home"
            continue
        fi
        
        if [[ ! "$(ls -A "$old_home")" ]]; then
            echo "  Skipping: Old home directory is empty"
            log_message "INFO" "Old home directory is empty: $old_home"
            continue
        fi
        
        # Create new home directory
        echo "  Creating new home directory: $new_home"
        mkdir -p "$new_home"
        log_command "mkdir -p '$new_home'" "Create new home directory for $new_user"
        
        # Set proper ownership (will be updated when user first logs in)
        chown "$new_user" "$new_home" 2>/dev/null || true
        
        # Copy user files from old to new home directory
        echo "  Copying user files..."
        if cp -r "$old_home"/* "$new_home/" 2>/dev/null; then
            echo "  Successfully copied user files"
            log_message "INFO" "Successfully copied files for user: $old_user -> $new_user"
        else
            echo "  Warning: Some files may not have been copied"
            log_message "WARNING" "Some files may not have been copied for user: $old_user"
        fi
        
        # Create symlink from old home to new home
        echo "  Creating symlink from old to new home directory..."
        if ln -sf "$new_home" "$old_home"; then
            echo "  Successfully created symlink"
            log_message "INFO" "Successfully created symlink: $old_home -> $new_home"
        else
            echo "  Warning: Failed to create symlink"
            log_message "WARNING" "Failed to create symlink: $old_home -> $new_home"
        fi
        
        echo "  User migration completed: $old_user -> $new_user"
        echo ""
    done
    
    echo "Domain user profile migration completed"
    log_message "INFO" "Domain user profile migration completed successfully"
    echo ""
    echo "Note: Local user accounts have been left untouched as requested"
    echo "Domain user files have been moved and symlinks created for compatibility"
    echo ""
}

# Function: Join new domain
join_domain() {
    display_step "Joining New Domain"
    
    log_message "INFO" "Starting domain join process for: $new_domain"
    
    echo "Joining domain: $new_domain"
    echo "Admin user: $admin_user"
    echo ""
    
    if [[ "$DEMO_MODE" == true ]]; then
        # Simulate domain discovery
        echo "Demo Mode: Discovering domain: $new_domain"
        echo "This will check domain connectivity and configuration..."
        echo ""
        sleep 2
        echo "Domain discovery successful"
        echo "Domain configuration verified"
        echo ""
        
        # Simulate domain join
        echo "Demo Mode: Attempting to join domain..."
        sleep 3
        echo "Domain join command completed successfully"
        echo ""
        
        # Simulate verification
        echo "Demo Mode: Verifying domain join and connectivity..."
        sleep 2
        echo "Domain join verification successful!"
        echo "Domain is properly configured and connected"
        echo ""
        
        # Call the actual functions in demo mode for proper simulation
        discover_and_permit_users
        migrate_domain_profiles
        
        # Simulate home directory setup
        echo "Demo Mode: Enabling home directory creation..."
        sleep 1
        echo "Domain join completed successfully!"
        echo ""
        
        # Show simulated domain status
        display_step "Domain Status"
        echo "Demo Mode: Current domain configuration:"
        echo "  $new_domain"
        echo "    type: kerberos"
        echo "    realm-name: $new_domain"
        echo "    domain-name: $new_domain"
        echo "    configured: kerberos-member"
        echo "    server-software: active-directory"
        echo "    client-software: sssd"
        echo "    required-package: sssd-tools"
        echo "    required-package: sssd"
        echo "    required-package: libnss-sss"
        echo "    login-formats: %U@$new_domain"
        echo "    login-policy: allow-realm-logins"
        echo ""
        
        display_step "Migration Complete"
        echo "Demo Mode: The system has been successfully migrated to: $new_domain"
        log_message "INFO" "Demo Mode: Migration completed successfully"
        echo ""
        
        echo "Demo Mode: Next steps:"
        echo "1. Test login with a domain user"
        echo "2. Verify group memberships"
        echo "3. Check file permissions"
        echo ""
        echo "Demo Mode: If you encounter any issues, check the backup files in: $BACKUP_DIR"
        
        # Demo mode reboot prompt
        echo ""
        echo "Demo Mode: Would prompt for reboot (Y/n)"
        log_message "INFO" "Demo Mode: Domain join process completed successfully"
        return 0
    fi
    
    echo "Joining domain: $new_domain"
    echo "Admin user: $admin_user"
    echo ""
    
    # First try to discover the domain
    discover_domain
    
    # Attempt to join the domain
    echo "Attempting to join domain..."
    log_command "realm join -U '$admin_user' '$new_domain' --install=/" "Join domain"
    
    if [[ $? -eq 0 ]]; then
        echo "Domain join command completed successfully"
        log_message "INFO" "Domain join command completed successfully"
        echo ""
        
        # Discover and permit domain users
        discover_and_permit_users
        
        # Migrate domain user profiles
        migrate_domain_profiles
        
        # Verify the domain join actually worked by checking domain status
        echo "Verifying domain join and connectivity..."
        log_message "INFO" "Verifying domain join with realm list"
        
        # Wait a moment for services to settle
        sleep 3
        
        # Check domain status
        local domain_status=$(realm list 2>/dev/null)
        log_command "realm list" "Verify domain status"
        
        if echo "$domain_status" | grep -q "$new_domain"; then
            echo "Domain join verification successful!"
            echo "Domain is properly configured and connected"
            log_message "INFO" "Domain join verification successful for: $new_domain"
            echo ""
            
            # Enable home directory creation
            echo "Enabling home directory creation..."
            log_command "systemctl enable oddjobd" "Enable oddjobd service"
            log_command "systemctl start oddjobd" "Start oddjobd service"
            echo "Domain join completed successfully!"
            log_message "INFO" "Domain join process completed successfully"
            echo ""
            
            # Show domain status
            display_step "Domain Status"
            echo "Current domain configuration:"
            realm list
            
            display_step "Migration Complete"
            echo "The system has been successfully migrated to: $new_domain"
            log_message "INFO" "Migration completed successfully"
            echo ""
            
            echo "Next steps:"
            echo "1. Test login with a domain user"
            echo "2. Verify group memberships"
            echo "3. Check file permissions"
            echo ""
            echo "If you encounter any issues, check the backup files in: $BACKUP_DIR"
            
            # Prompt for reboot
            prompt_for_reboot
        else
            log_message "ERROR" "Domain join verification failed - domain not found in realm list"
            echo "Error: Domain join verification failed"
            echo "The realm join command appeared to succeed, but the domain is not properly configured"
            echo ""
            echo "=========================================="
            echo "DOMAIN JOIN FAILURE ANALYSIS"
            echo "=========================================="
            echo ""
            echo "WHAT HAPPENED:"
            echo "The system attempted to join the domain '$new_domain' but the verification"
            echo "step failed. This means the join command appeared to succeed, but the"
            echo "domain is not properly configured or accessible."
            echo ""
            echo "POSSIBLE CAUSES:"
            echo ""
            echo "1. NETWORK CONNECTIVITY ISSUES"
            echo "   - The system cannot reach the domain controller"
            echo "   - Firewall is blocking required ports (88, 389, 636, 135, 445, 464)"
            echo "   - Network configuration problems"
            echo ""
            echo "2. DNS RESOLUTION PROBLEMS"
            echo "   - The domain name cannot be resolved to an IP address"
            echo "   - DNS server is not configured correctly"
            echo "   - Domain controller DNS records are missing"
            echo ""
            echo "3. AUTHENTICATION ISSUES"
            echo "   - Admin username or password is incorrect"
            echo "   - Admin account doesn't have domain join permissions"
            echo "   - Account is locked or expired"
            echo ""
            echo "4. DOMAIN CONFIGURATION ISSUES"
            echo "   - Domain controller is not responding"
            echo "   - Domain trust relationship problems"
            echo "   - Domain controller service issues"
            echo ""
            echo "5. SYSTEM CONFIGURATION ISSUES"
            echo "   - System time is not synchronized with domain controller"
            echo "   - Required services are not running"
            echo "   - System hostname conflicts with domain"
            echo ""
            echo "IMMEDIATE TROUBLESHOOTING STEPS:"
            echo ""
            echo "1. Check network connectivity:"
            echo "   ping [domain-controller-ip]"
            echo "   telnet [domain-controller-ip] 389"
            echo ""
            echo "2. Verify DNS resolution:"
            echo "   nslookup $new_domain"
            echo "   dig $new_domain"
            echo ""
            echo "3. Check system time:"
            echo "   date"
            echo "   timedatectl status"
            echo ""
            echo "4. Verify domain controller accessibility:"
            echo "   realm discover $new_domain"
            echo ""
            echo "5. Check system logs:"
            echo "   journalctl -u sssd"
            echo "   journalctl -u realmd"
            echo ""
            echo "=========================================="
            echo "WHAT HAS BEEN COMPLETED"
            echo "=========================================="
            echo ""
            echo "Required packages installed"
            echo "System configuration backed up"
            echo "OZBACKUP emergency account created"
            echo "Current domain status detected"
            if [[ -n "$current_domain" ]]; then
                echo "Successfully left old domain: $current_domain"
            fi
            echo "Domain join command executed"
            echo "Domain join verification failed"
            echo ""
            echo "=========================================="
            echo "WHAT IS PENDING"
            echo "=========================================="
            echo ""
            echo "⏳ Domain join verification"
            echo "⏳ Domain user permission setup"
            echo "⏳ Domain user profile migration"
            echo "⏳ System reboot"
            echo ""
            echo "=========================================="
            echo "HOW TO REVERT CHANGES"
            echo "=========================================="
            echo ""
            echo "To revert all changes made so far:"
            echo ""
            echo "1. Run the revert command:"
            echo "   sudo ./Oz-Deb-Mig.sh --revert"
            echo ""
            echo "2. The revert process will:"
            echo "   - Restore system configuration files from backup"
            echo "   - Remove any domain join attempts"
            echo "   - Restore original domain settings (if any)"
            echo ""
            echo "3. Backup files are stored in: $BACKUP_DIR"
            echo "   You can manually restore files if needed"
            echo ""
            echo "=========================================="
            echo "TROUBLESHOOTING INFORMATION"
            echo "=========================================="
            echo ""
            echo "Full log file location: $LOG_FILE"
            echo ""
            echo "To revert to the previous domain configuration:"
            echo "  sudo $SCRIPT_NAME --revert"
            echo ""
            echo "Current domain status:"
            echo "----------------------------------------"
            realm list
            echo "----------------------------------------"
            echo ""
            echo "Please review the log file for detailed error information."
            echo "Refer to HELPME.md for additional troubleshooting steps"
            echo ""
            echo "Press Enter to continue or Ctrl+C to exit..."
            read -r
            exit 1
        fi
    else
        log_message "ERROR" "Failed to join domain: $new_domain"
        echo "Error: Failed to join domain: $new_domain"
        echo "Please check your credentials and domain configuration"
        echo "Refer to HELPME.md for troubleshooting steps"
        exit 1
    fi
}

# Function: Revert migration
revert_migration() {
    display_step "Reverting Migration"
    
    log_message "INFO" "Starting migration revert process"
    
    if [[ "$DEMO_MODE" == true ]]; then
        echo "Demo Mode: Would revert migration changes"
        log_message "INFO" "Demo Mode: Migration revert skipped"
        return 0
    fi
    
    echo "Reverting migration changes..."
    echo ""
    
    # Find the most recent backup
    local latest_backup=$(ls -td "$BACKUP_DIR"/backup_* 2>/dev/null | head -1)
    
    if [[ -z "$latest_backup" ]]; then
        log_message "ERROR" "No backup found for revert"
        echo "Error: No backup found to revert to"
        echo "Please check the backup directory: $BACKUP_DIR"
        exit 1
    fi
    
    echo "Found backup: $latest_backup"
    log_message "INFO" "Found backup for revert: $latest_backup"
    
    # Files to restore
    local files_to_restore=(
        "/etc/samba/smb.conf"
        "/etc/nsswitch.conf"
        "/etc/pam.d/common-session"
        "/etc/pam.d/common-auth"
        "/etc/pam.d/common-account"
        "/etc/pam.d/common-password"
    )
    
    # Restore each file
    for file in "${files_to_restore[@]}"; do
        local backup_file="$latest_backup$(basename "$file")"
        if [[ -f "$backup_file" ]]; then
            cp "$backup_file" "$file"
            echo "  Restored: $file"
            log_message "INFO" "Restored: $file"
        else
            log_message "WARNING" "Backup file not found: $backup_file"
        fi
    done
    
    echo "Migration reverted successfully"
    log_message "INFO" "Migration revert completed successfully"
    echo ""
    echo "Please reboot the system to complete the revert process"
}

# Function: Create OZBACKUP account
create_ozbackup_account() {
    display_step "Creating OZBACKUP Account"
    
    log_message "INFO" "Starting OZBACKUP account creation"
    
    if [[ "$DEMO_MODE" == true ]]; then
        echo "Demo Mode: Creating OZBACKUP emergency account..."
        echo "This account should only be used in emergency situations."
        echo ""
        
        # Simulate password input
        read -s -p "Enter password for OZBACKUP account: " demo_password
        echo ""
        read -s -p "Confirm password for OZBACKUP account: " demo_confirm
        echo ""
        
        if [[ "$demo_password" == "$demo_confirm" ]]; then
            echo "OZBACKUP account created successfully"
            echo "Username: OZBACKUP"
            echo "Password: [set by user]"
            log_message "INFO" "Demo Mode: OZBACKUP account created successfully"
        else
            echo "Passwords do not match. Please try again."
            read -s -p "Enter password for OZBACKUP account: " demo_password
            echo ""
            read -s -p "Confirm password for OZBACKUP account: " demo_confirm
            echo ""
            echo "OZBACKUP account created successfully"
            echo "Username: OZBACKUP"
            echo "Password: [set by user]"
            log_message "INFO" "Demo Mode: OZBACKUP account created successfully"
        fi
        
        echo ""
        echo "IMPORTANT: This account is for emergency access only!"
        echo "Do not use for regular operations."
        echo ""
        return 0
    fi
    
    echo "Creating OZBACKUP emergency account..."
    echo "This account should only be used in emergency situations."
    echo ""
    
    # Check if OZBACKUP user already exists
    if id "OZBACKUP" &>/dev/null; then
        echo "OZBACKUP account already exists."
        echo "Please verify the password for the existing account:"
        log_message "INFO" "OZBACKUP account already exists, verifying password"
    fi
    
    # Get password for OZBACKUP account
    while true; do
        read -s -p "Enter password for OZBACKUP account: " OZBACKUP_PASSWORD
        echo ""
        read -s -p "Confirm password for OZBACKUP account: " confirm_password
        echo ""
        
        if [[ "$OZBACKUP_PASSWORD" == "$confirm_password" ]]; then
            break
        else
            echo "Passwords do not match. Please try again."
            log_message "WARNING" "OZBACKUP password confirmation failed"
        fi
    done
    
    # Create OZBACKUP user if it doesn't exist
    if ! id "OZBACKUP" &>/dev/null; then
        log_command "useradd -m -s /bin/bash -G sudo OZBACKUP" "Create OZBACKUP user"
    fi
    
    # Set the password
    log_command "echo 'OZBACKUP:$OZBACKUP_PASSWORD' | chpasswd" "Set OZBACKUP password"
    
    # Create sudoers entry for OZBACKUP if it doesn't exist
    if [[ ! -f "/etc/sudoers.d/ozbackup" ]]; then
        echo "OZBACKUP ALL=(ALL:ALL) ALL" >> /etc/sudoers.d/ozbackup
        log_message "INFO" "Created sudoers entry for OZBACKUP"
    fi
    
    echo "OZBACKUP account configured successfully"
    echo "Username: OZBACKUP"
    echo "Password: [set by user]"
    log_message "INFO" "OZBACKUP account configured successfully"
    echo ""
    echo "IMPORTANT: This account is for emergency access only!"
    echo "Do not use for regular operations."
    echo ""
}

# Function: Notify remote users
notify_remote_users() {
    log_message "INFO" "Checking for remote users and sending notifications"
    
    if [[ "$DEMO_MODE" == true ]]; then
        echo "Demo Mode: Would notify remote users about migration process"
        return 0
    fi
    
    echo "Checking for remote users..."
    
    # Check for SSH connections
    local ssh_users=$(who | grep -E "pts|ssh" | awk '{print $1}' | sort -u)
    
    # Check for XRDP connections
    local xrdp_users=$(who | grep -E "xrdp|rdp" | awk '{print $1}' | sort -u)
    
    if [[ -n "$ssh_users" || -n "$xrdp_users" ]]; then
        echo "Remote users detected. Sending notification..."
        
        # Create notification message
        local notification_msg="WARNING: Domain migration in progress. System may be unavailable shortly. Please save your work and log out."
        
        # Notify SSH users
        if [[ -n "$ssh_users" ]]; then
            echo "SSH users detected: $ssh_users"
            for user in $ssh_users; do
                echo "$notification_msg" | write "$user" 2>/dev/null || true
                log_message "INFO" "Sent notification to SSH user: $user"
            done
        fi
        
        # Notify XRDP users
        if [[ -n "$xrdp_users" ]]; then
            echo "XRDP users detected: $xrdp_users"
            for user in $xrdp_users; do
                echo "$notification_msg" | write "$user" 2>/dev/null || true
                log_message "INFO" "Sent notification to XRDP user: $user"
            done
        fi
        
        # Send wall message to all users
        echo "Sending system-wide notification..."
        wall <<< "$notification_msg" 2>/dev/null || true
        log_message "INFO" "Sent system-wide notification"
        
        echo "Remote user notifications sent"
    else
        echo "No remote users detected"
        log_message "INFO" "No remote users detected"
    fi
    
    echo ""
}

# Function: Prompt for reboot
prompt_for_reboot() {
    echo ""
    echo "=========================================="
    echo "REBOOT REQUIRED"
    echo "=========================================="
    echo ""
    echo "A reboot is required for domain changes to take effect properly."
    echo "This ensures all authentication and user settings are properly configured."
    echo ""
    
    # Notify remote users before asking about reboot
    notify_remote_users
    
    while true; do
        read -p "Do you want to reboot now? (Y/n): " reboot_choice
        case $reboot_choice in
            [Yy]|"")
                echo ""
                echo "Rebooting system..."
                log_message "INFO" "User chose to reboot system"
                sleep 2
                reboot
                ;;
            [Nn])
                echo ""
                echo "Reboot skipped. Please reboot manually when convenient."
                echo "Remember: Domain changes will not take full effect until reboot."
                log_message "INFO" "User chose to skip reboot"
                break
                ;;
            *)
                echo "Please enter Y (yes) or N (no)"
                ;;
        esac
    done
}

# Function: Main migration process
main_migration() {
    # Detect current domain status
    detect_current_domain
    
    # If no current domain detected, proceed directly to domain join
    if [[ $? -ne 0 ]]; then
        echo "No domain currently configured. Proceeding with domain join..."
        log_message "INFO" "No current domain detected, proceeding with domain join"
        join_domain
    else
        # Try to leave the current domain
        leave_domain
        
        echo "Domain leave process completed."
        echo ""
        echo "Proceeding with domain join..."
        echo ""
        
        join_domain
    fi
}

# Function: Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --demo)
                DEMO_MODE=true
                shift
                ;;
            --revert)
                REVERT_MODE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Function: Main execution
main() {
    # Initialize logging
    init_logging
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check if running as root
    check_root
    
    # Execute migration process
    display_banner
    install_packages
    create_backup_directory
    create_system_backups
    create_ozbackup_account
    
    if [[ "$REVERT_MODE" == true ]]; then
        revert_migration
    else
        get_domain_information
        main_migration
    fi
    
    log_message "INFO" "Script execution completed successfully"
}

# Run main function with all arguments
main "$@"

# =============================================================================
# =============================================================================

# =============================================================================
# Watermark
# =============================================================================
# ⢀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⣠⣤⣶⣶
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⢰⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⣀⣀⣾⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⡏⠉⠛⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⣿
# ⣿⣿⣿⣿⣿⣿⠀⠀⠀⠈⠛⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠛⠉⠁⠀⣿
# ⣿⣿⣿⣿⣿⣿⣧⡀⠀⠀⠀⠀⠙⠿⠿⠿⠻⠿⠿⠟⠿⠛⠉⠀⠀⠀⠀⠀⣸⣿
# ⣿⣿⣿⣿⣿⣿⣿⣷⣄⠀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣴⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⢰⣹⡆⠀⠀⠀⠀⠀⠀⣭⣷⠀⠀⠀⠸⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠈⠉⠀⠀⠤⠄⠀⠀⠀⠉⠁⠀⠀⠀⠀⢿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⢾⣿⣷⠀⠀⠀⠀⡠⠤⢄⠀⠀⠀⠠⣿⣿⣷⠀⢸⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⡀⠉⠀⠀⠀⠀⠀⢄⠀⢀⠀⠀⠀⠀⠉⠉⠁⠀⠀⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⠀⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿
# Coded By Oscar
# =============================================================================

# Script completed successfully
exit 0
