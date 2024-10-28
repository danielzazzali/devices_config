#!/bin/bash

LOG_FILE="/var/log/device_setup.log"
exec > >(tee -a $LOG_FILE) 2>&1

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

# Function to disable unnecessary services
disable_services() {
    log "Disabling unnecessary services..."
    sudo systemctl stop NetworkManager-wait-online.service || error_exit "Failed to stop NetworkManager-wait-online.service"
    sudo systemctl disable NetworkManager-wait-online.service || error_exit "Failed to disable NetworkManager-wait-online.service"
    sudo systemctl stop systemd-networkd || error_exit "Failed to stop systemd-networkd"
    sudo systemctl disable systemd-networkd || error_exit "Failed to disable systemd-networkd"
    log "Services disabled."
}

# Function to install necessary packages
install_packages() {
    log "Installing required packages..."
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
    sudo apt-get update || error_exit "Failed to update package list"
    sudo apt-get install -y hostapd dnsmasq iptables-persistent dhcpcd5 iw frr || error_exit "Failed to install packages"
    log "Packages installed."
}

# Function to calculate DHCP range based on IP and mask
calculate_dhcp_range() {
    local ip=$1
    local mask=$2

    IFS='.' read -r i1 i2 i3 i4 <<< "$ip"
    local host_bits=$(( 32 - mask ))

    # Calculate the range offset
    local offset=$(( 2 ** host_bits - 50 ))

    # Calculate the start of the range by adding 10 to the host part of the IP
    local start_host=$(( i4 + 10 ))
    local end_host=$(( start_host + 40 ))

    # Build DHCP range
    echo "$i1.$i2.$i3.$start_host,$i1.$i2.$i3.$end_host"
}

# Function to configure dhcpcd.conf for both AP and STA modes
configure_dhcpcd() {
    log "Configuring dhcpcd.conf..."
    sudo bash -c "cat > /etc/dhcpcd.conf" <<EOL || error_exit "Failed to configure dhcpcd.conf"
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
    sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig || error_exit "Failed to backup dnsmasq.conf"

    # Check if we're in AP or STA mode
    if [ "$MODE" == "AP" ]; then
        sudo bash -c "cat > /etc/dnsmasq.conf" <<EOL || error_exit "Failed to configure dnsmasq for AP mode"
interface=eth0
dhcp-range=$ETH_RANGE,24h

interface=wlan0
dhcp-range=$WLAN_RANGE,24h
EOL
        log "dnsmasq configured for DHCP on eth0: $ETH_RANGE and wlan0: $WLAN_RANGE."
    else
        sudo bash -c "cat > /etc/dnsmasq.conf" <<EOL || error_exit "Failed to configure dnsmasq for STA mode"
interface=eth0
dhcp-range=$ETH_RANGE,24h
EOL
        log "dnsmasq configured for DHCP on eth0: $ETH_RANGE (STA mode)."
    fi
}

# Function to configure hostapd
configure_hostapd() {
    log "Configuring hostapd..."
    sudo bash -c "cat > /etc/hostapd/hostapd.conf" <<EOL || error_exit "Failed to configure hostapd"
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

    sudo sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd || error_exit "Failed to update /etc/default/hostapd"
    sudo sed -i '/\[Service\]/a ExecStartPre=/bin/sleep 5' /lib/systemd/system/hostapd.service || error_exit "Failed to update hostapd.service"
    log "hostapd configured with SSID: AP_$SSID."
}

# Function to enable IP forwarding and configure iptables
configure_iptables() {
    log "Enabling IP forwarding and configuring iptables..."
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf || error_exit "Failed to enable IP forwarding"
    sudo sysctl -p || error_exit "Failed to reload sysctl configuration"

    # Add iptables rules
    log "Configuring iptables rules..."
    sudo iptables -A FORWARD -i eth0 -o wlan0 -j ACCEPT || error_exit "Failed to add iptables rule FORWARD eth0 to wlan0"
    sudo iptables -A FORWARD -i wlan0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT || error_exit "Failed to add iptables rule FORWARD wlan0 to eth0"
    sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE || error_exit "Failed to add iptables rule POSTROUTING"

    # Save iptables rules
    sudo netfilter-persistent save || log "Failed to save iptables rules"
    log "IP forwarding enabled and iptables rules configured."
}

