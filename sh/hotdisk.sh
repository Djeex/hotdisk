#!/bin/bash
# HotDisk: Monitor SATA disk temperature and notify via Discord
CONF_FILE="/etc/hdd_temp_monitor.conf"
STATE_FILE="/tmp/hdd_temp_state.txt"
source "$CONF_FILE"
DISKS=$(lsblk -dno NAME,TYPE | awk '$2=="disk"{print $1}' | grep -v '^nvme')
if [ ! -f "$STATE_FILE" ]; then touch "$STATE_FILE"; fi
declare -A HOT_COUNTERS
declare -A COOL_COUNTERS
while read -r line; do
    disk=$(echo "$line" | cut -d= -f1)
    val=$(echo "$line" | cut -d= -f2)
    HOT_COUNTERS[$disk]=$val
done < "$STATE_FILE"
for disk in $DISKS; do
    temp=$(smartctl -A /dev/$disk | awk '/Temperature_Celsius/ {print $10; exit}')
    [ -z "$temp" ] && continue
    hot=${HOT_COUNTERS[$disk]:-0}
    cool=${COOL_COUNTERS[$disk]:-0}
    if [ "$temp" -ge "$MAX_TEMP" ]; then
        hot=$((hot+1))
        cool=0
        curl -s -X POST -H "Content-Type: application/json" -d "{\"content\":\"🔥 Warning: $disk is above $MAX_TEMP°C for $hot minute(s)\"}" "$DISCORD_WEBHOOK"
        if [ "$hot" -ge "$HOT_DURATION" ]; then
            curl -s -X POST -H "Content-Type: application/json" -d "{\"content\":\"⚠️ Critical: $disk has been above $MAX_TEMP°C for $HOT_DURATION minutes. Shutting down...\"}" "$DISCORD_WEBHOOK"
            sleep 5
            shutdown -h now
        fi
    else
        if [ "$hot" -gt 0 ]; then
            cool=$((cool+1))
            curl -s -X POST -H "Content-Type: application/json" -d "{\"content\":\"❄️ Notice: $disk is under $MAX_TEMP°C for $cool minute(s)\"}" "$DISCORD_WEBHOOK"
            if [ "$cool" -ge "$COOL_DURATION" ]; then
                hot=0
                cool=0
            fi
        fi
    fi
    HOT_COUNTERS[$disk]=$hot
    COOL_COUNTERS[$disk]=$cool
    echo "$(date '+%Y-%m-%d %H:%M:%S') $disk $temp°C" >> "$LOG_FILE"
done
> "$STATE_FILE"
for disk in "${!HOT_COUNTERS[@]}"; do
    echo "$disk=${HOT_COUNTERS[$disk]}" >> "$STATE_FILE"
done
