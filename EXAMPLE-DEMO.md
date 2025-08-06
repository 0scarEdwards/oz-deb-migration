root@OZWS1:/home/occie/Oz-Deb-Mig# ./Oz-Deb-Mig.sh --demo
Log file initialized: /root/migration-backups/migration_log_20250806_215402.log
   ____           ____                        _
  / __ \____     / __ \____  ____ ___  ____ _(_)___
 / / / /_  /    / / / / __ \/ __ `__ \/ __ `/ / __ \
/ /_/ / / /_   / /_/ / /_/ / / / / / / /_/ / / / / /
\____/ /___/  /_____/\____/_/ /_/ /_/\__,_/_/_/ /_/

    __  ____                  __  _                _____           _       __
   /  |/  (_)___ __________ _/ /_(_)___  ____     / ___/__________(_)___  / /_
  / /|_/ / / __ `/ ___/ __ `/ __/ / __ \/ __ \    \__ \/ ___/ ___/ / __ \/ __/
 / /  / / / /_/ / /  / /_/ / /_/ / /_/ / / / /   ___/ / /__/ /  / / /_/ / /_
/_/  /_/_/\__, /_/   \__,_/\__/_/\____/_/ /_/   /____/\___/_/  /_/ .___/\__/
         /____/                                                 /_/

    ____  ________  _______     __  _______  ____  ______
   / __ \/ ____/  |/  / __ \   /  |/  / __ \/ __ \/ ____/
  / / / / __/ / /|_/ / / / /  / /|_/ / / / / / / / __/
 / /_/ / /___/ /  / / /_/ /  / /  / / /_/ / /_/ / /___
/_____/_____/_/  /_/\____/  /_/  /_/\____/_____/_____/

 _  _          _                                   _ _ _   _
| \| |___   __| |_  __ _ _ _  __ _ ___ ___ __ __ _(_) | | | |__  ___
| .` / _ \ / _| ' \/ _` | ' \/ _` / -_|_-< \ V  V / | | | | '_ \/ -_)
|_|\_\___/ \__|_||_\__,_|_||_\__, \___/__/  \_/\_/|_|_|_| |_.__/\___|
                             |___/
               _       _         _   _                     _
 _ __  __ _ __| |___  | |_ ___  | |_| |_  ___   ____  _ __| |_ ___ _ __
| '  \/ _` / _` / -_) |  _/ _ \ |  _| ' \/ -_) (_-< || (_-<  _/ -_) '  \
|_|_|_\__,_\__,_\___|  \__\___/  \__|_||_\___| /__/\_, /__/\__\___|_|_|_|
                                                   |__/

    ____           __        _____
   /  _/___  _____/ /_____ _/ / (_)___  ____ _
   / // __ \/ ___/ __/ __ `/ / / / __ \/ __ `/
 _/ // / / (__  ) /_/ /_/ / / / / / / / /_/ /
/___/_/ /_/____/\__/\__,_/_/_/_/_/ /_/\__, /
                                     /____/
    ____                   _               __
   / __ \___  ____ ___  __(_)_______  ____/ /
  / /_/ / _ \/ __ `/ / / / / ___/ _ \/ __  /
 / _, _/  __/ /_/ / /_/ / / /  /  __/ /_/ /
/_/ |_|\___/\__, /\__,_/_/_/   \___/\__,_/
              /_/
    ____             __
   / __ \____ ______/ /______ _____ ____  _____
  / /_/ / __ `/ ___/ //_/ __ `/ __ `/ _ \/ ___/
 / ____/ /_/ / /__/ ,< / /_/ / /_/ /  __(__  )
/_/    \__,_/\___/_/|_|\__,_/\__, /\___/____/
                            /____/

INFO: Starting package installation
Demo Mode: Installing required packages...
This may take a few moments...
Installing display packages... Done
Installing domain packages... Done
Packages installed successfully
INFO: Demo Mode: Package installation completed successfully

   ______                __  _                ____             __
  / ____/_______  ____ _/ /_(_)___  ____ _   / __ )____ ______/ /____  ______
 / /   / ___/ _ \/ __ `/ __/ / __ \/ __ `/  / __  / __ `/ ___/ //_/ / / / __ \
/ /___/ /  /  __/ /_/ / /_/ / / / / /_/ /  / /_/ / /_/ / /__/ ,< / /_/ / /_/ /
\____/_/   \___/\__,_/\__/_/_/ /_/\__, /  /_____/\__,_/\___/_/|_|\__,_/ .___/
                                 /____/                              /_/
    ____  _                __
   / __ \(_)_______  _____/ /_____  _______  __
  / / / / / ___/ _ \/ ___/ __/ __ \/ ___/ / / /
 / /_/ / / /  /  __/ /__/ /_/ /_/ / /  / /_/ /
/_____/_/_/   \___/\___/\__/\____/_/   \__, /
                                      /____/

INFO: Creating backup directory
Demo Mode: Creating backup directory...
Backup directory created: /root/migration-backups
INFO: Demo Mode: Backup directory created successfully

   ______                __  _
  / ____/_______  ____ _/ /_(_)___  ____ _
 / /   / ___/ _ \/ __ `/ __/ / __ \/ __ `/
/ /___/ /  /  __/ /_/ / /_/ / / / / /_/ /
\____/_/   \___/\__,_/\__/_/_/ /_/\__, /
                                 /____/
   _____            __
  / ___/__  _______/ /____  ____ ___
  \__ \/ / / / ___/ __/ _ \/ __ `__ \
 ___/ / /_/ (__  ) /_/  __/ / / / / /
