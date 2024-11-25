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

# Function to disable the NetworkManager-wait-online.service
disable_network_manager_service() {
    read -p "$(echo -e "${YELLOW}Do you want to disable NetworkManager-wait-online.service? (y/n): ${NC}")" disable_service
    disable_service=$(echo "$disable_service" | tr '[:upper:]' '[:lower:]')

    if [[ "$disable_service" == "y" ]]; then
        log_info "Disabling NetworkManager-wait-online.service..."
        sudo systemctl disable NetworkManager-wait-online.service
        if [ $? -eq 0 ]; then
            log_info "Successfully disabled NetworkManager-wait-online.service."
        else
            log_error "Failed to disable NetworkManager-wait-online.service."
            exit 1
        fi
    else
        log_warning "Skipped disabling NetworkManager-wait-online.service."
    fi
}

# Function to install nginx and git
install_nginx_git() {
    read -p "$(echo -e "${YELLOW}Do you want to install nginx and git? (y/n): ${NC}")" install_packages
    install_packages=$(echo "$install_packages" | tr '[:upper:]' '[:lower:]')

    if [[ "$install_packages" == "y" ]]; then
        log_info "Installing nginx and git..."
        sudo apt update -y && sudo apt install -y nginx git
        if [ $? -eq 0 ]; then
            log_info "Successfully installed nginx and git."
        else
            log_error "Failed to install nginx and/or git."
            exit 1
        fi
    else
        log_warning "Skipped installing nginx and git."
    fi
}

# Function to show WLAN country selection instructions
show_wlan_instructions() {
    log_info "Please follow these steps to set your WLAN country in 'raspi-config':"
    echo -e "${YELLOW}-> 5 Localisation Options -> L4 WLAN Country -> <Country> -> OK -> Finish${NC}"
}

# Function to prompt user to continue and open raspi-config
open_raspi_config() {
    read -p "$(echo -e "${YELLOW}Press Enter to continue and open 'raspi-config'...${NC}")"
    sudo raspi-config
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

# Function to create nginx default and default81 files for STA mode
create_nginx_files_sta() {
    log_info "Creating nginx default and default81 files for STA..."

    # default81 redirects to localhost:8000
    echo -e "server {\n    listen 80;\n    server_name localhost;\n    location / {\n        proxy_pass http://localhost:8000/;\n    }\n}" | sudo tee /etc/nginx/sites-available/default81 > /dev/null

    # default will remain empty for later configuration
    echo -e "" | sudo tee /etc/nginx/sites-available/default > /dev/null
}

# Function to create systemd service to update nginx default with eth0 IP
create_nginx_ip_update_service() {
    log_info "Creating systemd service to update default with eth0 IP every 20 seconds..."

    sudo tee /etc/systemd/system/update_nginx_ip.service > /dev/null <<EOF
[Unit]
Description=Update Nginx Proxy Pass to eth0 IP

[Service]
Type=simple
ExecStart=/bin/bash -c 'IP=$(arp -n eth0 | grep -oP "(?<=\d+\.\d+\.\d+\.\d+)\s+\d+" | awk "{print \$1}") && sed -i "s|proxy_pass http://localhost:8000/;|proxy_pass http://\$IP:8000/;|" /etc/nginx/sites-available/default'
Restart=always
RestartSec=20s

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start the service
    sudo systemctl enable update_nginx_ip.service
    sudo systemctl start update_nginx_ip.service
}

# Function to create nginx default file for AP mode
create_nginx_file_ap() {
    log_info "Creating nginx default file for AP..."

    echo -e "server {\n    listen 80;\n    server_name localhost;\n    location / {\n        proxy_pass http://localhost:8000/;\n    }\n}" | sudo tee /etc/nginx/sites-available/default > /dev/null
}


# Main function to orchestrate the configuration process
main() {
    log_info "Starting installation script for Raspberry Pi."

    # Step 1: Disable NetworkManager-wait-online.service
    disable_network_manager_service

    # Step 2: Install nginx and git
    install_nginx_git

    # Step 3: Show WLAN country selection instructions
    show_wlan_instructions

    # Step 4: Open raspi-config for user to finalize settings
    open_raspi_config

    # Step 5: Prompt user for AP or STA configuration
    configure_mode

    # Step 6: Based on the user's choice, configure the system for either AP or STA
    if [[ "$mode_choice" == "AP" ]]; then
        configure_ap_mode
        create_nginx_file_ap
    elif [[ "$mode_choice" == "STA" ]]; then
        configure_sta_mode
        create_nginx_files_sta
        create_nginx_ip_update_service
    else
        log_error "Invalid mode selected. Exiting."
        exit 1
    fi

    log_info "Configuration completed successfully."
}

# Execute the main function
main
