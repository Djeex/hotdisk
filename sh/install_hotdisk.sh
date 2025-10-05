#!/bin/bash
CONFIG_FILE=/etc/hdd_temp_monitor.conf
SERVICE_FILE=/etc/systemd/system/hotdisk.service
TIMER_FILE=/etc/systemd/system/hotdisk.timer
echo "=== HotDisk Installation ==="
DEPENDENCIES=(bash smartctl curl lsblk awk date tee sudo systemctl)
MISSING=()
for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then MISSING+=("$cmd"); fi
done
if [ ${#MISSING[@]} -ne 0 ]; then
    echo "❌ Missing dependencies:"
    for cmd in "${MISSING[@]}"; do echo "   - $cmd"; done
    echo "Install missing packages: sudo apt update && sudo apt install smartmontools curl"
    exit 1
fi
echo "✅ All dependencies are installed."
read -p "Maximum temperature (°C) before shutdown [60]: " MAX_TEMP
MAX_TEMP=${MAX_TEMP:-60}
read -p "Consecutive minutes above MAX_TEMP before shutdown [5]: " HOT_DURATION
HOT_DURATION=${HOT_DURATION:-5}
read -p "Consecutive minutes below MAX_TEMP to reset counter [5]: " COOL_DURATION
COOL_DURATION=${COOL_DURATION:-5}
read -p "Log file path [/var/log/hdd_temp_monitor.log]: " LOG_FILE
LOG_FILE=${LOG_FILE:-/var/log/hdd_temp_monitor.log}
read -p "Logrotate: number of files to keep [7]: " LOG_ROTATE_COUNT
LOG_ROTATE_COUNT=${LOG_ROTATE_COUNT:-7}
read -p "Logrotate: rotation period (daily/weekly) [daily]: " LOG_ROTATE_PERIOD
LOG_ROTATE_PERIOD=${LOG_ROTATE_PERIOD:-daily}
echo "Paste your Discord Webhook URL here."
read -p "Discord Webhook URL: " DISCORD_WEBHOOK
[ -z "$DISCORD_WEBHOOK" ] && { echo "Discord Webhook cannot be empty"; exit 1; }
echo ""
echo "Please confirm:"
echo "MAX_TEMP=$MAX_TEMP"
echo "HOT_DURATION=$HOT_DURATION"
echo "COOL_DURATION=$COOL_DURATION"
echo "LOG_FILE=$LOG_FILE"
echo "LOG_ROTATE_COUNT=$LOG_ROTATE_COUNT"
echo "LOG_ROTATE_PERIOD=$LOG_ROTATE_PERIOD"
echo "DISCORD_WEBHOOK=$DISCORD_WEBHOOK"
read -p "Is this correct? (y/n): " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && { echo "Aborted"; exit 1; }
sudo tee "$CONFIG_FILE" > /dev/null <<EOF
MAX_TEMP=$MAX_TEMP
HOT_DURATION=$HOT_DURATION
COOL_DURATION=$COOL_DURATION
LOG_FILE=$LOG_FILE
LOG_ROTATE_COUNT=$LOG_ROTATE_COUNT
LOG_ROTATE_PERIOD=$LOG_ROTATE_PERIOD
DISCORD_WEBHOOK=$DISCORD_WEBHOOK
EOF
sudo chmod +x /usr/local/bin/sh/hotdisk.sh /usr/local/bin/sh/hotdisk_logger.sh
sudo /usr/local/bin/sh/hotdisk_logger.sh
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=HotDisk SATA Temperature Check
[Service]
Type=oneshot
ExecStart=/usr/local/bin/sh/hotdisk.sh
EOF
sudo tee "$TIMER_FILE" > /dev/null <<EOF
[Unit]
Description=Run HotDisk temperature check every minute
[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
Persistent=true
[Install]
WantedBy=timers.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now hotdisk.timer
sudo /usr/local/bin/sh/hotdisk.sh
echo "✅ HotDisk installation complete!"
