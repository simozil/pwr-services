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

# Create the directory
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
            log "info" "Updating and upgrading system..."
            if ! sudo apt update && sudo apt upgrade -y; then
                log "error" "Failed to update system"
                exit 1
            fi

            for pkg in curl wget ufw; do
                if ! exists $pkg; then
                    log "error" "$pkg not found. Installing..."
                    if ! sudo apt install $pkg -y; then
                        log "error" "Failed to install $pkg"
                        exit 1
                    fi
                else
                    log "success" "$pkg is already installed."
                fi
            done

            clear
            log "info" "Run and Install Start..."
            sleep 1

            log "info" "Checking for existing installation..."

            if systemctl is-active --quiet pwr.service; then
                log "info" "Stopping existing PWR service..."
                sudo systemctl stop pwr.service
                sudo systemctl disable pwr.service
            fi

            log "info" "Cleaning up old files..."
            sudo rm -rf validator.jar config.json blocks rocksdb
            if [ -f "/etc/systemd/system/pwr.service" ]; then
                sudo rm /etc/systemd/system/pwr.service
            fi

            sudo systemctl daemon-reload

            log "info" "Cleanup completed. Starting fresh installation..."

            log "info" "Please provide the following information:"
            read -p "Enter your desired password: " PASSWORD
            echo
            read -p "Enter your private key: " PRIVATE_KEY
            echo

            while true; do
                read -p "Enter your server IP (e.g., 185.192.97.28): " SERVER_IP
                if validate_ip "$SERVER_IP"; then
                    break
                else
                    log "error" "Invalid IP format. Please try again."
                fi
            done

            log "info" "Configuring firewall..."

            check_port() {
                local port=$1
                local protocol=$2
                if sudo ufw status | grep -q "$port/$protocol"; then
                    log "success" "Port $port/$protocol already open"
                    return 0
                else
                    log "info" "Opening port $port/$protocol..."
                    sudo ufw allow $port/$protocol
                    return 1
                fi
            }

            check_port 22 tcp
            check_port 8231 tcp
            check_port 8085 tcp
            check_port 7621 udp

            if ! sudo ufw status | grep -q "Status: active"; then
                log "info" "Enabling UFW firewall..."
                sudo ufw --force enable
            else
                log "success" "UFW firewall already enabled"
            fi

            log "info" "Installing Java..."
            if ! sudo apt install -y openjdk-19-jre-headless; then
                log "error" "Failed to install Java"
                exit 1
            fi

            log "info" "Downloading PWR Validator..."
            latest_version=$(curl -s https://api.github.com/repos/pwrlabs/PWR-Validator/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
            if [ -z "$latest_version" ]; then
                log "error" "Failed to get latest version"
                exit 1
            fi

            if ! wget "https://github.com/pwrlabs/PWR-Validator/releases/download/$latest_version/validator.jar"; then
                log "error" "Failed to download validator.jar"
                exit 1
            fi

            if ! wget "https://github.com/pwrlabs/PWR-Validator/raw/refs/heads/main/config.json"; then
                log "error" "Failed to download config.json"
                exit 1
            fi

            echo "$PASSWORD" | sudo tee password > /dev/null
            sudo chmod 600 password

            log "info" "Importing private key..."
            java -jar validator.jar --import-key $PRIVATE_KEY password $SERVER_IP --compression-level 0

            sudo tee /etc/systemd/system/pwr.service > /dev/null <<EOF
[Unit]
Description=PWR node
After=network-online.target
Wants=network-online.target

[Service]
User=$USER
WorkingDirectory=$HOME
ExecStart=java -jar /root/pwr-services/validator.jar password $SERVER_IP --compression-level 0
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

            log "info" "Starting PWR service..."
            if ! sudo systemctl daemon-reload; then
                log "error" "Failed to reload systemd"
                exit 1
            fi

            if ! sudo systemctl enable pwr.service; then
                log "error" "Failed to enable PWR service"
                exit 1
            fi

            if ! sudo systemctl start pwr.service; then
                log "error" "Failed to start PWR service"
                exit 1
            fi

            log "success" "PWR node setup complete and service started."
            log "info" "Current service status:"
            sudo systemctl status pwr

            log "info" "Showing live logs (press Ctrl+C to exit):"
            sudo journalctl -u pwr -f
            exit 0
            ;;
        2)
            log "info" "Starting upgrade process..."
            # Same upgrade steps as before
            ;;
        3)
            log "info" "=== System Status Check ==="
            # Same system check steps as before
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
