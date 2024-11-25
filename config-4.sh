# Function to set up the Nginx IP update script and systemd service
setup_nginx_ip_update() {
    # Variables
    SCRIPT_PATH="/usr/local/bin/update_nginx_ip.sh"
    NGINX_CONF_PATH="/etc/nginx/sites-available/default"
    SERVICE_PATH="/etc/systemd/system/nginx-ip-update.service"
    TIMER_PATH="/etc/systemd/system/nginx-ip-update.timer"
    INTERFACE="eth0"

    # Colors for logs
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    NC='\033[0m' # No Color

    # Function to print info messages
    log_info() {
        echo -e "${GREEN}[INFO]${NC} $1"
    }

    # Function to print error messages
    log_error() {
        echo -e "${RED}[ERROR]${NC} $1"
        exit 1
    }

    # Step 1: Create the Nginx IP update script
    log_info "Creating the Nginx IP update script..."

    cat << 'EOF' > "$SCRIPT_PATH"
#!/bin/bash

# Path to the Nginx configuration file
NGINX_CONF_PATH="/etc/nginx/sites-available/default"

# Network interface to check for connected devices (e.g., eth0)
INTERFACE="eth0"

# Step 1: Ping the device to force ARP table refresh
# Get the MAC address of the device connected to eth0 (ignoring incomplete entries)
TARGET_MAC=$(arp -n -i $INTERFACE | grep -v "incomplete" | awk '{print $3}' | head -n 1)

if [ -z "$TARGET_MAC" ]; then
    echo "No connected device found on $INTERFACE."
    exit 1
fi

# Use the MAC address to ping the device, forcing ARP table update
ping -c 1 -I $INTERFACE $TARGET_MAC > /dev/null

# Step 2: Get the IP address of the device from the ARP cache (after refreshing it with ping)
CONNECTED_IP=$(arp -n -i $INTERFACE | grep -v "incomplete" | grep -v "Address" | awk '{print $1}' | head -n 1)

# Check if a valid IP was found
if [ -z "$CONNECTED_IP" ]; then
    echo "No valid IP found for the device connected to $INTERFACE."
    exit 1
fi

# Step 3: Update the Nginx configuration with the found IP address
cat <<EOL > $NGINX_CONF_PATH
server {
    listen 80;
    listen [::]:80;

    server_name _;

    location / {
        proxy_pass http://$CONNECTED_IP/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        add_header Cache-Control 'no-store, no-cache';
    }
}
EOL

# Check if the file was updated successfully
if [ $? -eq 0 ]; then
    echo "Nginx configuration file updated successfully with IP: $CONNECTED_IP"
else
    echo "Error updating the Nginx configuration file."
    exit 1
fi

# Step 4: Reload Nginx to apply the changes
sudo systemctl reload nginx

# Verify if Nginx was reloaded successfully
if [ $? -eq 0 ]; then
    echo "Nginx reloaded successfully."
else
    echo "Error reloading Nginx."
    exit 1
fi
EOF

    # Make the script executable
    chmod +x "$SCRIPT_PATH"

    # Step 2: Create the systemd service unit file
    log_info "Creating the systemd service unit file..."

    cat << EOF > "$SERVICE_PATH"
[Unit]
Description=Update Nginx configuration with connected device IP

[Service]
ExecStart=$SCRIPT_PATH
Restart=always
RestartSec=30s

[Install]
WantedBy=multi-user.target
EOF

    # Step 3: Create the systemd timer unit file
    log_info "Creating the systemd timer unit file..."

    cat << EOF > "$TIMER_PATH"
[Unit]
Description=Run Nginx IP update script every 30 seconds

[Timer]
OnBootSec=5min
OnUnitActiveSec=30s

[Install]
WantedBy=timers.target
EOF

    # Step 4: Reload systemd to recognize the new service and timer
    log_info "Reloading systemd to recognize the new service and timer..."
    sudo systemctl daemon-reload

    # Step 5: Enable and start the systemd service and timer
    log_info "Enabling and starting the systemd timer..."
    sudo systemctl enable nginx-ip-update.timer
    sudo systemctl start nginx-ip-update.timer

    # Step 6: Verify that the service and timer are running
    log_info "Verifying the status of the service and timer..."

    # Check the status of the timer
    sudo systemctl status nginx-ip-update.timer

    # Check the status of the service
    sudo systemctl status nginx-ip-update.service

    log_info "Setup complete! The system is now configured to update the Nginx IP every 30 seconds."
}

# Run the function to set everything up
setup_nginx_ip_update
