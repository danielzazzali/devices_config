#!/bin/bash

# Colors for logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Variables for user choices (initialized as empty for now)
mode_choice=""
mode_file="/etc/rpi_mode_config"

# Function to print info logs
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Function to print warning logs
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to print error logs
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to configure Raspberry Pi as an Access Point (AP)
configure_ap_mode() {
    log_info "Configuring Raspberry Pi as an Access Point (AP)..."

    # Create a bridge connection between wlan0 and eth0
    log_info "Creating bridge connection (br0) between wlan0 and eth0..."
    sudo nmcli connection add con-name 'BR0' ifname br0 type bridge ipv4.method auto ipv6.method disabled connection.autoconnect yes stp no
    sudo nmcli connection add con-name 'ETH' ifname eth0 type bridge-slave master 'BR0' connection.autoconnect yes

    # Set up the Wi-Fi Access Point with SSID ChilipepperLABS and password
    log_info "Setting up Wi-Fi Access Point with SSID ChilipepperLABS..."

    sudo nmcli connection add con-name 'AP' ifname wlan0 type wifi slave-type bridge master 'BR0' wifi.band bg wifi.mode ap wifi.ssid "ChilipepperLABS" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "12345678" autoconnect yes

    sudo nmcli connection up ETH
    sudo nmcli connection up AP
    sudo nmcli connection up BR0

    log_info "Access Point (AP) configuration completed successfully."
}

# Function to configure Raspberry Pi as a Station (STA)
configure_sta_mode() {
    log_info "Configuring Raspberry Pi as a Station (STA)..."

    # Create WLAN connection to the Access Point ChilipepperLABS
    log_info "Creating WLAN connection to SSID ChilipepperLABS..."
    sudo nmcli connection add type wifi con-name 'WLAN' ifname wlan0 ssid "ChilipepperLABS" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "12345678" autoconnect yes

    # Create Ethernet connection with static IP in the 192.168.1.0/24 network for eth0
    log_info "Creating Ethernet connection with static IP in 192.168.1.0/24 network..."
    sudo nmcli connection add type ethernet con-name 'ETH' ifname eth0 ipv4.addresses "192.168.1.1/24" ipv4.gateway "192.168.1.1" ipv4.method manual autoconnect yes
    
    # Bring up both connections
    sudo nmcli connection up WLAN
    sudo nmcli connection up ETH

    log_info "Station (STA) configuration completed successfully."
}

# Function to prompt user for mode (AP or STA) and save it
configure_mode() {
    while true; do
        echo -e "${YELLOW}Would you like to configure the Raspberry Pi as an Access Point (AP) or Station (STA)?${NC}"
        echo -e "${YELLOW}Type 'AP' for Access Point or 'STA' for Station:${NC}"
        read -p "> " mode_choice

        # Convert choice to uppercase for consistency
        mode_choice=$(echo "$mode_choice" | tr '[:lower:]' '[:upper:]')

        if [[ "$mode_choice" == "AP" || "$mode_choice" == "STA" ]]; then
            log_info "You selected $mode_choice mode."
            echo "$mode_choice" > $mode_file
            log_info "Mode configuration saved to $mode_file."
            
            # Print the content of mode_file to ensure the mode was saved correctly
            log_info "Contents of $mode_file:"
            cat $mode_file
            
            break
        else
            log_warning "Invalid input. Please enter 'AP' or 'STA'."
        fi
    done
}

# Main function to orchestrate the configuration process
main() {
    log_info "Starting configuration script for Raspberry Pi."

    # Step 1: Prompt user for AP or STA mode
    configure_mode

    # Step 2: Based on the user's choice, configure the system for either AP or STA
    if [[ "$mode_choice" == "AP" ]]; then
        configure_ap_mode
    elif [[ "$mode_choice" == "STA" ]]; then
        configure_sta_mode
    else
        log_error "Invalid mode selected. Exiting."
        exit 1
    fi

    log_info "Configuration completed successfully."
}

# Execute the main function
main
