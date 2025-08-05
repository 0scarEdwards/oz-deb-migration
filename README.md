# Oz Debian Domain Migration Script V5.0.0

A toolkit for migrating Debian systems between Active Directory domains with user profile migration, safety features, and automation capabilities.

## Version 5.0.0

This version represents a complete rewrite and optimization of the domain migration process:

- **Simplified Domain Join**: Standard realm join process without unnecessary discovery steps
- **Cleaner Output**: Eliminated verbose system checks and unnecessary warnings
- **Reliability**: Streamlined workflow with fewer failure points
- **Error Handling**: Robust error handling throughout the migration process
- **Complete Automation**: Full end-to-end automation with reboot and verification

## Key Features

### Streamlined Domain Migration
- **Standard Process**: Uses the proven `realm join` command for reliable domain joining
- **Simplified Domain Join**: Standard realm join process without unnecessary discovery steps
- **Simplified Workflow**: Streamlined process optimized for reliability and speed
- **Error Recovery**: Graceful handling of failures with user choice options

### Safety Features
- **Configuration Backups**: Timestamped backups of all critical system files
- **Progress Tracking**: State persistence across interruptions and reboots
- **Backup Accounts**: Emergency local sudo account creation to prevent lockouts
- **Rollback Options**: Complete system restoration capabilities

### User Profile Migration
- **Intelligent Detection**: Automatically identifies domain users vs local accounts
- **Complete Migration**: Moves home directories, settings, and file ownership
- **Conflict Resolution**: Handles existing directories with merge or backup options
- **Compatibility Links**: Creates symlinks for seamless application compatibility

### Professional Automation
- **One-Command Migration**: Complete automation with `oz-migration-automator.sh`
- **Automatic Reboot**: Handles system restart and post-reboot verification
- **Test Mode**: Safe simulation without making system changes
- **Logging**: Detailed logs for troubleshooting and audit trails

### Quality Features
- **Error Handling**: Robust error management with user-friendly messages
- **Validation**: Verification of domain functionality
- **Documentation**: Detailed inline comments and user guidance
- **Maintainability**: Clean, well-structured code for easy maintenance

### Quick Start

#### Manual Migration
# Download and make executable
chmod +x oz-deb-migration-improved.sh

# Standard migration
sudo ./oz-deb-migration-improved.sh --live

#### Automated Migration (Recommended)
# Make automator executable
chmod +x oz-migration-automator.sh

# Complete automation (includes reboot and verification)
sudo ./oz-migration-automator.sh

## Overview

This toolkit provides two approaches to domain migration:

### Manual Migration
Should handle the complete process of leaving one domain and joining another, including user home directory migration, account validation, and backup/rollback options.

### Automated Migration
The `oz-migration-automator.sh` script provides complete automation:
- Runs the migration script as root
- Automatically reboots the system after migration
- Runs post-migration verification after reboot
- Provides logging and error handling
- No manual intervention required

### How It Works

The migration process follows a streamlined workflow designed for reliability and simplicity:

#### Core Migration Steps
1. **Input Collection**: Gather domain information and admin credentials
2. **System Preparation**: Install required packages and create backup accounts
3. **Current Status Check**: Verify current domain membership
4. **Configuration Backup**: Create timestamped backups of critical files
5. **Domain Transition**: Leave current domain and join new domain
6. **System Configuration**: Update hostname, network, and authentication settings
7. **Service Configuration**: Configure PAM/NSS and home directory creation
8. **Verification**: Testing of domain functionality
9. **User Migration**: Migrate user profiles and home directories
10. **Final Setup**: Configure sudo access and generate migration report

The process includes error handling, progress tracking, and safety features throughout each step.

## Pre-Migration Checks
- Verifies root access and installs required packages (realmd, sssd, etc.)
- Creates backup local sudo account to prevent lockouts (unsure if this is something to be concerned with in Linux but just incase)
- Checks internet connectivity and warns about active user sessions (figured would be useful for build servers etc with xrdp sessions)
- Shows current domain status via realm list

