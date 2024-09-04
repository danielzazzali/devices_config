sudo nmcli c mod "Wired connection 1" ipv4.addresses 10.0.0.200/24 ipv4.method manual
sudo nmcli con mod "Wired connection 1" ipv4.gateway 10.0.0.1
