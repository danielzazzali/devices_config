## Notes for Developing the Web Server

To ensure the proper development and configuration of the web server, consider the following points:

1. **AP Mode Routing**:
    - The `configure.sh` script routes both `wlan` and `eth` interfaces in AP mode.
    - In STA mode, routing must be handled once the device connects to the wireless network.

2. **Executing `nmcli` Commands**:
    - The web server can execute `nmcli` commands by adding the following line to `sudo visudo`:
      ```
      capstone ALL=(ALL) NOPASSWD: /usr/bin/nmcli
      ```

3. **Network Reconnection with `nmcli`**:
    - `nmcli` is responsible for reconnecting to the wireless network if the connection is lost, either during boot or if the AP is restarted.

4. **Preventing IP Duplication**:
    - Deny the `wlan0` interface to `dhcpcd` to prevent IP duplication on the `wlan0` interface when configured with `nmcli`.

5. **Nginx and Node.js Configuration**:
    - The `configure.sh` script sets up `nginx` to redirect traffic from port 80 to port 3000.
    - It also installs Node.js version 22.11 for the web server.

These points are crucial for the proper setup and functioning of the web server. Ensure to revisit and verify these configurations when resuming development.