## Domain Migration Process
- Prompts for new domain name and admin credentials
- Tests Kerberos authentication before proceeding
- Creates timestamped backups of critical config files
- Uses standard realm join process for domain joining
- Leaves current domain and joins new domain with validation
- Updates hostname to match new domain

## User Profile Migration
- Finds all users with @olddomain in home directories
- Migrates home folders to @newdomain structure
- Creates symlinks from old to new paths for compatibility
- Handles local accounts intelligently (skips system/service accounts) - hoping this doesn't disturb any build server machines where possible as doubt they'd be with a domain account
- Updates file ownership to new domain users

## Post-Migration Setup
- Configures SSSD and Kerberos settings
- Sets up sudo access for new domain users
- Validates domain membership and connectivity
- Provides rollback options if needed

### Modes

#### Manual Migration Modes
## Live Mode
Standard migration with essential safety features. Creates file-based backups and includes progress tracking.
```bash
sudo ./oz-deb-migration-improved.sh --live
```

## Revert Mode
Revert to previous domain configuration.
```bash
sudo ./oz-deb-migration-improved.sh --revert
```

## Help
Show usage information and available options.
```bash
sudo ./oz-deb-migration-improved.sh --help
```

**Note**: Dry-run functionality has been moved to the automator script for better testing capabilities.

#### Automated Migration Modes
## Standard Automation
Runs with user prompts and confirmation dialogs.
```bash
sudo ./oz-migration-automator.sh
```

## Test Mode
Simulates the entire migration process without making changes. Perfect for validating script functionality and syntax.
```bash
sudo ./oz-migration-automator.sh --test
```

## Auto Mode
Fully automatic with no user prompts.
```bash
sudo ./oz-migration-automator.sh --auto
```

## Custom Reboot Delay
Set custom reboot delay (default: 15 seconds).
```bash
sudo ./oz-migration-automator.sh --reboot-delay 30
```

## Installation

### Requirements

**System Requirements:**
- Debian-based Linux distribution (Debian, Ubuntu, Linux Mint, etc.)
- Root/sudo access
- Network connectivity to domain controllers
- Minimum 1GB available disk space for backups

**Required Packages:**
The script will automatically install these packages if not present:
- `realmd` - Domain joining and management
- `sssd` - System Security Services Daemon
- `sssd-tools` - SSSD management tools
- `krb5-user` - Kerberos authentication tools
- `oddjob-mkhomedir` - Automatic home directory creation
- `figlet` - ASCII art display (optional, for output)
- `lolcat` - Color output (optional, for display)

### Download and Setup

```bash
# Clone or download the repository
git clone https://github.com/yourusername/debian-domain-migration.git
cd debian-domain-migration

# Make scripts executable
chmod +x oz-deb-migration-improved.sh
chmod +x oz-migration-automator.sh
chmod +x oz-post-migration-checklist.sh

# Verify installation
ls -la *.sh
```

### Prerequisites

- Root access
- Internet connectivity
- Valid domain admin credentials for new domain
- Debian/Ubuntu system (tested on Debian 12, not Ubuntu but imagine compatibility across flavours should be fine aslong as have same aptitude packages)

### Post-Migration

#### Manual Migration
After migration completes:
1. Reboot the system (required)
2. Run the verification script: sudo ./oz-post-migration-checklist.sh

The verification script checks:
- Domain membership status
- Kerberos authentication
- SSSD service health
- Network connectivity
- User accessibility

#### Automated Migration
The automator handles post-migration automatically:
1. Automatically reboots the system after migration
2. Runs post-migration verification after reboot
3. Provides completion report
4. Cleans up temporary files

## Brief troubleshooting steps found across multiple forums - take with pinch of salt:

Can't log in with domain user:
- Check SSSD logs: tail -f /var/log/sssd/sssd.log
- Clear cache: sssctl cache-remove
- Restart SSSD: systemctl restart sssd

Kerberos authentication fails:
- Check system time manually - Kerberos doesn't like if out of sync
- Enable NTP manually if needed
- kinit username@yourdomain.com - sometimes worth testing again

## Files Modified

The script modifies these system files:
- /etc/hosts
- /etc/hostname
- /etc/krb5.conf
- /etc/sssd/sssd.conf
- /etc/resolv.conf
- Network configuration files
- User home directories

