#!/bin/bash

sudo ifconfig

sudo nmcli c mod "Wired connection 1" ipv4.addresses 172.16.23.102/24 ipv4.method manual
sudo nmcli con mod "Wired connection 1" ipv4.gateway 172.16.23.1
sudo nmcli con mod "Wired connection 1" ipv4.dns "146.83.129.4,8.8.8.8"

sudo nmcli c down "Wired connection 1" && sudo nmcli c up "Wired connection 1"

sudo ifconfig
