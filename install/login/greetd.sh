#!/bin/bash

# Configure greetd display manager to replace autologin
# greetd provides login screen with optional VNC remote access via wayvnc

# Install greetd and related packages
sudo pacman -S --noconfirm --needed greetd greetd-tuigreet sway

# Create greetd configuration
sudo mkdir -p /etc/greetd
sudo tee /etc/greetd/config.toml <<'EOF' >/dev/null
[terminal]
vt = 1

[default_session]
command = "sway --config /etc/greetd/sway-config"
user = "greeter"
EOF

# Create Sway configuration for greeter
# This runs tuigreet and wayvncctl attach (if wayvnc is enabled)
sudo tee /etc/greetd/sway-config <<'EOF' >/dev/null
# Sway config for greetd greeter
# Runs tuigreet login prompt

exec "tuigreet --remember --remember-session --time --cmd Hyprland"

# If wayvnc is running in detached mode, attach to this compositor
# This allows VNC clients to see the login screen
exec "wayvncctl attach 2>/dev/null || true"
EOF

# Enable greetd service
sudo systemctl enable greetd.service

echo "✓ greetd display manager configured"
