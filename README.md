# Debian Domain Migration Script

A comprehensive script for migrating Debian/Ubuntu systems between Active Directory domains with user profile migration and safety features.

## Quick Start

```bash
# Download and make executable
chmod +x oz-deb-migration-improved.sh

# Test run (safe, no changes)
sudo ./oz-deb-migration-improved.sh --dry-run

# Standard migration
sudo ./oz-deb-migration-improved.sh --live

# Full migration with rollback points
sudo ./oz-deb-migration-improved.sh --technician
```

## Features

- **Complete Domain Migration**: Leave old domain, join new domain
- **User Profile Migration**: Move home directories with symlink creation
- **Multiple Safety Modes**: Dry-run, Live, and Technician modes
- **State Tracking**: Resume interrupted migrations
- **Rollback Points**: Complete system snapshots (Technician mode)
- **Local Account Detection**: Smart filtering of non-domain accounts
- **Time Synchronisation**: Automatic NTP fixes
- **Domain Controller Discovery**: Automatic DC detection
- **Comprehensive Logging**: Detailed migration logs
- **Account Creation**: Create missing user accounts on new domain

## Overview

This script handles the complete process of leaving one domain and joining another, including user home directory migration, account validation, and comprehensive backup/rollback options. Built for reliability with multiple safety nets to prevent getting locked out of systems.

## What It Does

### Pre-Migration Checks
- Verifies root access and installs required packages (realmd, sssd, etc.)
- Creates backup local sudo account to prevent lockouts
- Checks internet connectivity and warns about active user sessions
- Shows current domain status via `realm list`

### Domain Migration Process
- Prompts for new domain name and admin credentials
- Tests Kerberos authentication before proceeding
- Creates timestamped backups of critical config files
- Leaves current domain and discovers new domain
- Joins new domain with validation
- Updates hostname to match new domain

### User Profile Migration
- Finds all users with @olddomain in home directories
- Migrates home folders to @newdomain structure
- Creates symlinks from old to new paths for compatibility
- Handles local accounts intelligently (skips system/service accounts)
- Attempts to create missing user accounts on new domain
- Updates file ownership to new domain users

### Post-Migration Setup
- Configures SSSD and Kerberos settings
- Sets up sudo access for new domain users
- Validates domain membership and connectivity
- Provides rollback options if needed

## Modes

### Technician Mode
Full migration with complete system snapshots (~50-100MB each). Best for production environments where maximum safety is needed.

### Live Mode
Standard migration with essential safety features. Creates file-based backups and includes progress tracking.

### Dry-Run Mode
Test run without making any system changes. Perfect for validating settings on domainless VMs.

## Safety Features

- **State Tracking**: Saves progress to `/tmp/migration-state` for resuming interrupted migrations
- **Rollback Points**: Complete system snapshots in Technician Mode
- **Backup Verification**: Ensures all backups are valid before proceeding
- **Concurrent User Handling**: Gracefully manages active sessions
- **Local Account Detection**: Identifies and skips non-domain accounts

## Usage

```bash
# Technician Mode (full features)
sudo ./oz-deb-migration-improved.sh --technician

# Live Mode (standard)
sudo ./oz-deb-migration-improved.sh --live

# Dry-Run Mode (test only)
sudo ./oz-deb-migration-improved.sh --dry-run

# Revert to previous domain
sudo ./oz-deb-migration-improved.sh --revert

# Show help
sudo ./oz-deb-migration-improved.sh --help
```

## Prerequisites

- Root access on target system
- Internet connectivity
- Valid domain admin credentials for new domain
- Debian/Ubuntu system (tested on Debian 11/12, Ubuntu 20.04/22.04)

## Post-Migration

After migration completes:
1. Reboot the system (required)
2. Run the verification script: `sudo ./oz-post-migration-checklist.sh`

The verification script checks:
- Domain membership status
- Kerberos authentication
- SSSD service health
- Network connectivity
- User accessibility

## Troubleshooting

### Common Issues

**Can't log in with domain user:**
- Check SSSD logs: `tail -f /var/log/sssd/sssd.log`
- Clear cache: `sssctl cache-remove`
- Restart SSSD: `systemctl restart sssd`

**DNS resolution issues:**
- Check `/etc/resolv.conf`
- Verify DNS server settings
- Test: `nslookup yourdomain.com`

**Kerberos authentication fails:**
- Check system time: `timedatectl status`
- Enable NTP: `timedatectl set-ntp true`
- Test: `kinit username@yourdomain.com`

