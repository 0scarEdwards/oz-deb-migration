# Oz Domain Migration Automator

An automation script that handles the domain migration process from start to finish, including automatic reboot and post-migration verification.

## Overview

The `oz-migration-automator.sh` script is a wrapper that automates the entire domain migration process:

1. **Runs the main migration script** as root in live mode
2. **Automatically reboots** the system after migration completion
3. **Runs post-migration verification** after reboot
4. **Provides logging** and error handling

## Quick Start

```bash
# Make executable (on Linux)
chmod +x oz-migration-automator.sh

# Run automation
sudo ./oz-migration-automator.sh

# Test mode (simulates migration without changes)
sudo ./oz-migration-automator.sh --test
```

## Features

### Complete Automation
- **One-command migration**: Run the entire process with a single command
- **Automatic reboot handling**: No manual intervention required
- **Post-reboot verification**: Automatic verification after system restart
- **State persistence**: Remembers progress across reboots
- **Test mode simulation**: Safe validation without making changes

### Safety Features
- **Pre-flight checks**: Validates system before starting
- **Logging**: Detailed logs at `/var/log/oz-migration-automator.log`
- **Error recovery**: Graceful handling of failures
- **User confirmation**: Prompts for confirmation (unless in auto mode)
- **Rollback capabilities**: Can handle migration failures

### Customization Options
- **Custom reboot delay**: Set how long to wait before reboot
- **Auto mode**: Run without user prompts
- **Test mode**: Simulate migration without changes
- **Progress tracking**: Real-time status updates
- **Flexible configuration**: Easy to modify settings

## Usage

### Basic Usage

```bash
# Standard automation with prompts
sudo ./oz-migration-automator.sh
```

### Advanced Options

```bash
# Custom reboot delay (30 seconds)
sudo ./oz-migration-automator.sh --reboot-delay 30

# Test mode (simulates migration without changes)
sudo ./oz-migration-automator.sh --test

# Fully automatic mode (no prompts)
sudo ./oz-migration-automator.sh --auto

# Show help
./oz-migration-automator.sh --help
```

## How It Works

### Phase 1: Pre-Migration
1. **System checks**: Validates Debian/Ubuntu system compatibility
2. **Dependency verification**: Ensures required scripts exist and are executable
3. **Pre-flight checks**: Disk space, network connectivity, active user sessions
4. **User confirmation**: Gets approval to proceed with migration

### Phase 2: Migration
1. **Runs main script**: Executes `oz-deb-migration-improved.sh --live` with simplified domain join
2. **Progress tracking**: Monitors migration progress and step completion
3. **Error handling**: Manages any migration failures with user choice options
4. **State saving**: Records completion status for resumption if needed

### Phase 3: Reboot
1. **Countdown timer**: Shows reboot countdown
2. **Auto-start setup**: Configures post-reboot execution
3. **State persistence**: Saves state for post-reboot
4. **System reboot**: Reboots the system

### Phase 4: Post-Reboot
1. **Auto-detection**: Detects post-reboot environment and resumes automation
2. **Verification**: Runs `oz-post-migration-checklist.sh` for validation
3. **Cleanup**: Removes temporary files and persistence mechanisms
4. **Completion**: Shows final status and provides next steps guidance

### Test Mode Flow
1. **Simulation**: Runs complete migration simulation without making changes
2. **Validation**: Tests all migration steps and script functionality
3. **Verification**: Simulates post-migration verification process
4. **Completion**: Shows test results and validation status

**Perfect for validating script functionality and syntax in safe environments.**

## Configuration

### Script Settings

The automator can be configured by editing these variables in the script:

```bash
REBOOT_DELAY=15          # Seconds to wait before reboot
LOG_FILE="/var/log/oz-migration-automator.log"  # Log file location
STATE_FILE="/tmp/oz-automator-state"            # State tracking file
```

### Logging

The automator creates logs:

- **Automation log**: `/var/log/oz-migration-automator.log`
- **Migration logs**: `/var/log/user-migration-*.log`
- **SSSD logs**: `/var/log/sssd/sssd.log`

### State Tracking

The automator uses state files to track progress:

- **Location**: `/tmp/oz-automator-state`
- **Purpose**: Remembers progress across reboots
- **Auto-cleanup**: Removed after completion

## Error Handling

### Common Issues

1. **Migration script fails**
   - Option to continue with reboot anyway
   - Detailed error logging
   - Manual recovery instructions

2. **Network connectivity issues**
   - Pre-flight network checks
   - Option to continue without network
   - Post-migration network verification

3. **Disk space problems**
   - Pre-flight disk space checks
   - Warning if space is low
   - Option to continue anyway

### Recovery Options

If automation fails:

```bash
# Check automation logs
tail -f /var/log/oz-migration-automator.log

# Run migration manually
sudo ./oz-deb-migration-improved.sh --live

# Run verification manually
sudo ./oz-post-migration-checklist.sh

# Check state file
cat /tmp/oz-automator-state
```

## Safety Considerations

### Before Running

1. **Backup important data**: Always backup critical files (script creates light backups automatically)
2. **Test in test mode**: Use the automator's test mode first
3. **Check system requirements**: Ensure sufficient disk space
4. **Verify network connectivity**: Test domain connectivity
5. **Close applications**: Save work and close programs

