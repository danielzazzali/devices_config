#!/bin/bash

# IP range
start_ip=200
end_ip=254
subnet="172.16.23"
gateway="172.16.23.1"
dns1="146.83.129.4"
dns2="8.8.8.8"

# Find the first available IP
for i in $(seq $start_ip $end_ip); do
  ip="$subnet.$i"
  
  # Check if the IP is in use
  ping -c 1 -W 1 $ip > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "First available IP found: $ip"
    
    # Assign static IP using 'ip' command
    sudo ip addr flush dev eth0
    sudo ip addr add $ip/24 dev eth0

    # Set the default gateway
    sudo ip route add default via $gateway dev eth0

    # Set DNS servers
    echo "nameserver $dns1" | sudo tee /etc/resolv.conf > /dev/null
    echo "nameserver $dns2" | sudo tee -a /etc/resolv.conf > /dev/null

    # Show network configuration after the change
    ip addr show dev eth0

    # Exit the script after assigning the IP
    exit 0
  fi
done

echo "No available IPs found in the range $subnet.$start_ip-$subnet.$end_ip"
exit 1