**Sudo access not working:**
- Check sudoers: `sudo -l -U username@yourdomain.com`
- Verify group membership: `groups username@yourdomain.com`

**Need to revert changes:**
- Run: `sudo ./oz-deb-migration-improved.sh --revert`
- Or manually restore backups: `ls -la /etc/*.backup.*`

## Files Modified

The script modifies these system files:
- `/etc/hosts`
- `/etc/hostname`
- `/etc/krb5.conf`
- `/etc/sssd/sssd.conf`
- `/etc/resolv.conf`
- Network configuration files
- User home directories

All changes are backed up with timestamps before modification.

## State Tracking

Progress is saved to `/tmp/migration-state` in format:
```
STEP=X|MODE=Y|DOMAIN=Z|HOSTNAME=A
```

If interrupted, the script will offer to resume from the last completed step.

## Rollback Points

Technician Mode creates complete system snapshots including:
- All `/etc/` configuration files
- Network settings
- User data and system state
- Machine ID and SSSD cache

Each rollback point is approximately 50-100MB and stored in `/root/migration-rollbacks/`.

## Local Account Detection

The script automatically detects local (non-domain) accounts by:
- Checking for usernames without @domain suffixes
- Looking for local account markers in `/etc/passwd` comments
- Searching for marker files (`.local_account`, `.skip_migration`) in home directories
- Examining user profile files for local account indicators

Local accounts can be skipped during migration to prevent accidental changes to system accounts.

## User Profile Migration

For each domain user found, the script:
1. Creates new home directory with @newdomain suffix
2. Copies all files and settings from old to new location
3. Creates symlink from old path to new path
4. Updates file ownership to new domain user
5. Handles conflicts by merging or backing up existing folders

A detailed log is created at `/var/log/user-migration-*.log`.

## Account Creation

If users exist on old domain but not new domain:
- Attempts to create missing accounts using domain tools
- Uses `samba-tool` (preferred) or `ldapadd` (fallback)
- Asks for confirmation before each account creation
- Retries profile migration for newly created accounts

## Support Files

- Migration logs: `/var/log/user-migration-*.log`
- Account creation logs: `/var/log/account-creation-*.log`
- State tracking: `/tmp/migration-state`
- Rollback points: `/root/migration-rollbacks/`
- User mapping: `/etc/domain-user-mapping.conf`

## Notes

- The script requires a reboot after completion
- All domain users will need sudo access configured after migration
- Local accounts are preserved and can be skipped
- The backup local sudo account is removed by the verification script
- SSL/TLS certificate validation is disabled for ethernet networks

## Testing

Test the script on a domainless Debian VM using Dry-Run Mode before using on production systems. The script is designed to be safe but always verify backups before proceeding.

## Tools and Commands Used

### Core Domain Tools

**realmd** - Domain membership management
- *Technical*: Daemon that handles joining/leaving Active Directory domains, manages domain discovery and authentication
- *Simple*: The main tool that connects your computer to a company network, like joining a Windows domain

**sssd** (System Security Services Daemon)
- *Technical*: Provides access to remote authentication and identity sources, caches user information locally
- *Simple*: Stores and manages user account information from the company network, so you can log in even when offline

**adcli** - Active Directory command line interface
- *Technical*: Command-line tool for managing Active Directory objects and authentication
- *Simple*: Lets you create and manage user accounts on the company network from your computer

**samba-tool** - Samba administration tool
- *Technical*: Comprehensive tool for managing Samba/Active Directory services, user creation, group management
- *Simple*: Advanced tool for creating and managing user accounts on the company network

### Authentication and Security

**Kerberos** - Network authentication protocol
- *Technical*: Ticket-based authentication system that provides secure authentication without sending passwords over the network
- *Simple*: A secure way to prove who you are to the company network without sending your password

**kinit** - Kerberos ticket initialization
- *Technical*: Obtains and caches Kerberos authentication tickets for a user
- *Simple*: Logs you into the company network securely

**klist** - Kerberos ticket listing
- *Technical*: Displays current Kerberos tickets and their status
- *Simple*: Shows whether you're currently logged into the company network

### Network and DNS

**dig** - DNS lookup utility
- *Technical*: Queries DNS servers for domain information, SRV records, and name resolution
- *Simple*: Looks up information about company network servers and their addresses

**nslookup** - Name server lookup
- *Technical*: Interactive tool for querying DNS servers and testing name resolution
- *Simple*: Tests whether your computer can find company network servers by name