All changes are backed up with timestamps before modification.

## State Tracking

Progress is saved to /tmp/migration-state in format:
STEP=X|MODE=Y|DOMAIN=Z|HOSTNAME=A

If interrupted, the script will offer to resume from the last completed step.

## File Backups

Live Mode creates timestamped backups of critical configuration files including:
- All /etc/ configuration files
- Network settings
- User data and system state
- Machine ID and SSSD cache

All backups are stored with timestamps for easy restoration if needed.

## Local Account Detection

The script automatically detects local (non-domain) accounts by:
- Checking for usernames without @domain suffixes
- Looking for local account markers in /etc/passwd comments
- Searching for marker files (.local_account, .skip_migration) in home directories
- Examining user profile files for local account indicators

Local accounts can be skipped during migration to prevent accidental changes to system accounts.

## User Profile Migration

For each domain user found, the script:
1. Creates new home directory with @newdomain suffix
2. Copies all files and settings from old to new location
3. Creates symlink from old path to new path
4. Updates file ownership to new domain user
5. Handles conflicts by merging or backing up existing folders

A detailed log is created at /var/log/user-migration-.log.

## Account Creation

If users exist on old domain but not new domain:
- Attempts to create missing accounts using domain tools
- Uses samba-tool (preferred) or ldapadd (fallback)
- Asks for confirmation before each account creation
- Retries profile migration for newly created accounts

## Support Files

- Migration logs: /var/log/user-migration-.log
- Account creation logs: /var/log/account-creation-.log
- State tracking: /tmp/migration-state
- File backups: /etc/ with .backup timestamps
- User mapping: /etc/domain-user-mapping.conf

## Troubleshooting

### Common Issues

**Domain Join Failures:**
```bash
# Check domain connectivity
ping -c 3 yourdomain.com

# Verify DNS resolution
nslookup yourdomain.com

# Test Kerberos authentication
kinit admin@yourdomain.com

# Check SSSD status
systemctl status sssd
sssctl domain-list
```

**User Authentication Issues:**
```bash
# Clear SSSD cache
sssctl cache-remove

# Check user lookup
getent passwd username@domain.com

# Verify PAM configuration
pam-auth-update

# Check home directory creation
systemctl status oddjobd
```

**Network Connectivity Problems:**
```bash
# Check network interfaces
ip addr show

# Test domain controller connectivity
ping -c 3 dc1.yourdomain.com

# Verify firewall settings
iptables -L | grep -E "(389|636|88|464)"
```

### Recovery Options

**If Migration Fails:**
1. Check the migration logs: `/var/log/user-migration-*.log`
2. Review system logs: `journalctl -u sssd`
3. Use the backup account: `su - backup` (password: backup)
4. Restore from backups: Check `/root/migration-rollbacks/`

**Manual Recovery:**
```bash
# Restore SSSD configuration
cp /etc/sssd/sssd.conf.backup.* /etc/sssd/sssd.conf

# Restore Kerberos configuration
cp /etc/krb5.conf.backup.* /etc/krb5.conf

# Restart services
systemctl restart sssd
systemctl restart oddjobd
```

### Log Files

- **Migration Logs**: `/var/log/user-migration-*.log`
- **SSSD Logs**: `/var/log/sssd/sssd.log`
- **System Logs**: `journalctl -u sssd`
- **Automation Logs**: `/var/log/oz-migration-automator.log`

## Notes

- The script requires a reboot after completion
- All domain users will need sudo access configured after migration
- Local accounts are preserved and can be skipped
- The backup local sudo account is removed by the verification script

## Contributing

This project is open to contributions! Please feel free to submit issues, feature requests, or pull requests.

### Development Guidelines
- Follow the existing code style and structure
- Add comments for new functionality
- Test thoroughly before submitting changes
- Update documentation for any new features

## License

This project is licensed under the MIT License with Attribution Clause - see the [LICENSE](LICENSE) file for details.

## Support

For support, please:
1. Check the troubleshooting section above
2. Review the log files for error details
3. Open an issue on GitHub with detailed information
4. Include system information and error messages

---

**Coded by Oscar**

