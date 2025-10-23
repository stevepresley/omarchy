#!/bin/bash

# Configure wayvnc with PAM authentication for remote VNC access
# Uses detached mode + auto-attach architecture for seamless login screen access

# Read advanced state file if it exists
if [[ -f "$OMARCHY_ADVANCED_STATE" ]]; then
  enable_wayvnc=$(jq -r '.enable_wayvnc' "$OMARCHY_ADVANCED_STATE")
else
  # Default: wayvnc disabled if no state file
  enable_wayvnc="false"
fi

if [[ "$enable_wayvnc" == "true" ]]; then
  echo "Enabling wayvnc (VNC remote access with PAM authentication)..."

  # Install wayvnc (has PAM support compiled in on Arch)
  sudo pacman -S --noconfirm --needed wayvnc

  # Ensure PAM policy exists (Arch package should ship it, but add fallback just in case)
  if [[ ! -f /etc/pam.d/wayvnc ]]; then
    sudo tee /etc/pam.d/wayvnc <<'EOF' >/dev/null
# Fallback PAM configuration for wayvnc
# Mirrors the standard system login stack so VNC auth matches local users
auth      include   system-local-login
account   include   system-local-login
password  include   system-local-login
session   include   system-local-login
EOF
  fi

  # Create wayvnc configuration directory
  sudo mkdir -p /etc/wayvnc

  # Create wayvnc configuration with PAM authentication
  sudo tee /etc/wayvnc/config <<'EOF' >/dev/null
# wayvnc configuration for Omarchy Advanced
# Provides VNC access with PAM authentication (system users)

address=0.0.0.0
port=5900

# Enable PAM authentication - users authenticate with system credentials
enable_pam=true

# Optional: Enable encryption (requires generating certificates)
# private_key_file=/etc/wayvnc/tls_key.pem
# certificate_file=/etc/wayvnc/tls_cert.pem
EOF

  # Create systemd service for wayvnc in detached mode
  # This runs at boot and persists across login sessions
  sudo tee /etc/systemd/system/wayvnc.service <<EOF >/dev/null
[Unit]
Description=WayVNC - VNC Server for Wayland (Detached Mode)
Documentation=man:wayvnc(1)
After=network.target
Wants=network.target

[Service]
Type=simple
# Run in detached mode - waits for wayvncctl attach commands
ExecStart=/usr/bin/wayvnc --config=/etc/wayvnc/config --detached --render-cursor 0.0.0.0 5900
Restart=always
RestartSec=5

# Run as root to allow attachment to any user's compositor
User=root

[Install]
WantedBy=multi-user.target
EOF

  # Enable wayvnc service to start at boot
  sudo systemctl enable wayvnc.service

  # Add wayvncctl attach to user's Hyprland autostart
  # This attaches wayvnc to the user's session after they log in
  # Must use full socket path and sudo (user gets permission via sudoers.d)
  if ! grep -q "wayvncctl attach" ~/.config/hypr/autostart.conf 2>/dev/null; then
    echo "" >> ~/.config/hypr/autostart.conf
    echo "# Attach wayvnc to this Hyprland session for VNC access" >> ~/.config/hypr/autostart.conf
    echo 'exec-once = sudo wayvncctl --socket /tmp/wayvncctl-0 attach $XDG_RUNTIME_DIR/wayland-1' >> ~/.config/hypr/autostart.conf
  fi

  # Add sudoers rule to allow user to run wayvncctl without password
  # This is needed for the Hyprland autostart attach command AND the monitor service
  # Note: $USER is set during installation by archinstall
  sudo tee /etc/sudoers.d/user-wayvnc <<EOF >/dev/null
$USER ALL=(ALL) NOPASSWD: /usr/bin/wayvncctl
EOF

  sudo chmod 0440 /etc/sudoers.d/user-wayvnc

  # Enable wayvnc disconnect monitor (Issues 24 & 25)
  # This service:
  # 1. Detects when VNC client disconnects
  # 2. Locks the screen immediately (prevents unauthorized reconnection)
  # 3. Detaches wayvnc from session (forces greeter on reconnect for re-authentication)
  mkdir -p ~/.config/systemd/user
  cp "$HOME/.local/share/omarchy/default/systemd/user/omarchy-wayvnc-monitor.service" \
     ~/.config/systemd/user/omarchy-wayvnc-monitor.service

  systemctl --user daemon-reload
  systemctl --user enable omarchy-wayvnc-monitor.service

  # Get IP address for user information
  ip_address=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)

  # Store VNC info for display on the finished screen
  mkdir -p /tmp/omarchy
  echo "$ip_address" > /tmp/omarchy/vnc_ip.txt

  echo "✓ wayvnc installed and configured with PAM authentication"
  echo "  VNC will be accessible at: vnc://$ip_address:5900"
  echo "  Users authenticate with their system username/password"
  echo "✓ VNC Disconnect Monitor enabled (automatic screen lock + detach)"
else
  echo "wayvnc disabled (not requested in advanced mode)"
fi