**ping** - Network connectivity test
- *Technical*: Sends ICMP echo requests to test network connectivity and response times
- *Simple*: Checks if your computer can reach other computers on the network

### System Management

**timedatectl** - System time and date control
- *Technical*: Controls system clock, timezone, and NTP synchronization settings
- *Simple*: Manages your computer's clock and keeps it synchronised with company network time

**systemctl** - System service control
- *Technical*: Controls systemd services, starts/stops daemons, checks service status
- *Simple*: Starts, stops, and checks whether important background programs are running

**hostnamectl** - Hostname control
- *Technical*: Displays and modifies system hostname and related information
- *Simple*: Changes your computer's name on the network

### File and User Management

**rsync** - Remote synchronisation
- *Technical*: Efficient file copying and synchronisation tool with delta-transfer algorithm
- *Simple*: Copies files and folders quickly, only copying what's changed

**chown** - Change ownership
- *Technical*: Changes file and directory ownership to specified user/group
- *Simple*: Changes who "owns" files so the right person can access them

**getent** - Get entries from administrative database
- *Technical*: Retrieves entries from system databases like passwd, group, hosts
- *Simple*: Looks up information about users, groups, and network addresses

**usermod** - User modification
- *Technical*: Modifies user account properties, comments, and group memberships
- *Simple*: Changes user account settings and information

### Backup and Archive

**tar** - Tape archive
- *Technical*: Creates compressed archives of files and directories
- *Simple*: Packs up files into a single compressed file for backup

**cp** - Copy
- *Technical*: Copies files and directories with various options
- *Simple*: Makes copies of files and folders

**mv** - Move
- *Technical*: Moves or renames files and directories
- *Simple*: Moves files to different locations or renames them

### Configuration Files

**/etc/hosts** - Local hostname resolution
- *Technical*: Static table lookup for hostnames, maps hostnames to IP addresses
- *Simple*: A list that tells your computer what names match which network addresses

**/etc/krb5.conf** - Kerberos configuration
- *Technical*: Configuration file for Kerberos authentication settings and realm information
- *Simple*: Settings file that tells your computer how to connect to the company network

**/etc/sssd/sssd.conf** - SSSD configuration
- *Technical*: Configuration file for System Security Services Daemon settings
- *Simple*: Settings file that controls how user accounts are managed

**/etc/resolv.conf** - DNS resolver configuration
- *Technical*: Configuration file for DNS name resolution settings
- *Simple*: Settings file that tells your computer how to find other computers on the network

### Logging and Monitoring

**tail** - Display file endings
- *Technical*: Displays the last lines of files, often used with -f for real-time monitoring
- *Simple*: Shows the most recent messages from log files

**grep** - Global regular expression print
- *Technical*: Searches for patterns in text files using regular expressions
- *Simple*: Finds specific words or phrases in files

**awk** - Text processing language
- *Technical*: Pattern scanning and processing language for text manipulation
- *Simple*: Tool for extracting and processing specific parts of text

### Visual and Display

**figlet** - ASCII art text
- *Technical*: Creates large text banners using ASCII characters
- *Simple*: Makes big, fancy text displays

**lolcat** - Rainbow colour output
- *Technical*: Adds rainbow colouring to text output
- *Simple*: Makes text appear in different colours

---

## Changelog

### v3.0.0 (Current)
- Comprehensive domain migration with enhanced safety features
- Three safety modes: Dry-run, Live, and Technician
- User profile migration with symlink creation
- Local account detection and filtering
- State tracking for interrupted migrations
- Rollback points for complete system recovery
- Domain controller discovery and time synchronisation
- Account creation for missing users
- Enhanced backup verification and validation

## Contributing

Feel free to submit issues, feature requests, or pull requests. This project is open to contributions from the community.

## License

This project is licensed under the MIT License with Attribution Clause.

### MIT License with Attribution

Copyright (c) 2024 Oscar

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in all
   copies or substantial portions of the Software.

2. **Attribution Requirement**: Any use, modification, or distribution of this
   software must include clear attribution to the original author (Oscar) and
   a link to the original repository where possible.

3. **No Warranty**: THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
   EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
   OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
   ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
   DEALINGS IN THE SOFTWARE.

### Attribution Examples

When using this code, please include attribution such as:
- "Based on Debian Domain Migration Script by Oscar"
- "Original work by Oscar - https://github.com/yourusername/debian-domain-migration"
- "Credits: Oscar's Domain Migration Script"

---

Thank you for reading and looking at my project -Oscar :) 