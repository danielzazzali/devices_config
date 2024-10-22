# Complete Guide to Connect to an Access Point and Route eth0 and wlan0 on Raspberry Pi

## Step 0: Disable Unnecessary Services
To improve boot time, stop and disable unnecessary services:
```bash
sudo systemctl stop NetworkManager-wait-online.service
sudo systemctl disable NetworkManager-wait-online.service
sudo systemctl stop systemd-networkd
sudo systemctl disable systemd-networkd
```

## Step 1: Configure eth0 (Wired Interface)
Create a script to configure the `eth0` interface:
```bash
nano conf_eth0.sh
```
Add the following content to the script:
```bash
#!/bin/bash
sudo ip addr add 172.16.23.29/24 dev eth0
sudo ip route add default via 172.16.23.1 dev eth0
```
Make the script executable and run it:
```bash
chmod +x conf_eth0.sh
./conf_eth0.sh
```

## Step 2: Update and Upgrade the System
Update your Raspberry Pi:
```bash
sudo apt update && sudo apt upgrade -y
```
Restart your Raspberry Pi:
```bash
sudo reboot
```

## Step 3: Install Required Packages
Install necessary packages for networking and set up iptables-persistent to auto-save:
```bash
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
sudo apt-get install -y dnsmasq iptables-persistent dhcpcd5
```

## Step 4: Configure `dhcpcd.conf` for Both Interfaces
Edit the `dhcpcd` configuration file:
```bash
sudo nano /etc/dhcpcd.conf
```
Replace the content with:
```plaintext
duid

persistent

option domain_name_servers, domain_name, domain_search
option classless_static_routes
option interface_mtu
option host_name
option rapid_commit

require dhcp_server_identifier
slaac private

interface eth0
static ip_address=172.16.23.29/24
static routers=172.16.23.1
static domain_name_servers=1.1.1.1

interface wlan0
nohook wpa_supplicant
```
Save and close the file (CTRL + X, then Y, and Enter).

## Step 5: Configure wlan0 to Connect to an Existing AP Using wpa_supplicant
Configure `wlan0` to connect to an external Wi-Fi network (AP):
```bash
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf
```
Add your Wi-Fi details:
```plaintext
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="MH_SSID"
    psk="password"
}
```
Save and close the file.

## Step 6: Initialize and Connect wlan0 with wpa_cli
1. **Verify available network interfaces:**
   ```bash
   iw dev
   ```
   Ensure `wlan0` (or another Wi-Fi interface) is available.

2. **Start `wpa_supplicant`:**
   ```bash
   sudo wpa_supplicant -B -Dnl80211 -c/etc/wpa_supplicant/wpa_supplicant.conf -iwlan0
   ```

3. **Scan for nearby Wi-Fi networks:**
   ```bash
   sudo wpa_cli -i wlan0 scan
   sleep 3  # Wait 3 seconds for the scan to complete
   sudo wpa_cli -i wlan0 scan_results
   ```

4. **List currently configured networks:**
   ```bash
   sudo wpa_cli -i wlan0 list_networks
   ```

5. **Add a new network:**
   ```bash
   NET_ID=$(sudo wpa_cli -i wlan0 add_network)
   ```

6. **Set SSID and password:**
   ```bash
   sudo wpa_cli -i wlan0 set_network $NET_ID ssid '"Your_SSID"'
   sudo wpa_cli -i wlan0 set_network $NET_ID psk '"Your_WiFi_Password"'
   ```

7. **For an open network (no password):**
   ```bash
   sudo wpa_cli -i wlan0 set_network $NET_ID key_mgmt NONE
   ```

8. **Connect to the network:**
   ```bash
   sudo wpa_cli -i wlan0 enable_network $NET_ID
   sudo wpa_cli -i wlan0 select_network $NET_ID
   ```

9. **Check Wi-Fi connection status:**
   ```bash
   iwconfig wlan0
   ```

## Step 7: Configure Routing Between eth0 and wlan0
Edit iptables to allow traffic between the two interfaces:
```bash
# Allow forwarding from eth0 to wlan0
sudo iptables -A FORWARD -i eth0 -o wlan0 -j ACCEPT

# Allow forwarding from wlan0 to eth0
sudo iptables -A FORWARD -i wlan0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

Enable NAT (Network Address Translation) to share internet from `wlan0` to `eth0`:
```bash
sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
```

## Step 8: Save iptables Rules
Make sure iptables rules persist after a reboot:
```bash
sudo netfilter-persistent save
```

## Step 9: Enable IP Forwarding
Enable IP forwarding to route packets between interfaces:
```bash
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## Step 10: Restart Networking Services
Restart the necessary services to apply the changes:
```bash
sudo systemctl restart dhcpcd
sudo systemctl restart wpa_supplicant
```

## Step 11: Reboot Raspberry Pi
Finally, reboot your Raspberry Pi for all changes to take effect:
```bash
sudo reboot
```

Now, your Raspberry Pi should connect to the external Wi-Fi network via `wlan0`, and route traffic between `eth0` and `wlan0`.
