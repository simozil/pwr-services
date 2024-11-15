#!/bin/bash

log() {
  local type="$1"
  local message="$2"
  local color

  case "$type" in
    info) color="\033[0;34m" ;;
    success) color="\033[0;32m" ;;
    error) color="\033[0;31m" ;;
    *) color="\033[0m" ;;
  esac

  echo -e "${color}${message}\033[0m"
}

# Set working directory to /root/pwr-services
mkdir -p /root/pwr-services
cd /root/pwr-services

log "info" "=== PWR Node Management ==="
log "info" "1. Install New Node"
log "info" "2. Upgrade Existing Node"
log "info" "3. Check System Status"
log "info" "0. Exit"
log "info" "=========================="

exists() {
  command -v "$1" >/dev/null 2>&1
}

validate_ip() {
    if [[ $1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

while true; do
    read -p "Choose an option: " choice
    case $choice in
        1)
            # Code for installation (seperti sebelumnya)
            ;;
        2)
            log "info" "Starting upgrade process..."

            log "info" "Stopping PWR service..."
            if sudo systemctl stop pwr.service; then
                log "success" "PWR service stopped successfully."
            else
                log "error" "Failed to stop PWR service."
                exit 1
            fi

            log "info" "Cleaning up old validator files..."
            sudo rm -rf /root/pwr-services/validator.jar /root/pwr-services/config.json
            log "success" "Old files removed."

            log "info" "Downloading latest version of PWR Validator..."
            latest_version=$(curl -s https://api.github.com/repos/pwrlabs/PWR-Validator/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
            if [ -z "$latest_version" ]; then
                log "error" "Failed to get latest version"
                exit 1
            fi

            if wget "https://github.com/pwrlabs/PWR-Validator/releases/download/$latest_version/validator.jar"; then
                log "success" "Latest validator.jar downloaded."
            else
                log "error" "Failed to download validator.jar"
                exit 1
            fi

            if wget "https://github.com/pwrlabs/PWR-Validator/raw/refs/heads/main/config.json"; then
                log "success" "Latest config.json downloaded."
            else
                log "error" "Failed to download config.json"
                exit 1
            fi

            log "info" "Starting PWR service with updated files..."
            if sudo systemctl start pwr.service; then
                log "success" "PWR service started successfully."
            else
                log "error" "Failed to start PWR service."
                exit 1
            fi

            log "info" "Upgrade complete. Showing logs (press Enter to return to menu)..."
            sudo journalctl -u pwr --since "5 minutes ago" -n 20  # Menampilkan log terbaru
            read -p ""
            ;;
        3)
            log "info" "=== System Status Check ==="
            # Status check steps as before
            ;;
        0)
            log "info" "Exiting..."
            exit 0
            ;;
        *)
            log "error" "Invalid option. Please try again."
            sleep 2
            clear
            ;;
    esac
done
