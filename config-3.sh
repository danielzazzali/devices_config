#!/bin/bash

# Colors for logs
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print info logs
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Function to print error logs
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
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

# Main logic to handle file creation based on mode
configure_nginx_based_on_mode() {
    if [[ "$mode_choice" == "STA" ]]; then
        create_nginx_files_sta
        create_nginx_ip_update_service
    elif [[ "$mode_choice" == "AP" ]]; then
        create_nginx_file_ap
    else
        log_error "Invalid mode selected for nginx configuration."
        exit 1
    fi
}

# Test the script by setting the mode
test_script() {
    echo -e "${YELLOW}Enter mode (AP or STA):${NC}"
    read mode_choice

    # Convert choice to uppercase for consistency
    mode_choice=$(echo "$mode_choice" | tr '[:lower:]' '[:upper:]')

    log_info "Selected mode: $mode_choice"

    # Call the function to configure nginx based on selected mode
    configure_nginx_based_on_mode
}

# Run the test
test_script
