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

CONF_FILE="/etc/hdd_temp_monitor.conf"
if [[ ! -f "$CONF_FILE" ]]; then
    echo "ERROR: Configuration file $CONF_FILE not found!" >&2
    exit 1
fi
source "$CONF_FILE"

# Validate required variables
for var in LOG_FILE LOG_ROTATE_PERIOD LOG_ROTATE_COUNT; do
    if [[ -z "${!var:-}" ]]; then
        echo "ERROR: Required variable $var not set in $CONF_FILE" >&2
        exit 1
    fi
done

LOGROTATE_FILE="/etc/logrotate.d/hotdisk"
run_as_root tee "$LOGROTATE_FILE" > /dev/null <<EOF
$LOG_FILE {
    $LOG_ROTATE_PERIOD
    rotate $LOG_ROTATE_COUNT
    compress
    missingok
    notifempty
    copytruncate
}
EOF
echo "Logrotate configuration generated at $LOGROTATE_FILE"