# Function to configure FRR for dynamic routing
configure_frr() {
    log "Configuring FRR for dynamic routing..."
    sudo bash -c "cat > /etc/frr/daemons" <<EOL || error_exit "Failed to configure FRR daemons"
zebra=yes
bgpd=no
ospfd=yes
ospf6d=no
ripd=no
ripngd=no
isisd=no
pimd=no
ldpd=no
nhrpd=no
eigrpd=no
babeld=no
sharpd=no
pbrd=no
bfdd=no
fabricd=no
vrrpd=no
EOL

    sudo bash -c "cat > /etc/frr/frr.conf" <<EOL || error_exit "Failed to configure FRR"
log file /var/log/frr/frr.log
router ospf
 network $ETH_IP/$ETH_MASK area 0
EOL

    if [ "$MODE" == "AP" ]; then
        sudo bash -c "echo ' network $WLAN_IP/$WLAN_MASK area 0' >> /etc/frr/frr.conf" || error_exit "Failed to configure OSPF for wlan0"
    fi

    sudo systemctl restart frr || log "Failed to restart FRR"
    log "FRR configured and restarted."
}

# Function to enable all necessary services
enable_services() {
    log "Enabling necessary services..."
    sudo systemctl unmask hostapd.service || log "Failed to unmask hostapd.service"
    sudo systemctl enable hostapd.service || log "Failed to enable hostapd.service"
    sudo systemctl enable dnsmasq.service || log "Failed to enable dnsmasq.service"
    sudo systemctl enable dhcpcd.service || log "Failed to enable dhcpcd.service"
    sudo systemctl enable iptables-persistent || log "Failed to enable iptables-persistent"
    sudo systemctl enable frr || log "Failed to enable FRR"
    log "Services enabled."
}

# Function to ask for reboot
ask_reboot() {
    read -p "Do you want to reboot now? (y/n): " REBOOT
    if [ "$REBOOT" == "y" ]; then
        sudo reboot || error_exit "Failed to reboot the system"
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

    # Calculate DHCP ranges
    WLAN_RANGE=$(calculate_dhcp_range $WLAN_IP $WLAN_MASK)
    ETH_RANGE=$(calculate_dhcp_range $ETH_IP $ETH_MASK)

    # Configure dhcpcd.conf
    configure_dhcpcd

    # Configure dnsmasq for DHCP
    configure_dnsmasq

    # Get AP settings
    read -p "Enter SSID name (will be prefixed with AP_): " SSID
    read -p "Enter Wi-Fi password (default 'chilipepperlabs'): " PASSWORD
    PASSWORD=${PASSWORD:-chilipepperlabs}

    read -p "Enter country code (default 'US'): " COUNTRY
    COUNTRY=${COUNTRY:-US}

    # Configure hostapd
    configure_hostapd

    # Enable IP forwarding and configure iptables
    configure_iptables

    # Configure FRR for dynamic routing
    configure_frr

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

    read -p "Enter the subnet mask for eth0 (default 24): " ETH_MASK
    ETH_MASK=${ETH_MASK:-24}

    # Calculate DHCP range for eth0 in STA mode
    ETH_RANGE=$(calculate_dhcp_range $ETH_IP $ETH_MASK)

    # Configure dhcpcd.conf
    WLAN_IP="dynamic"  # wlan0 will use DHCP in STA mode
    configure_dhcpcd

    # Configure dnsmasq for DHCP (if needed)
    configure_dnsmasq

    # Enable IP forwarding
    configure_iptables

    # Configure FRR for dynamic routing
    configure_frr

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
