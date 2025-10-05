#!/bin/bash
BASE_URL="https://git.djeex.fr/Djeex/hotdisk/raw/branch/main/sh"
SCRIPTS=("hotdisk.sh" "hotdisk_logger.sh" "install_hotdisk.sh")
sudo apt update
sudo apt install -y smartmontools curl
sudo mkdir -p /usr/local/bin
for script in "${SCRIPTS[@]}"; do
    sudo curl -fsSL "$BASE_URL/$script" -o "/usr/local/bin/$script"
    sudo chmod +x "/usr/local/bin/$script"
done
sudo /usr/local/bin/install_hotdisk.sh
