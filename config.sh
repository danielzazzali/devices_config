#!/bin/bash

# Colors for logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print logs
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_info "Starting installation script for Raspberry Pi."

# Step 1: Disable NetworkManager-wait-online.service
log_info "Disabling NetworkManager-wait-online.service..."
sudo systemctl disable NetworkManager-wait-online.service
if [ $? -eq 0 ]; then
    log_info "Successfully disabled NetworkManager-wait-online.service."
else
    log_error "Failed to disable NetworkManager-wait-online.service."
    exit 1
fi

# Step 2: Install nginx and git
log_info "Installing nginx and git..."
sudo apt update -y && sudo apt install -y nginx git
if [ $? -eq 0 ]; then
    log_info "Successfully installed nginx and git."
else
    log_error "Failed to install nginx and/or git."
    exit 1
fi

# Step 3: Prompt user to configure AP or STA mode
log_info "Prompting user for AP or STA configuration."
echo -e "${YELLOW}Would you like to configure the Raspberry Pi as an Access Point (AP) or Station (STA)?${NC}"
echo -e "${YELLOW}Type 'AP' for Access Point or 'STA' for Station:${NC}"
read -p "> " mode_choice

# Convert choice to uppercase for consistency
mode_choice=$(echo "$mode_choice" | tr '[:lower:]' '[:upper:]')

if [[ "$mode_choice" == "AP" || "$mode_choice" == "STA" ]]; then
    log_info "You selected $mode_choice mode."
    echo "$mode_choice" > /etc/rpi_mode_config
    log_info "Mode configuration saved to /etc/rpi_mode_config."
else
    log_error "Invalid input. Please run the script again and enter 'AP' or 'STA'."
    exit 1
fi

log_info "Installation script completed successfully."
