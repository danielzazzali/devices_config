#!/bin/bash

# Update package list and install Nginx
sudo apt update
sudo apt install -y nginx

# Create Nginx configuration file
cat <<EOL | sudo tee /etc/nginx/sites-available/example-app
server {
    listen 80;
    server_name _;  # Accepts any IP or domain

    location / {
        proxy_pass http://localhost:3000;  # Redirects to port 3000 where your application is running
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOL

# Enable new configuration and disable default
sudo ln -s /etc/nginx/sites-available/example-app /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

# Test Nginx configuration and restart service
sudo nginx -t
sudo systemctl restart nginx

# Print message
echo "Nginx is configured and restarted. Next.js should be running on port 3000, and Nginx should redirect traffic from port 80 to port 3000."
