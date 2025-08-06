# Oz Domain Migration Script

A comprehensive Debian system migration tool for transitioning between Active Directory domains. This script handles the complete process of leaving an old domain and joining a new one, including user profile migration and system configuration management.

## Overview

The Oz Domain Migration Script automates the complex process of migrating a Debian system from one Active Directory domain to another. It handles all the necessary steps including package installation, system backups, domain operations, user permission management, and profile migration.

## Features

- **Automated Domain Operations**: Leaves current domain and joins new domain
- **System Backup Management**: Creates comprehensive backups before making changes
- **User Profile Migration**: Optionally migrates domain user profiles with symlink creation
- **Emergency Access**: Creates OZBACKUP emergency account for recovery
- **Comprehensive Logging**: Detailed logging with automatic log file opening on failure
- **Demo Mode**: Dry-run mode to preview changes without making them
- **Revert Functionality**: Ability to rollback changes if needed
- **Non-Interactive Installation**: Automated package installation without prompts

## Requirements

- Debian-based system (only tested with Debian, not ubuntu but expect would function the same)
- Root privileges (must be run with sudo)
- Active Directory domain access
- Admin credentials for the target domain
- Network connectivity to domain controllers

## Installation

1. Download the script to your system
2. Make it executable:
   ```bash
   chmod +x Oz-Deb-Mig.sh
   ```
3. Run as root:
   ```bash
   sudo ./Oz-Deb-Mig.sh
   ```

## Usage

### Standard Migration
```bash
sudo ./Oz-Deb-Mig.sh
```
The script will prompt for:
- New domain name
- Admin username for the new domain

### Demo Mode
```bash
sudo ./Oz-Deb-Mig.sh --demo
```
Shows what would happen without making any changes.

### Revert Changes
```bash
sudo ./Oz-Deb-Mig.sh --revert
```
Restores system to previous configuration.

### Help
```bash
sudo ./Oz-Deb-Mig.sh --help
```
Displays usage information and options.

## Project Structure

```
Oz-Deb-Mig/
├── Oz-Deb-Mig.sh          # Main migration script
├── README.md              # This documentation file
├── HELPME.md              # Troubleshooting guide
└── LICENSE                # MIT License
```

## Code Analysis

### File Breakdown
- **Main Script**: `Oz-Deb-Mig.sh` (1,775 lines)
- **Documentation**: `README.md`, `HELPME.md`, `LICENSE`

### Code vs Comments Ratio
The main script contains approximately:
- **Code Lines**: ~890 lines (50%)
- **Comment Lines**: ~885 lines (50%)

This achieves the target 50/50 split between code and comments for maximum readability and maintainability.

### Function Breakdown

#### Core Functions
- `main()`: Entry point and overall script flow control
- `parse_arguments()`: Command line argument processing
- `check_root()`: Root privilege verification

#### Logging and Error Handling
- `init_logging()`: Log file initialization and setup
- `log_message()`: Structured message logging
- `log_command()`: Command execution logging
- `handle_failure()`: Comprehensive error handling and recovery guidance

#### Display and User Interface
- `display_banner()`: Script banner with figlet/lolcat theming
- `display_step()`: Step header display
- `show_help()`: Help information display

#### System Operations
- `install_packages()`: Required package installation with non-interactive mode
- `create_backup_directory()`: Backup directory creation
- `create_system_backups()`: System configuration file backups
- `create_ozbackup_account()`: Emergency access account creation

#### Domain Operations
- `get_domain_information()`: User input collection for domain details
- `detect_current_domain()`: Current domain status detection
- `discover_domain()`: Domain connectivity and configuration verification
- `leave_domain()`: Domain leave process
- `join_domain()`: Domain join process with verification

#### User Management
- `discover_and_permit_users()`: Domain user discovery and permission setup
- `migrate_domain_profiles()`: User profile migration with symlink creation

#### System Services
- `notify_remote_users()`: Remote user notification before reboot
- `prompt_for_reboot()`: User-controlled reboot process
- `revert_migration()`: System restoration from backups

### Key Features Explained

#### Automated Package Installation
The script uses `DEBIAN_FRONTEND=noninteractive` and `debconf-set-selections` to automatically handle Kerberos configuration prompts, eliminating the need for manual intervention during package installation.

#### User Discovery Logic
The script scans the `/home` directory to find:
- Domain users (usernames containing `@`)
- Local users (usernames without `@`)
- Processes only domain users from the current domain for migration

#### Profile Migration Process
When enabled, the script:
1. Copies user files from old domain home directories to new domain home directories
2. Creates symlinks from old paths to new paths for application compatibility
3. Preserves all user data while ensuring seamless transition

#### Emergency Recovery
The OZBACKUP account provides emergency access in case of issues:
- Created at the start of the migration process
- Password set by the user
- Full sudo privileges for system recovery

## Troubleshooting

For detailed troubleshooting information, see `HELPME.md`. This guide covers:
- Common error scenarios and solutions
- Network connectivity issues
- DNS resolution problems
- Authentication failures
- Emergency recovery procedures

## Logging

The script creates detailed logs in `/root/migration-backups/` including:
- All command executions and their output
- Error messages and warnings
- User discovery and processing details
- System backup information

Log files are automatically opened in a text editor if the script fails, providing immediate access to troubleshooting information.

## Safety Features

- **Comprehensive Backups**: All system configuration files are backed up before changes
- **Demo Mode**: Test the migration process without making changes
- **Revert Functionality**: Rollback changes if needed
- **Emergency Account**: OZBACKUP account for recovery access
- **User Confirmation**: Prompts for critical operations like profile migration and reboot

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.

## Support

For issues and questions:
1. Check the log files in `/root/migration-backups/`
2. Review `HELPME.md` for troubleshooting guidance
3. Ensure all requirements are met before running the script

The script includes comprehensive error handling and will provide specific guidance based on the type of failure encountered.

---

<!--
⢀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⣠⣤⣶⣶
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⢰⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⣀⣀⣾⣿⣿⣿⣿
⣿⣿⣿⣿⣿⡏⠉⠛⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⣿
⣿⣿⣿⣿⣿⣿⠀⠀⠀⠈⠛⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠛⠉⠁⠀⣿
⣿⣿⣿⣿⣿⣿⣧⡀⠀⠀⠀⠀⠙⠿⠿⠿⠻⠿⠿⠟⠿⠛⠉⠀⠀⠀⠀⠀⣸⣿
⣿⣿⣿⣿⣿⣿⣿⣷⣄⠀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣴⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⢰⣹⡆⠀⠀⠀⠀⠀⠀⣭⣷⠀⠀⠀⠸⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠈⠉⠀⠀⠤⠄⠀⠀⠀⠉⠁⠀⠀⠀⠀⢿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⢾⣿⣷⠀⠀⠀⠀⡠⠤⢄⠀⠀⠀⠠⣿⣿⣷⠀⢸⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⡀⠉⠀⠀⠀⠀⠀⢄⠀⢀⠀⠀⠀⠀⠉⠉⠁⠀⠀⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⠀⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿
Coded By Oscar
-->
