# Domain Migration Troubleshooting Guide

This guide helps you resolve common issues when migrating between Active Directory domains using the Oz Domain Migration Script. Each section provides detailed explanations of what causes the problem and how to fix it.

## Common Issues and Solutions

### 1. Missing Dependencies

**Problem**: Script fails during package installation with dependency errors.

**Why it happens**: Required packages for domain authentication are not installed on the system.

**Solution**:
```bash
# Fix any pending package operations first
sudo dpkg --configure -a
sudo apt-get install -f

# Install required packages manually
sudo apt-get install realmd sssd sssd-tools adcli samba-common-bin oddjob oddjob-mkhomedir packagekit krb5-user libnss-sss libpam-sss
```

**What this does**: Resolves package dependency issues and ensures all required components are available for domain operations.

### 2. DNS Resolution Issues

**Problem**: Domain cannot be resolved or discovered.

**Why it happens**: System cannot find the domain controller due to DNS configuration problems.

**Solution**:
```bash
# Test DNS resolution
nslookup yourdomain.com
dig yourdomain.com

# Check DNS configuration
cat /etc/resolv.conf

# Ensure DNS points to domain-connected server
# Update /etc/resolv.conf if needed
```

**What this does**: Verifies that the domain name resolves to an IP address and checks if the system can reach the domain controller.

### 3. Hostname Configuration

**Problem**: System hostname conflicts with domain naming.

**Why it happens**: Hostname doesn't align with domain structure or contains invalid characters.

**Solution**:
```bash
# Check current hostname
hostname

# Set proper FQDN
sudo hostnamectl set-hostname yourpc.yourdomain.local

# Verify the change
hostname
```

**What this does**: Ensures the hostname follows the format `hostname.domain.com` and aligns with Active Directory naming conventions.

### 4. Kerberos Configuration

**Problem**: Kerberos authentication fails or prompts for realm configuration.

**Why it happens**: Kerberos needs to know the default realm for authentication but isn't properly configured.

**Solution**:
- When prompted for "Default Kerberos version 5 realm", simply press **Tab** to select `<Ok>` and press **Enter**
- Accept the default LOCALDOMAIN value - this will be automatically configured during domain join
- Do not change this value unless specifically instructed by your system administrator

**What this does**: Sets up the default Kerberos realm that will be automatically updated during the domain join process.

### 5. Firewall and Port Issues

**Problem**: Cannot connect to domain controller.

**Why it happens**: Required ports are blocked by firewall or network policies.

**Solution**:
```bash
# Check if required ports are open
telnet domain-controller-ip 88    # Kerberos
telnet domain-controller-ip 389   # LDAP
telnet domain-controller-ip 636   # LDAPS
telnet domain-controller-ip 135   # RPC
telnet domain-controller-ip 445   # SMB
telnet domain-controller-ip 464   # Kerberos password change

# Open ports if needed (adjust for your firewall)
sudo ufw allow 88/tcp
sudo ufw allow 389/tcp
sudo ufw allow 636/tcp
sudo ufw allow 135/tcp
sudo ufw allow 445/tcp
sudo ufw allow 464/tcp
```

**What this does**: Tests connectivity to essential domain services and opens required ports for domain communication.

### 6. SSSD Configuration Issues

**Problem**: Users cannot log in after domain join.

**Why it happens**: SSSD is not properly configured for authentication or services are not running.

**Solution**:
```bash
# Check SSSD status
sudo systemctl status sssd

# Restart SSSD service
sudo systemctl restart sssd

# Check SSSD configuration
sudo cat /etc/sssd/sssd.conf

# Update PAM configuration
sudo pam-auth-update
```

**What this does**: Verifies SSSD service is running, shows current configuration, and ensures proper authentication setup.

### 7. PAM Module Issues

**Problem**: Authentication modules not properly configured.

**Why it happens**: PAM configuration doesn't include domain authentication or modules are missing.

**Solution**:
```bash
# Update PAM configuration
sudo pam-auth-update

# Ensure these modules are enabled:
# - Unix authentication
# - SSS authentication
# - Create home directory on login
```

**What this does**: Configures PAM to use SSSD for authentication and ensures proper authentication flow.

### 8. Home Directory Creation

**Problem**: Domain users cannot log in due to missing home directories.

**Why it happens**: Home directory creation is not properly configured or services are not running.

**Solution**:
```bash
# Enable oddjobd service
sudo systemctl enable oddjobd
sudo systemctl start oddjobd

# Create PAM mkhomedir configuration
sudo mkdir -p /usr/share/pam-configs
sudo tee /usr/share/pam-configs/mkhomedir > /dev/null << EOF
Name: activate mkhomedir
Default: yes
Priority: 900
Session-Type: Additional
Session:
        required pam_mkhomedir.so umask=0022 skel=/etc/skel
EOF

# Update PAM configuration
sudo pam-auth-update
```

**What this does**: Ensures the oddjob service is running and configures automatic home directory creation for domain users.

### 9. Network Connectivity

**Problem**: Cannot reach domain controller.

**Why it happens**: Network configuration or connectivity issues prevent communication with domain controllers.

**Solution**:
```bash
# Test basic connectivity
ping domain-controller-ip

# Check network configuration
ip addr show
ip route show

# Test specific ports
telnet domain-controller-ip 389
```

**What this does**: Tests network connectivity and shows network configuration to identify connectivity problems.

### 10. Time Synchronization

**Problem**: Authentication fails due to time differences.

**Why it happens**: System time is not synchronized with domain controller, causing Kerberos authentication failures.

**Solution**:
```bash
# Check current time
date

# Check time synchronization status
timedatectl status

# Enable and start NTP
sudo systemctl enable systemd-timesyncd
sudo systemctl start systemd-timesyncd

# Or configure NTP manually
sudo apt-get install ntp
sudo systemctl enable ntp
sudo systemctl start ntp
```

**What this does**: Shows current system time and enables automatic time synchronization to prevent authentication issues.

## Emergency Recovery

### If Script Fails Mid-Process

1. **Check the log file**: The script creates detailed logs in `/root/migration-backups/`
2. **Use the revert option**: `sudo ./Oz-Deb-Mig.sh --revert`
3. **Manual recovery**: Restore files from backup directory

### If System Becomes Unusable

1. **Use OZBACKUP account**: Log in with the emergency account created by the script
2. **Check system status**: `systemctl status sssd realmd`
3. **Restore from backup**: Copy files from `/root/migration-backups/backup_*/`

## Prevention Tips

1. **Always backup first**: The script creates backups automatically
2. **Test in demo mode**: Use `--demo` flag to see what would happen
3. **Check prerequisites**: Ensure network connectivity and DNS resolution
4. **Verify credentials**: Test admin account before running script
5. **Monitor system logs**: Check `/var/log/auth.log` and `journalctl -u sssd`

## Getting Help

If you continue to experience issues:

1. Check the detailed log file created by the script
2. Review system logs: `journalctl -u sssd -u realmd`
3. Verify domain controller accessibility
4. Contact your system administrator with the error details

Remember: The script includes comprehensive error handling and will provide specific guidance based on the type of failure encountered. The error handling system will automatically open the log file in a text editor and provide detailed analysis of what went wrong and how to fix it.