/____/\__, /____/\__/\___/_/ /_/ /_/
     /____/
    ____             __
   / __ )____ ______/ /____  ______  _____
  / __  / __ `/ ___/ //_/ / / / __ \/ ___/
 / /_/ / /_/ / /__/ ,< / /_/ / /_/ (__  )
/_____/\__,_/\___/_/|_|\__,_/ .___/____/
                           /_/

INFO: Starting system backup creation
Demo Mode: Creating system backups...
Creating backup at: /root/migration-backups/backup_20250806_215408
  Backed up: /etc/samba/smb.conf
  Backed up: /etc/nsswitch.conf
  Backed up: /etc/pam.d/common-session
  Backed up: /etc/pam.d/common-auth
  Backed up: /etc/pam.d/common-account
  Backed up: /etc/pam.d/common-password
  Backed up: Current domain information
Backup completed successfully
INFO: Demo Mode: System backup completed successfully

   ______                __  _
  / ____/_______  ____ _/ /_(_)___  ____ _
 / /   / ___/ _ \/ __ `/ __/ / __ \/ __ `/
/ /___/ /  /  __/ /_/ / /_/ / / / / /_/ /
\____/_/   \___/\__,_/\__/_/_/ /_/\__, /
                                 /____/
   ____  _____   ____  ___   ________ ____  ______
  / __ \/__  /  / __ )/   | / ____/ //_/ / / / __ \
 / / / /  / /  / __  / /| |/ /   / ,< / / / / /_/ /
/ /_/ /  / /__/ /_/ / ___ / /___/ /| / /_/ / ____/
\____/  /____/_____/_/  |_\____/_/ |_\____/_/

    ___                               __
   /   | ______________  __  ______  / /_
  / /| |/ ___/ ___/ __ \/ / / / __ \/ __/
 / ___ / /__/ /__/ /_/ / /_/ / / / / /_
/_/  |_\___/\___/\____/\__,_/_/ /_/\__/


INFO: Starting OZBACKUP account creation
Demo Mode: Creating OZBACKUP emergency account...
This account should only be used in emergency situations.

Enter password for OZBACKUP account:
Confirm password for OZBACKUP account:
OZBACKUP account created successfully
Username: OZBACKUP
Password: [set by user]
INFO: Demo Mode: OZBACKUP account created successfully

IMPORTANT: This account is for emergency access only!
Do not use for regular operations.

    ____                        _
   / __ \____  ____ ___  ____ _(_)___
  / / / / __ \/ __ `__ \/ __ `/ / __ \
 / /_/ / /_/ / / / / / / /_/ / / / / /
/_____/\____/_/ /_/ /_/\__,_/_/_/ /_/

    ____      ____                           __  _
   /  _/___  / __/___  _________ ___  ____ _/ /_(_)___  ____
   / // __ \/ /_/ __ \/ ___/ __ `__ \/ __ `/ __/ / __ \/ __ \
 _/ // / / / __/ /_/ / /  / / / / / / /_/ / /_/ / /_/ / / / /
/___/_/ /_/_/  \____/_/  /_/ /_/ /_/\__,_/\__/_/\____/_/ /_/


INFO: Starting domain information collection
Demo Mode: Please provide the following information:

New domain name: oscartestr
INFO: Demo Mode: New domain: oscartestr
Admin username for new domain: oscartestr
INFO: Demo Mode: Admin user: oscartestr

INFO: Demo Mode: Domain information collection completed
INFO: Detecting current domain status
Demo Mode: Would detect current domain status
    __                     _
   / /   ___  ____ __   __(_)___  ____ _
  / /   / _ \/ __ `/ | / / / __ \/ __ `/
 / /___/  __/ /_/ /| |/ / / / / / /_/ /
/_____/\___/\__,_/ |___/_/_/ /_/\__, /
                               /____/
   ______                           __     ____                        _
  / ____/_  _______________  ____  / /_   / __ \____  ____ ___  ____ _(_)___
 / /   / / / / ___/ ___/ _ \/ __ \/ __/  / / / / __ \/ __ `__ \/ __ `/ / __ \
/ /___/ /_/ / /  / /  /  __/ / / / /_   / /_/ / /_/ / / / / / / /_/ / / / / /
\____/\__,_/_/  /_/   \___/_/ /_/\__/  /_____/\____/_/ /_/ /_/\__,_/_/_/ /_/


INFO: Starting domain leave process for:
Leaving domain:

Demo Mode: Successfully left domain:
INFO: Demo Mode: Successfully left domain:

Domain leave process completed.

Proceeding with domain join...

       __      _       _                _   __
      / /___  (_)___  (_)___  ____ _   / | / /__ _      __
 __  / / __ \/ / __ \/ / __ \/ __ `/  /  |/ / _ \ | /| / /
