#!/bin/bash
CONF_FILE="/etc/hdd_temp_monitor.conf"
source "$CONF_FILE"
LOGROTATE_FILE="/etc/logrotate.d/hotdisk"
sudo tee "$LOGROTATE_FILE" > /dev/null <<EOF
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
