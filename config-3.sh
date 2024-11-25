#!/bin/bash

# Colors for logs
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

NGINX_CONF_DEFAULT="/etc/nginx/sites-available/default"
NGINX_CONF_DEFAULT81="/etc/nginx/sites-available/default81"
NGINX_CONF_ENABLED="/etc/nginx/sites-enabled"

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

    # Crear el archivo "default" vacío para futuras configuraciones
    cat <<'EOL' > $NGINX_CONF_DEFAULT
# Este archivo está vacío por ahora y se puede configurar en el futuro según sea necesario.
EOL

    # Comprobar si los archivos se crearon correctamente
    if [ $? -eq 0 ]; then
        log_info "Nginx configuration files created successfully:"
        log_info " - $NGINX_CONF_DEFAULT81"
        log_info " - $NGINX_CONF_DEFAULT"
    else
        log_error "Failed to create Nginx configuration files"
        return 1
    fi

    # Crear los enlaces simbólicos para habilitar los archivos de configuración
    log_info "Creating symbolic links to enable the configurations..."
    sudo ln -sf $NGINX_CONF_DEFAULT81 $NGINX_CONF_ENABLED/default81
    sudo ln -sf $NGINX_CONF_DEFAULT $NGINX_CONF_ENABLED/default

    # Verificar si los enlaces se crearon correctamente
    if [ $? -eq 0 ]; then
        log_info "Symbolic links created successfully:"
        log_info " - $NGINX_CONF_ENABLED/default81"
        log_info " - $NGINX_CONF_ENABLED/default"
    else
        log_error "Failed to create symbolic links"
        return 1
    fi

    # Recargar Nginx para aplicar los cambios
    log_info "Reloading Nginx to apply the changes..."
    sudo systemctl reload nginx

    # Verificar si Nginx se recargó correctamente
    if [ $? -eq 0 ]; then
        log_info "Nginx reloaded successfully"
    else
        log_error "Failed to reload Nginx"
        return 1
    fi
}

# Función para crear el archivo de configuración para AP
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

    # Comprobar si el archivo se creó correctamente
    if [ $? -eq 0 ]; then
        log_info "Nginx configuration file created successfully at $NGINX_CONF_DEFAULT"
    else
        log_error "Failed to create Nginx configuration file"
        return 1
    fi

    # Crear enlace simbólico para habilitar la configuración de AP
    log_info "Creating symbolic link to enable the AP configuration..."
    sudo ln -sf $NGINX_CONF_DEFAULT $NGINX_CONF_ENABLED/default

    # Recargar Nginx para aplicar los cambios
    log_info "Reloading Nginx to apply the changes..."
    sudo systemctl reload nginx

    # Verificar si Nginx se recargó correctamente
    if [ $? -eq 0 ]; then
        log_info "Nginx reloaded successfully"
    else
        log_error "Failed to reload Nginx"
        return 1
    fi
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
