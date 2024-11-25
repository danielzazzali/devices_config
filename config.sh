#!/bin/bash

# Colors for logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Variables for user choices (initialized as empty for now)
mode_choice=""
mode_file="/etc/rpi_mode_config"

# Function to print info logs
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Function to print warning logs
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to print error logs
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to disable the NetworkManager-wait-online.service
disable_network_manager_service() {
    read -p "$(echo -e "${YELLOW}Do you want to disable NetworkManager-wait-online.service? (y/n): ${NC}")" disable_service
    disable_service=$(echo "$disable_service" | tr '[:upper:]' '[:lower:]')

    if [[ "$disable_service" == "y" ]]; then
        log_info "Disabling NetworkManager-wait-online.service..."
        sudo systemctl disable NetworkManager-wait-online.service
        if [ $? -eq 0 ]; then
            log_info "Successfully disabled NetworkManager-wait-online.service."
        else
            log_error "Failed to disable NetworkManager-wait-online.service."
            exit 1
        fi
    else
        log_warning "Skipped disabling NetworkManager-wait-online.service."
    fi
}

# Function to install nginx and git
install_nginx_git() {
    read -p "$(echo -e "${YELLOW}Do you want to install nginx and git? (y/n): ${NC}")" install_packages
    install_packages=$(echo "$install_packages" | tr '[:upper:]' '[:lower:]')

    if [[ "$install_packages" == "y" ]]; then
        log_info "Installing nginx and git..."
        sudo apt update -y && sudo apt install -y nginx git
        if [ $? -eq 0 ]; then
            log_info "Successfully installed nginx and git."
        else
            log_error "Failed to install nginx and/or git."
            exit 1
        fi
    else
        log_warning "Skipped installing nginx and git."
    fi
}

# Function to show WLAN country selection instructions
show_wlan_instructions() {
    log_info "Please follow these steps to set your WLAN country in 'raspi-config':"
    echo -e "${YELLOW}-> 5 Localisation Options -> L4 WLAN Country -> <Country> -> OK -> Finish${NC}"
}

# Function to prompt user to continue and open raspi-config
open_raspi_config() {
    read -p "$(echo -e "${YELLOW}Press Enter to continue and open 'raspi-config'...${NC}")"
    sudo raspi-config
}

# Function to prompt user for mode (AP or STA) and save it
configure_mode() {
    while true; do
        echo -e "${YELLOW}Would you like to configure the Raspberry Pi as an Access Point (AP) or Station (STA)?${NC}"
        echo -e "${YELLOW}Type 'AP' for Access Point or 'STA' for Station:${NC}"
        read -p "> " mode_choice

        # Convert choice to uppercase for consistency
        mode_choice=$(echo "$mode_choice" | tr '[:lower:]' '[:upper:]')

        if [[ "$mode_choice" == "AP" || "$mode_choice" == "STA" ]]; then
            log_info "You selected $mode_choice mode."
            echo "$mode_choice" > $mode_file
            log_info "Mode configuration saved to $mode_file."
            
            # Print the content of mode_file to ensure the mode was saved correctly
            log_info "Contents of $mode_file:"
            cat $mode_file
            
            break
        else
            log_warning "Invalid input. Please enter 'AP' or 'STA'."
        fi
    done
}

# Main function to orchestrate the installation process
main() {
    log_info "Starting installation script for Raspberry Pi."

    # Step 1: Disable NetworkManager-wait-online.service
    disable_network_manager_service

    # Step 2: Install nginx and git
    install_nginx_git

    # Step 3: Show WLAN country selection instructions
    show_wlan_instructions

    # Step 4: Open raspi-config for user to finalize settings
    open_raspi_config

    # Step 5: Prompt user for AP or STA configuration
    configure_mode

    log_info "Installation script completed successfully."
}

# Execute the main function
main
