# Complete Guide to Configure an Access Point and DHCP Server on Raspberry Pi

## Step 0: Create the Configuration Script

Before starting, create a script for configuring the network interface. Open a terminal and run the following command to create the script file:

```bash
sudo nano /usr/local/bin/conf_eth0.sh
```

Then, add the following content to the script:

```bash
#!/bin/bash
sudo ip addr add 172.16.23.29/24 dev eth0
sudo ip route add default via 172.16.23.1 dev eth0
```

Save and close the file (CTRL + X, then Y, and Enter). Make the script executable with:

```bash
sudo chmod +x /usr/local/bin/conf_eth0.sh
```

## Step 1: Update and Upgrade the System
```bash
sudo apt update && sudo apt upgrade -y
```

## Step 2: Install Required Packages
Run the following commands to install the necessary packages and set iptables-persistent to auto-save:
```bash
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
sudo apt-get install -y hostapd dnsmasq iptables-persistent dhcpcd5 iw
```

## Step 3: Disable Services
Disable unnecessary services to improve boot time:
```bash
sudo systemctl stop NetworkManager-wait-online.service
sudo systemctl disable NetworkManager-wait-online.service
sudo systemctl stop systemd-networkd
sudo systemctl disable systemd-networkd
```

## Step 4: Configure dhcpcd.conf
Edit the dhcpcd configuration file:
```bash
sudo nano /etc/dhcpcd.conf
```
Replace the content with the following configuration:
```plaintext
# A sample configuration for dhcpcd.
# See dhcpcd.conf(5) for details.

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
static ip_address=11.0.0.1/24
static routers=11.0.0.1
static domain_name_servers=1.1.1.1

interface wlan0
static ip_address=10.0.0.1/24
nohook wpa_supplicant
```
Save and close the file (CTRL + X, then Y, and Enter).

## Step 5: Configure dnsmasq for DHCP
Backup the original dnsmasq configuration:
```bash
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
```
Create a new configuration file:
```bash
sudo nano /etc/dnsmasq.conf
```
Add the following lines:
```plaintext
interface=eth0                   
dhcp-range=11.0.0.10,11.0.0.100,24h 

interface=wlan0  
dhcp-range=10.0.0.10,10.0.0.20,24h
```
Save and close the file.

## Step 6: Configure hostapd
Create a configuration file for hostapd:
```bash
sudo nano /etc/hostapd/hostapd.conf
```
Add the following configuration:
```plaintext
interface=wlan0
driver=nl80211
ssid=MH_Example
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=password
rsn_pairwise=CCMP
```
Save and close the file.

Edit the hostapd default configuration:
```bash
sudo nano /etc/default/hostapd
```
Change the line that says `#DAEMON_CONF=""` to:
```plaintext
DAEMON_CONF="/etc/hostapd/hostapd.conf"
```
Save and close the file.

## Step 7: Enable IP Forwarding
Ensure that IP forwarding is enabled:
```bash
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## Step 8: Configure iptables Rules
Allow traffic between wlan0 and eth0:
```bash
# Allow traffic from wlan0 to eth0
sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT

# Allow traffic from eth0 to wlan0
sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

## Step 9: Save iptables Rules
Ensure that iptables rules are applied after reboot:
```bash
sudo netfilter-persistent save
```

## Step 10: Unmask and Restart Services
Unmask dnsmasq and restart the services:
```bash
sudo systemctl unmask dnsmasq
sudo systemctl restart dnsmasq
sudo systemctl restart hostapd
```

## Step 11: Restart the Raspberry Pi
Finally, restart your Raspberry Pi for all changes to take effect:
```bash
sudo reboot
```