#### Tools and Commands Used

## Core Domain & Authentication Tools

realmd
Used for joining, leaving, and listing Active Directory domains.
("Joins your Linux machine to a Windows domain, or removes it.")

sssd
The service that handles domain user authentication and caching.
("Lets Linux check usernames and passwords against the domain, and keeps a local cache.")

sssctl
Command-line tool to manage and query SSSD.
("Used to clear SSSD's cache or list domain info.")

kinit
Gets a Kerberos ticket for a user.
("Logs you into the domain securely, so you can access resources.")

klist
Shows current Kerberos tickets.
("Lets you check if you're logged in to the domain.")

## System & Service Management

systemctl
Controls system services (start, stop, check status).
("Turns services like SSSD or oddjobd on and off, or checks if they're running.")

hostnamectl
Changes or displays the system's hostname.
("Sets your computer's name on the network.")

# timedatectl (currently disabled)
# Checks and sets system time and NTP sync.
# ("Makes sure your computer's clock matches the domain, which is critical for logins.")
# Note: Time synchronization is currently disabled in the script.

## Network & DNS

realm join
Joins the system to an Active Directory domain using standard domain join process.
("The primary command that joins your Linux machine to a Windows domain.")

ping
Tests network connectivity.
("Checks if you can reach another computer or server.")

## User & File Management

getent
Looks up users and groups from the system and domain.
("Checks if domain users and groups are visible to Linux.")

usermod
Modifies user accounts.
("Changes user settings, like group membership.")

chown
Changes file and folder ownership.
("Makes sure files belong to the right user after migration.")

cp, mv, rm, mkdir, ls, find, tar
Standard Linux file operations and archiving.
("Copy, move, delete, create, list, search, and archive files and folders.")

## Text Processing & Scripting

sed, awk, grep, cut, tr, sort, uniq, wc, head, tail
Used for searching, editing, and processing text in files and command output.
("Finds and changes settings in config files, or processes lists of users, etc.")

echo, cat, read, printf
Shell built-ins for displaying, reading, and writing text.
("Shows messages, reads user input, or writes to files.")

## Visual Output

figlet
Prints large ASCII art banners.
("Displays a big, fancy title at the start of the script.")

lolcat
Adds rainbow colours to terminal output.
("Makes banners and messages colourful for better visibility.")

## Automation Script

For complete automation of the migration process, use the `oz-migration-automator.sh` script:

### Features
- **One-command migration**: Run the entire process with a single command
- **Automatic reboot handling**: No manual intervention required
- **Post-reboot verification**: Automatic verification after system restart
- **Logging**: Detailed logs at `/var/log/oz-migration-automator.log`
- **Error recovery**: Graceful handling of failures
- **State persistence**: Remembers progress across reboots

### Usage
```bash
# Standard automation with prompts
sudo ./oz-migration-automator.sh

# Fully automatic mode (no prompts)
sudo ./oz-migration-automator.sh --auto

# Custom reboot delay (30 seconds)
sudo ./oz-migration-automator.sh --reboot-delay 30

# Show help
./oz-migration-automator.sh --help
```

### Documentation
For detailed information about the automation script, see `AUTOMATOR_README.md`.

## Project Structure and Code Analysis

### File Structure
```
Debian Migration Script/
├── oz-deb-migration-improved.sh      # Main migration script (3,785 lines)
├── oz-migration-automator.sh         # Automation wrapper (1,309 lines)
├── oz-post-migration-checklist.sh    # Verification script (563 lines)
├── README.md                         # Main documentation (523 lines)
├── AUTOMATOR_README.md               # Automation documentation (384 lines)
├── LICENSE                           # MIT License with attribution
└── archive/                          # Previous versions
    ├── oz-deb-migration-improved.sh  # Archive of previous versions
    └── AUTOMATOR_README.md           # Archive documentation
```

### Code Quality Metrics (circa~)
**Total Project Size**: 6,660 lines across all scripts
**Documentation Ratio**: 49% (comments + output)
**Functional Code**: 51% (actual migration logic)
### Near about an even split between code and comments ###


## Thank you for reading and looking at my project - Oscar ##