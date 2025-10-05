#!/bin/bash
set -euo pipefail

# Function to run commands with sudo only if not root
run_as_root() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

CONFIG_FILE=/etc/hdd_temp_monitor.conf
SERVICE_FILE=/etc/systemd/system/hotdisk.service
TIMER_FILE=/etc/systemd/system/hotdisk.timer
echo "=== HotDisk Installation ==="
DEPENDENCIES=(bash smartctl curl lsblk awk date tee systemctl)
MISSING=()

# Check dependencies - skip sudo if running as root
for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then MISSING+=("$cmd"); fi
done

# Only check for sudo if not running as root
if [[ $EUID -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
    MISSING+=("sudo")
fi

if [ ${#MISSING[@]} -ne 0 ]; then
    echo "❌ Missing dependencies:"
    for cmd in "${MISSING[@]}"; do echo "   - $cmd"; done
    echo "Install missing packages: sudo apt update && sudo apt install smartmontools curl"
    exit 1
fi
echo "✅ All dependencies are installed."

# Check if running interactively
if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
    echo "⚠️  Non-interactive mode detected. Using default values."
    echo "To customize settings, run: /usr/local/bin/install_hotdisk.sh"
    MAX_TEMP=60
    HOT_DURATION=5
    COOL_RESET_DURATION=5
    LOG_FILE="/var/log/hdd_temp_monitor.log"
    LOG_ROTATE_COUNT=7
    LOG_ROTATE_PERIOD="daily"
    echo ""
    echo "⚠️  IMPORTANT: You must set your Discord webhook URL manually!"
    echo "Edit /etc/hdd_temp_monitor.conf and add:"
    echo "DISCORD_WEBHOOK=https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"
    echo "Then restart the service: sudo systemctl restart hotdisk.timer"
    DISCORD_WEBHOOK="https://discord.com/api/webhooks/CHANGE_THIS"
else
    read -p "Maximum temperature (°C) before shutdown [60]: " MAX_TEMP
MAX_TEMP=${MAX_TEMP:-60}
if ! [[ "$MAX_TEMP" =~ ^[0-9]+$ ]] || [[ $MAX_TEMP -lt 1 || $MAX_TEMP -gt 100 ]]; then
    echo "ERROR: MAX_TEMP must be a number between 1-100" >&2
    exit 1
fi

read -p "Consecutive minutes above MAX_TEMP before shutdown [5]: " HOT_DURATION
HOT_DURATION=${HOT_DURATION:-5}
if ! [[ "$HOT_DURATION" =~ ^[0-9]+$ ]] || [[ $HOT_DURATION -lt 1 ]]; then
    echo "ERROR: HOT_DURATION must be a positive number" >&2
    exit 1
fi

read -p "Minutes below MAX_TEMP to reset all counters [5]: " COOL_RESET_DURATION
COOL_RESET_DURATION=${COOL_RESET_DURATION:-5}
if ! [[ "$COOL_RESET_DURATION" =~ ^[0-9]+$ ]] || [[ $COOL_RESET_DURATION -lt 1 ]]; then
    echo "ERROR: COOL_RESET_DURATION must be a positive number" >&2
    exit 1
fi
read -p "Log file path [/var/log/hdd_temp_monitor.log]: " LOG_FILE
LOG_FILE=${LOG_FILE:-/var/log/hdd_temp_monitor.log}
read -p "Logrotate: number of files to keep [7]: " LOG_ROTATE_COUNT
LOG_ROTATE_COUNT=${LOG_ROTATE_COUNT:-7}
if ! [[ "$LOG_ROTATE_COUNT" =~ ^[0-9]+$ ]] || [[ $LOG_ROTATE_COUNT -lt 1 ]]; then
    echo "ERROR: LOG_ROTATE_COUNT must be a positive number" >&2
    exit 1
fi

read -p "Logrotate: rotation period (daily/weekly) [daily]: " LOG_ROTATE_PERIOD
LOG_ROTATE_PERIOD=${LOG_ROTATE_PERIOD:-daily}
if [[ ! "$LOG_ROTATE_PERIOD" =~ ^(daily|weekly)$ ]]; then
    echo "ERROR: LOG_ROTATE_PERIOD must be 'daily' or 'weekly'" >&2
    exit 1
fi
    echo "Paste your Discord Webhook URL here."
    read -p "Discord Webhook URL: " DISCORD_WEBHOOK
    if [[ -z "$DISCORD_WEBHOOK" ]]; then
        echo "ERROR: Discord Webhook cannot be empty" >&2
        exit 1
    fi

    # Validate Discord webhook URL format
    if [[ ! "$DISCORD_WEBHOOK" =~ ^https://discord(app)?\.com/api/webhooks/ ]]; then
        echo "ERROR: Invalid Discord webhook URL format" >&2
        exit 1
    fi
fi
echo ""
echo "Please confirm:"
echo "MAX_TEMP=$MAX_TEMP"
echo "HOT_DURATION=$HOT_DURATION"
echo "COOL_RESET_DURATION=$COOL_RESET_DURATION"
echo "LOG_FILE=$LOG_FILE"
echo "LOG_ROTATE_COUNT=$LOG_ROTATE_COUNT"
echo "LOG_ROTATE_PERIOD=$LOG_ROTATE_PERIOD"
echo "DISCORD_WEBHOOK=$DISCORD_WEBHOOK"

if [[ -t 0 ]] && [[ -t 1 ]]; then
    read -p "Is this correct? (y/n): " CONFIRM
    [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && { echo "Aborted"; exit 1; }
else
    echo "Proceeding with installation..."
fi
run_as_root tee "$CONFIG_FILE" > /dev/null <<EOF
MAX_TEMP=$MAX_TEMP
HOT_DURATION=$HOT_DURATION
COOL_RESET_DURATION=$COOL_RESET_DURATION
LOG_FILE=$LOG_FILE
LOG_ROTATE_COUNT=$LOG_ROTATE_COUNT
LOG_ROTATE_PERIOD=$LOG_ROTATE_PERIOD
DISCORD_WEBHOOK=$DISCORD_WEBHOOK
EOF
run_as_root chmod +x /usr/local/bin/hotdisk.sh /usr/local/bin/hotdisk_logger.sh
run_as_root /usr/local/bin/hotdisk_logger.sh
run_as_root tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=HotDisk SATA Temperature Check
[Service]
Type=oneshot
ExecStart=/usr/local/bin/hotdisk.sh
EOF
run_as_root tee "$TIMER_FILE" > /dev/null <<EOF
[Unit]
Description=Run HotDisk temperature check every minute
[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
Persistent=true
[Install]
WantedBy=timers.target
EOF
run_as_root systemctl daemon-reload
run_as_root systemctl enable --now hotdisk.timer
run_as_root /usr/local/bin/hotdisk.sh
echo "✅ HotDisk installation complete!"