/ /_/ / /_/ / / / / / / / / / /_/ /  / /|  /  __/ |/ |/ /
\____/\____/_/_/ /_/_/_/ /_/\__, /  /_/ |_/\___/|__/|__/
                           /____/
    ____                        _
   / __ \____  ____ ___  ____ _(_)___
  / / / / __ \/ __ `__ \/ __ `/ / __ \
 / /_/ / /_/ / / / / / / /_/ / / / / /
/_____/\____/_/ /_/ /_/\__,_/_/_/ /_/


INFO: Starting domain join process for: oscartestr
Joining domain: oscartestr
Admin user: oscartestr

Demo Mode: Discovering domain: oscartestr
This will check domain connectivity and configuration...

Domain discovery successful
Domain configuration verified

Demo Mode: Attempting to join domain...
Domain join command completed successfully

Demo Mode: Verifying domain join and connectivity...
Domain join verification successful!
Domain is properly configured and connected

    ____  _                                _
   / __ \(_)_____________ _   _____  _____(_)___  ____ _
  / / / / / ___/ ___/ __ \ | / / _ \/ ___/ / __ \/ __ `/
 / /_/ / (__  ) /__/ /_/ / |/ /  __/ /  / / / / / /_/ /
/_____/_/____/\___/\____/|___/\___/_/  /_/_/ /_/\__, /
                                               /____/
    ____                        _          __  __
   / __ \____  ____ ___  ____ _(_)___     / / / /_______  __________
  / / / / __ \/ __ `__ \/ __ `/ / __ \   / / / / ___/ _ \/ ___/ ___/
 / /_/ / /_/ / / / / / / /_/ / / / / /  / /_/ (__  )  __/ /  (__  )
/_____/\____/_/ /_/ /_/\__,_/_/_/ /_/   \____/____/\___/_/  /____/


INFO: Starting domain user discovery and permission setup
Discovering domain users in home directories...
Setting up permissions for new domain access...

Demo Mode: Found local user: OZBACKUP (skipped - local user)
INFO: Demo Mode: Found local user: OZBACKUP (skipped)
Demo Mode: Found local user: occie (skipped - local user)
INFO: Demo Mode: Found local user: occie (skipped)

Demo Mode: Found 2 local user(s) (skipped - local users are not affected):
  - OZBACKUP
  - occie

Demo Mode: No domain users found from current domain in home directories
INFO: Demo Mode: No domain users found from current domain
    ____                        _          __  __
   / __ \____  ____ ___  ____ _(_)___     / / / /_______  _____
  / / / / __ \/ __ `__ \/ __ `/ / __ \   / / / / ___/ _ \/ ___/
 / /_/ / /_/ / / / / / / /_/ / / / / /  / /_/ (__  )  __/ /
/_____/\____/_/ /_/ /_/\__,_/_/_/ /_/   \____/____/\___/_/

    ____             _____ __        __  ____                  __  _
   / __ \_________  / __(_) /__     /  |/  (_)___ __________ _/ /_(_)___  ____
  / /_/ / ___/ __ \/ /_/ / / _ \   / /|_/ / / __ `/ ___/ __ `/ __/ / __ \/ __ \
 / ____/ /  / /_/ / __/ / /  __/  / /  / / / /_/ / /  / /_/ / /_/ / /_/ / / / /
/_/   /_/   \____/_/ /_/_/\___/  /_/  /_/_/\__, /_/   \__,_/\__/_/\____/_/ /_/
                                          /____/

INFO: Starting domain user profile migration
Domain user profile migration
This will move user files from old domain accounts to new domain accounts
Files will be copied to new domain user home directories and symlinks created
for compatibility with applications that reference the old paths.

Demo Mode: Would prompt: Do you want to migrate domain user profiles? (y/N)
Demo Mode: User would choose: y

Demo Mode: Starting domain user profile migration...

Demo Mode: No domain users found to migrate
INFO: Demo Mode: No domain users found to migrate
Demo Mode: Enabling home directory creation...
Domain join completed successfully!

    ____                        _          _____ __        __
   / __ \____  ____ ___  ____ _(_)___     / ___// /_____ _/ /___  _______
  / / / / __ \/ __ `__ \/ __ `/ / __ \    \__ \/ __/ __ `/ __/ / / / ___/
 / /_/ / /_/ / / / / / / /_/ / / / / /   ___/ / /_/ /_/ / /_/ /_/ (__  )
