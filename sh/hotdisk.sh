#!/bin/bash
# HotDisk: Monitor SATA disk temperature and notify via Discord
set -euo pipefail

CONF_FILE="/etc/hdd_temp_monitor.conf"
STATE_FILE="/tmp/hdd_temp_state"

# Check if configuration file exists
if [[ ! -f "$CONF_FILE" ]]; then
    echo "ERROR: Configuration file $CONF_FILE not found!" >&2
    exit 1
fi

source "$CONF_FILE"

# Validate required variables
for var in MAX_TEMP HOT_DURATION COOL_RESET_DURATION LOG_FILE DISCORD_WEBHOOK; do
    if [[ -z "${!var:-}" ]]; then
        echo "ERROR: Required variable $var not set in $CONF_FILE" >&2
        exit 1
    fi
done
DISKS=$(lsblk -dno NAME,TYPE | awk '$2=="disk"{print $1}' | grep -v '^nvme')
if [[ -z "$DISKS" ]]; then
    echo "WARNING: No SATA disks found to monitor" >&2
    exit 0
fi
if [ ! -f "$STATE_FILE" ]; then touch "$STATE_FILE"; fi
declare -A HOT_COUNTERS
declare -A COOL_COUNTERS
while read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    if [[ "$line" =~ ^(.+)_HOT=(.+)$ ]]; then
        HOT_COUNTERS[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
    elif [[ "$line" =~ ^(.+)_COOL=(.+)$ ]]; then
        COOL_COUNTERS[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
    fi
done < "$STATE_FILE"
for disk in $DISKS; do
    # Get temperature with error handling
    if ! temp=$(smartctl -A /dev/$disk 2>/dev/null | awk '/Temperature_Celsius/ {print $10; exit}'); then
        echo "WARNING: Failed to read temperature for $disk" >&2
        continue
    fi
    
    # Skip if temperature is empty or not numeric
    if [[ -z "$temp" ]] || ! [[ "$temp" =~ ^[0-9]+$ ]]; then
        continue
    fi
    hot=${HOT_COUNTERS[$disk]:-0}
    cool=${COOL_COUNTERS[$disk]:-0}
    if [ "$temp" -ge "$MAX_TEMP" ]; then
        hot=$((hot+1))
        cool=0
        if ! curl -s -X POST -H "Content-Type: application/json" -d "{\"content\":\"🔥 Warning: $disk is above $MAX_TEMP°C for $hot minute(s)\"}" "$DISCORD_WEBHOOK" >/dev/null 2>&1; then
            echo "WARNING: Failed to send Discord notification for $disk" >&2
        fi
        if [ "$hot" -ge "$HOT_DURATION" ]; then
            if ! curl -s -X POST -H "Content-Type: application/json" -d "{\"content\":\"⚠️ Critical: $disk has been above $MAX_TEMP°C for $HOT_DURATION minutes. Shutting down...\"}" "$DISCORD_WEBHOOK" >/dev/null 2>&1; then
                echo "WARNING: Failed to send critical Discord notification for $disk" >&2
            fi
            sleep 5
            shutdown -h now
        fi
    else
        if [ "$hot" -gt 0 ]; then
            cool=$((cool+1))
            if ! curl -s -X POST -H "Content-Type: application/json" -d "{\"content\":\"❄️ Notice: $disk is under $MAX_TEMP°C for $cool minute(s)\"}" "$DISCORD_WEBHOOK" >/dev/null 2>&1; then
                echo "WARNING: Failed to send cool-down Discord notification for $disk" >&2
            fi
            if [ "$cool" -ge "$COOL_RESET_DURATION" ]; then
                hot=0
                cool=0
            fi
        fi
    fi
    HOT_COUNTERS[$disk]=$hot
    COOL_COUNTERS[$disk]=$cool
    
    # Ensure log directory exists and log the temperature
    LOG_DIR=$(dirname "$LOG_FILE")
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || echo "WARNING: Cannot create log directory $LOG_DIR" >&2
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') $disk $temp°C" >> "$LOG_FILE" 2>/dev/null || echo "WARNING: Cannot write to log file $LOG_FILE" >&2
done

# Atomic state file update - write to temp file then move
TEMP_STATE_FILE="${STATE_FILE}.tmp.$$"
{
    for disk in "${!HOT_COUNTERS[@]}"; do
        echo "${disk}_HOT=${HOT_COUNTERS[$disk]}"
    done
    for disk in "${!COOL_COUNTERS[@]}"; do
        echo "${disk}_COOL=${COOL_COUNTERS[$disk]}"
    done
} > "$TEMP_STATE_FILE"

# Atomic move - this operation is atomic on most filesystems
if mv "$TEMP_STATE_FILE" "$STATE_FILE" 2>/dev/null; then
    :  # Success - do nothing
else
    echo "WARNING: Failed to update state file atomically" >&2
    # Cleanup temp file if move failed
    rm -f "$TEMP_STATE_FILE" 2>/dev/null || true
fi
