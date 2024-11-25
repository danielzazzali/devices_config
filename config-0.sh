#!/bin/bash

# Colors for logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Variables for user choices (initialized as empty for now)
MODE_CHOICE=""
MODE_FILE="/etc/rpi_mode_config"
NGINX_CONF_DEFAULT="/etc/nginx/sites-available/default"
NGINX_CONF_DEFAULT81="/etc/nginx/sites-available/default81"
NGINX_CONF_ENABLED="/etc/nginx/sites-enabled"

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
        read -p "> " MODE_CHOICE

        # Convert choice to uppercase for consistency
        MODE_CHOICE=$(echo "$MODE_CHOICE" | tr '[:lower:]' '[:upper:]')

        if [[ "$MODE_CHOICE" == "AP" || "$MODE_CHOICE" == "STA" ]]; then
            log_info "You selected $MODE_CHOICE mode."
            echo "$MODE_CHOICE" > $MODE_FILE
            log_info "Mode configuration saved to $MODE_FILE."
            
            # Print the content of mode_file to ensure the mode was saved correctly
            log_info "Contents of $MODE_FILE:"
            cat $MODE_FILE
            
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

    # Crear el archivo "default81" para redirigir al puerto 8000
    cat <<'EOL' > $NGINX_CONF_DEFAULT81
server {
    listen 81;
    listen [::]:81;

    server_name _;

    location / {
        proxy_pass http://localhost:8000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        add_header Cache-Control 'no-store, no-cache';
    }

}
EOL


    cat <<'EOL' > $NGINX_CONF_DEFAULT
# Este archivo está vacío por ahora y se puede configurar en el futuro según sea necesario.
EOL


    if [ $? -eq 0 ]; then
        log_info "Nginx configuration files created successfully:"
        log_info " - $NGINX_CONF_DEFAULT81"
        log_info " - $NGINX_CONF_DEFAULT"
    else
        log_error "Failed to create Nginx configuration files"
        return 1
    fi

    log_info "Creating symbolic links to enable the configurations..."
    sudo ln -sf $NGINX_CONF_DEFAULT81 $NGINX_CONF_ENABLED/default81
    sudo ln -sf $NGINX_CONF_DEFAULT $NGINX_CONF_ENABLED/default

    if [ $? -eq 0 ]; then
        log_info "Symbolic links created successfully:"
        log_info " - $NGINX_CONF_ENABLED/default81"
        log_info " - $NGINX_CONF_ENABLED/default"
    else
        log_error "Failed to create symbolic links"
        return 1
    fi

    log_info "Reloading Nginx to apply the changes..."
    sudo systemctl reload nginx

    if [ $? -eq 0 ]; then
        log_info "Nginx reloaded successfully"
    else
        log_error "Failed to reload Nginx"
        return 1
    fi
}

create_nginx_file_ap() {
    log_info "Creating nginx default file for AP..."

    cat <<'EOL' > $NGINX_CONF_DEFAULT
server {
    listen 80;
    listen [::]:80;

    server_name _;

    location / {
        proxy_pass http://localhost:8000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        add_header Cache-Control 'no-store, no-cache';
    }

}

EOL

    if [ $? -eq 0 ]; then
        log_info "Nginx configuration file created successfully at $NGINX_CONF_DEFAULT"
    else
        log_error "Failed to create Nginx configuration file"
        return 1
    fi

    log_info "Creating symbolic link to enable the AP configuration..."
    sudo ln -sf $NGINX_CONF_DEFAULT $NGINX_CONF_ENABLED/default

    log_info "Reloading Nginx to apply the changes..."
    sudo systemctl reload nginx

    if [ $? -eq 0 ]; then
        log_info "Nginx reloaded successfully"
    else
        log_error "Failed to reload Nginx"
        return 1
    fi
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
    if [[ "$MODE_CHOICE" == "AP" ]]; then
        configure_ap_mode
        create_nginx_file_ap
    elif [[ "$MODE_CHOICE" == "STA" ]]; then
        configure_sta_mode
        create_nginx_files_sta
    else
        log_error "Invalid mode selected. Exiting."
        exit 1
    fi

    log_info "Configuration completed successfully."
}

# Execute the main function
main