/_____/\____/_/ /_/ /_/\__,_/_/_/ /_/   /____/\__/\__,_/\__/\__,_/____/


Demo Mode: Current domain configuration:
  oscartestr
    type: kerberos
    realm-name: oscartestr
    domain-name: oscartestr
    configured: kerberos-member
    server-software: active-directory
    client-software: sssd
    required-package: sssd-tools
    required-package: sssd
    required-package: libnss-sss
    login-formats: %U@oscartestr
    login-policy: allow-realm-logins

    __  ____                  __  _
   /  |/  (_)___ __________ _/ /_(_)___  ____
  / /|_/ / / __ `/ ___/ __ `/ __/ / __ \/ __ \
 / /  / / / /_/ / /  / /_/ / /_/ / /_/ / / / /
/_/  /_/_/\__, /_/   \__,_/\__/_/\____/_/ /_/
         /____/
   ______                      __     __
  / ____/___  ____ ___  ____  / /__  / /____
 / /   / __ \/ __ `__ \/ __ \/ / _ \/ __/ _ \
/ /___/ /_/ / / / / / / /_/ / /  __/ /_/  __/
\____/\____/_/ /_/ /_/ .___/_/\___/\__/\___/
                    /_/

Demo Mode: The system has been successfully migrated to: oscartestr
INFO: Demo Mode: Migration completed successfully

Demo Mode: Next steps:
1. Test login with a domain user
2. Verify group memberships
3. Check file permissions

Demo Mode: If you encounter any issues, check the backup files in: /root/migration-backups

Demo Mode: Would prompt for reboot (Y/n)
INFO: Demo Mode: Domain join process completed successfully
INFO: Script execution completed successfully
root@OZWS1:/home/occie/Oz-Deb-Mig#