### During Automation

1. **Don't interrupt**: Let the automation complete
2. **Monitor logs**: Watch for any error messages
3. **Wait for reboot**: Don't manually reboot during countdown
4. **Check progress**: Monitor the automation log

### After Completion

1. **Verify migration**: Test domain user login
2. **Check services**: Ensure SSSD is running
3. **Test connectivity**: Verify domain connectivity
4. **Review logs**: Check for any warnings or errors

## Troubleshooting

### Automation Won't Start

```bash
# Check script permissions
ls -la oz-migration-automator.sh

# Make executable
chmod +x oz-migration-automator.sh

# Check dependencies
ls -la oz-deb-migration-improved.sh
ls -la oz-post-migration-checklist.sh
```

### Reboot Issues

```bash
# Check rc.local
cat /etc/rc.local

# Manual post-reboot run
sudo ./oz-migration-automator.sh --auto

# Check state file
cat /tmp/oz-automator-state
```

### Log Analysis

```bash
# View automation log
tail -f /var/log/oz-migration-automator.log

# View migration logs
ls -la /var/log/user-migration-*.log

# View SSSD logs
tail -f /var/log/sssd/sssd.log
```

## Integration

### With Existing Scripts

The automator works seamlessly with the existing migration tools:

- **Main migration script**: `oz-deb-migration-improved.sh`
- **Post-migration script**: `oz-post-migration-checklist.sh`
- **Manual verification**: Can run scripts individually

### With Monitoring Systems

The automator provides hooks for monitoring:

- **Log files**: Standard log file locations
- **Exit codes**: Proper exit codes for automation
- **State files**: Progress tracking for external monitoring

## Examples

### Basic Automation

```bash
# Simple automation
sudo ./oz-migration-automator.sh

# Output:
# === Occie's Domain Migration Automator :) ===
# 
# ==> Starting domain migration automation...
# ==> Running pre-flight checks...
# [SUCCESS] Disk space: OK (2048MB available)
# [SUCCESS] Network connectivity: OK
# [SUCCESS] No active user sessions
# 
# Continue with automation? (y/n): y
# 
# ==> Running domain migration script...
# [INFO] Executing: ./oz-deb-migration-improved.sh --live
# ... (migration output) ...
# 
# ==> Scheduling system reboot...
# [INFO] System will reboot in 15 seconds to complete the process
# Rebooting in 15 seconds... 
# Rebooting in 14 seconds... 
# ... (countdown) ...
# 
# ==> Detected post-reboot run - continuing automation...
# ==> Running post-migration verification...
# ... (verification output) ...
# 
# AUTOMATION COMPLETE!
```

### Test Mode

```bash
# Test mode simulation
sudo ./oz-migration-automator.sh --test

# Output:
# === Occie's Domain Migration Automator :) ===
# 
# ==> Starting test migration simulation...
# ==> Running pre-flight checks...
# [SUCCESS] Disk space: OK (2048MB available)
# [SUCCESS] Network connectivity: OK
# [SUCCESS] No active user sessions
# 
# ==> Running test migration simulation...
# [INFO] TEST MODE: Simulating complete migration process
# [INFO] Simulating pre-migration checks...
# [SUCCESS] System compatibility: OK
# [SUCCESS] Package installation completed
# [SUCCESS] Domain discovery: testdomain.local
# [SUCCESS] Successfully joined new domain: testdomain.local
# ... (simulation continues) ...
# 
# TEST MIGRATION SIMULATION COMPLETE
# All migration steps were simulated successfully.
# Script syntax and logic validation: PASSED
# No actual changes were made to the system.
```

### Custom Configuration

```bash
# 30 second reboot delay
sudo ./oz-migration-automator.sh --reboot-delay 30

# Test mode (simulates migration without changes)
sudo ./oz-migration-automator.sh --test

# Fully automatic (no prompts)
sudo ./oz-migration-automator.sh --auto

# Custom delay with auto mode
sudo ./oz-migration-automator.sh --reboot-delay 60 --auto
```

## Support

### Getting Help

```bash
# Show usage information
./oz-migration-automator.sh --help

# Check script version
head -5 oz-migration-automator.sh | grep VERSION
```

### Log Locations

- **Automation log**: `/var/log/oz-migration-automator.log`
- **Migration logs**: `/var/log/user-migration-*.log`
- **SSSD logs**: `/var/log/sssd/sssd.log`
- **System logs**: `journalctl -u sssd`

### Common Commands

```bash
# Check automation status
cat /tmp/oz-automator-state

# View recent logs
tail -50 /var/log/oz-migration-automator.log

# Check if automation is running
ps aux | grep oz-migration-automator

# Clean up state files
rm -f /tmp/oz-automator-state
```

## Notes

- **Root required**: Must be run with sudo/root privileges
- **Debian/Ubuntu**: Designed for Debian-based systems
- **Network dependent**: Requires network connectivity for domain operations
- **Reboot required**: System will reboot during automation
- **Logging**: Logging for troubleshooting
- **State persistence**: Progress saved across reboots

---

**Coded by Oscar** 