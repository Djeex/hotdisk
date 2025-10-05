# HotDisk
A lightweight Linux tool that monitors **SATA HDD temperatures**, sends **Discord notifications**, and safely shuts down the system if disks overheat.

> [!NOTE]
>_HotDisk focuses on SATA disks (NVMe ignored). The repo contains installer scripts, systemd integration, and log rotation setup._
> _Github repo is a mirror of https://git.djeex.fr/Djeex/hotdisk. You'll find full package, history and release note there._

## 📌 Table of Contents

- [✨ Features](#-features)
- [📜 Script Installation (Debian/Ubuntu)](#-script-installation-debianubuntu)
- [⚙️ Configuration Variables](#-configuration-variables)
- [🐞 Common issues](#-common-issues)
- [❓ How it works](#-how-it-works)
- [🧑‍💻 Contributors](#-contributors)

## ✨ Features

- Monitors SATA disk temperatures using SMART (`smartctl`).
- Configurable maximum temperature threshold.
- Counts consecutive minutes above or below threshold before notifications or shutdown.
- Sends Discord notifications when disks exceed or drop below the threshold.
- Sends pre-shutdown warning before executing system shutdown.
- Configurable logging with automatic log rotation.
- Runs as a **systemd service + timer** for continuous monitoring.

## 📜 Script Installation (Debian/Ubuntu)

**Requirements**

- `bash`, `smartmontools`, `curl`, `lsblk` (Debian/Ubuntu default)
- `systemd` & `sudo`  

**Quick Install with Curl**

```bash
curl -fsSL https://git.djeex.fr/Djeex/hotdisk/raw/branch/main/sh/hotdisk_curl_install.sh | bash && sudo /usr/local/bin/install_hotdisk.sh
```

This single command will:
1. Download all scripts to `/usr/local/bin/`
2. Run interactive installation with full customization prompts

**Alternative Installation Options:**

- **Download only**: `curl -fsSL https://git.djeex.fr/Djeex/hotdisk/raw/branch/main/sh/hotdisk_curl_install.sh | bash`
- **Install after download**: `sudo /usr/local/bin/install_hotdisk.sh`

The installer will:

- Download and install all scripts to `/usr/local/bin/`
- Check dependencies (smartmontools, curl, systemd)
- Create configuration with defaults or prompt for custom values
- Generate logrotate configuration for automatic log management
- Install and enable systemd service + timer for continuous monitoring
- Run HotDisk immediately for testing

**Post-Installation (Non-Interactive Mode):**
```bash
sudo nano /etc/hdd_temp_monitor.conf  # Set your Discord webhook URL
sudo systemctl restart hotdisk.timer   # Restart service with new config
```

**Check Logs**

```bash
tail -f /var/log/hdd_temp_monitor.log
```

## ⚙️ Configuration Variables

| Variable              | Description                                                     | Default Value                                  |
|-----------------------|-----------------------------------------------------------------|-----------------------------------------------|
| `MAX_TEMP`            | Maximum allowed temperature (°C) before starting shutdown count | `60`                                          |
| `HOT_DURATION`        | Consecutive minutes above `MAX_TEMP` before shutdown           | `5`                                           |
| `COOL_RESET_DURATION` | Consecutive minutes below `MAX_TEMP` to reset all counters     | `5`                                           |
| `LOG_FILE`            | Path to the main log file                                        | `/var/log/hdd_temp_monitor.log`               |
| `LOG_ROTATE_COUNT`    | Number of log files to keep                                      | `7`                                           |
| `LOG_ROTATE_PERIOD`   | Rotation period for logs (`daily` or `weekly`)                  | `daily`                                       |
| `DISCORD_WEBHOOK`     | Discord webhook URL for notifications                             | _Required_                                    |

Configuration is stored in `/etc/hdd_temp_monitor.conf` and is created by the installer.

## 🐞 Common issues

- `smartctl` may fail if SATA disks do not support SMART.
- Incorrect Discord webhook URL: double-check for typos.
- Installer requires `sudo` privileges for shutdown, log creation, and systemd services.

## ❓ How it works

**Installation Process:**
1. Downloads scripts to `/usr/local/bin/` (hotdisk.sh, hotdisk_logger.sh, install_hotdisk.sh)
2. Detects if running interactively and prompts for configuration or uses defaults
3. Creates `/etc/hdd_temp_monitor.conf` with monitoring settings
4. Sets up systemd service (`hotdisk.service`) and timer (`hotdisk.timer`)
5. Configures automatic log rotation via logrotate
6. Enables and starts the monitoring service

**Monitoring Process:**
1. Runs every minute via systemd timer
2. Discovers all SATA disks (excludes NVMe) using `lsblk` and `smartctl`
3. Reads temperature for each disk via SMART attributes
4. Tracks consecutive minutes above/below threshold in persistent state file
5. Sends Discord notifications for temperature warnings and cool-downs
6. Initiates safe system shutdown if critical temperature duration exceeded
7. Logs all temperature readings with timestamps for analysis


