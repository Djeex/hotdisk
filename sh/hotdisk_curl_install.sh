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

BASE_URL="https://git.djeex.fr/Djeex/hotdisk/raw/branch/main/sh"
SCRIPTS=("hotdisk.sh" "hotdisk_logger.sh" "install_hotdisk.sh")
run_as_root mkdir -p /usr/local/bin
for script in "${SCRIPTS[@]}"; do
    echo "Downloading $script..."
    if ! run_as_root curl -fsSL "$BASE_URL/$script" -o "/usr/local/bin/$script"; then
        echo "ERROR: Failed to download $script" >&2
        exit 1
    fi
    run_as_root chmod +x "/usr/local/bin/$script"
done

echo ""
echo "📦 Scripts downloaded successfully to /usr/local/bin/"
echo "🔧 Run installation with: sudo /usr/local/bin/install_hotdisk.sh"
