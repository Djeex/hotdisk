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
curl -fsSL https://git.djeex.fr/Djeex/hotdisk/raw/branch/main/sh/hotdisk_curl_install.sh | bash
```

The installer will:

- Prompt for configuration: max temperature, cooldown, Discord webhook, log file, logrotate settings.
- Check and install missing dependencies.
- Generate logrotate configuration.
- Install and enable systemd service + timer.
- Run HotDisk immediately for testing.

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

1. The script reads SMART temperature for all SATA disks every minute.
2. Counts consecutive minutes above/below threshold.
3. Sends Discord notifications if threshold exceeded or cooled.
4. Initiates system shutdown if temperature exceeds limit for configured duration.
5. Logs all temperatures and counter states, rotates logs automatically.


