#!/bin/bash

LOG_FILE="/var/log/device_setup.log"
exec > >(tee -a $LOG_FILE) 2>&1

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to disable unnecessary services
disable_services() {
    log "Disabling unnecessary services..."
    sudo systemctl stop NetworkManager-wait-online.service
    sudo systemctl disable NetworkManager-wait-online.service
    sudo systemctl stop systemd-networkd
    sudo systemctl disable systemd-networkd
    log "Services disabled."
}

# Function to install necessary packages
install_packages() {
    log "Installing required packages..."
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
    sudo apt-get install -y hostapd dnsmasq iptables-persistent dhcpcd5 iw
    log "Packages installed."
}

# Function to configure dhcpcd.conf for both AP and STA modes
configure_dhcpcd() {
    log "Configuring dhcpcd.conf..."
    sudo bash -c "cat > /etc/dhcpcd.conf" <<EOL
duid
persistent
vendorclassid

option domain_name_servers, domain_name, domain_search
option classless_static_routes
option interface_mtu
option host_name
option rapid_commit

require dhcp_server_identifier
slaac private

interface eth0
static ip_address=$ETH_IP/$ETH_MASK
static routers=$ETH_IP
static domain_name_servers=1.1.1.1

interface wlan0
static ip_address=$WLAN_IP/$WLAN_MASK
nohook wpa_supplicant
EOL
    log "dhcpcd.conf configured with eth0 IP: $ETH_IP and wlan0 IP: $WLAN_IP."
}

# Function to configure dnsmasq for DHCP
configure_dnsmasq() {
    log "Configuring dnsmasq..."
    sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
    sudo bash -c "cat > /etc/dnsmasq.conf" <<EOL
interface=eth0                   
dhcp-range=$ETH_RANGE,24h 

interface=wlan0  
dhcp-range=$WLAN_RANGE,24h
EOL
    log "dnsmasq configured for DHCP on eth0: $ETH_RANGE and wlan0: $WLAN_RANGE."
}

# Function to configure hostapd
configure_hostapd() {
    log "Configuring hostapd..."
    sudo bash -c "cat > /etc/hostapd/hostapd.conf" <<EOL
interface=wlan0
driver=nl80211
ssid=AP_$SSID
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$PASSWORD
rsn_pairwise=CCMP

country_code=$COUNTRY
ieee80211n=1
wmm_enabled=1
EOL

    sudo sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
    sudo sed -i '/\[Service\]/a ExecStartPre=/bin/sleep 5' /lib/systemd/system/hostapd.service
    log "hostapd configured with SSID: AP_$SSID."
}

# Function to enable IP forwarding and configure iptables
configure_iptables() {
    log "Enabling IP forwarding and configuring iptables..."
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p

    # Add iptables rules
    sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
    sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT

    # Save iptables rules
    sudo netfilter-persistent save
    log "IP forwarding enabled and iptables rules configured."
}

# Function to enable all necessary services
enable_services() {
    log "Enabling necessary services..."
    sudo systemctl unmask hostapd.service
    sudo systemctl enable hostapd.service
    sudo systemctl enable dnsmasq.service
    sudo systemctl enable dhcpcd.service
    sudo systemctl enable iptables-persistent
    log "Services enabled."
}

# Function to ask for reboot
ask_reboot() {
    read -p "Do you want to reboot now? (y/n): " REBOOT
    if [ "$REBOOT" == "y" ]; then
        sudo reboot
    else
        log "Reboot skipped. Please reboot the system later to apply changes."
    fi
}

# Function to configure AP mode
configure_ap_mode() {
    log "Configuring device in AP mode..."
    
    # Disable unnecessary services
    disable_services

    # Install required packages
    install_packages

    # Get network details
    read -p "Enter the IP address for wlan0 (default 10.0.0.1): " WLAN_IP
    WLAN_IP=${WLAN_IP:-10.0.0.1}

    read -p "Enter the subnet mask for wlan0 (default 24): " WLAN_MASK
    WLAN_MASK=${WLAN_MASK:-24}

    read -p "Enter the IP address for eth0 (default 11.0.0.1): " ETH_IP
    ETH_IP=${ETH_IP:-11.0.0.1}
    
    read -p "Enter the subnet mask for eth0 (default 24): " ETH_MASK
    ETH_MASK=${ETH_MASK:-24}

    read -p "Enter the DHCP range for wlan0 (default 10.0.0.10,10.0.0.20): " WLAN_RANGE
    WLAN_RANGE=${WLAN_RANGE:-10.0.0.10,10.0.0.20}
    
    read -p "Enter the DHCP range for eth0 (default 11.0.0.10,11.0.0.100): " ETH_RANGE
    ETH_RANGE=${ETH_RANGE:-11.0.0.10,11.0.0.100}
    
    # Configure dhcpcd.conf
    configure_dhcpcd
    
    # Configure dnsmasq for DHCP
    configure_dnsmasq
    
    # Get AP settings
    read -p "Enter SSID name (without prefix, will be prefixed with AP_): " SSID
    read -p "Enter Wi-Fi password (default 'chilipepperlabs'): " PASSWORD
    PASSWORD=${PASSWORD:-chilipepperlabs}
    
    read -p "Enter country code (default 'US'): " COUNTRY
    COUNTRY=${COUNTRY:-US}
    
    # Configure hostapd
    configure_hostapd

    # Enable IP forwarding and configure iptables
    configure_iptables

    # Enable necessary services
    enable_services

    # Ask for reboot
    ask_reboot
}

# Function to configure STA mode
configure_sta_mode() {
    log "Configuring device in STA mode..."
    
    # Disable unnecessary services
    disable_services
    
    # Install required packages
    install_packages
    
    # Get network details
    read -p "Enter the IP address for eth0 (default 12.0.0.1): " ETH_IP
    ETH_IP=${ETH_IP:-12.0.0.1}

    # Configure dhcpcd.conf
    WLAN_IP="dynamic"  # wlan0 will use DHCP in STA mode
    configure_dhcpcd
    
    # Configure iptables for routing
    log "Configuring iptables for STA mode..."
    sudo iptables -A FORWARD -i eth0 -o wlan0 -j ACCEPT
    sudo iptables -A FORWARD -i wlan0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
    
    # Save iptables rules
    sudo netfilter-persistent save
    log "iptables configured for STA mode."

    # Enable IP forwarding
    configure_iptables
    
    # Enable necessary services
    enable_services

    # Ask for reboot
    ask_reboot
}

# Main menu
main() {
    log "Starting device setup..."
    read -p "Select mode (AP or STA): " MODE
    if [ "$MODE" == "AP" ]; then
        configure_ap_mode
    elif [ "$MODE" == "STA" ]; then
        configure_sta_mode
    else
        log "Invalid mode selected. Exiting."
        exit 1
    fi
}

# Run the main function
main
