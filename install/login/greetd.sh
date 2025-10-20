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

# Create wayvnc attach helper script for greeter
# This script is called by Sway to attach wayvnc to the greeter compositor
sudo tee /usr/local/bin/greetd-wayvnc-attach <<'EOF' >/dev/null
#!/bin/bash
# Wait for Sway compositor to be fully ready
sleep 3

# Attach wayvnc to the greeter's Sway compositor
# Must use full socket path and sudo (greeter user has permission via sudoers.d)
sudo wayvncctl --socket /tmp/wayvncctl-0 attach /run/user/965/wayland-1
EOF

sudo chmod +x /usr/local/bin/greetd-wayvnc-attach

# Create Sway configuration for greeter
# This runs tuigreet (TUI greeter) and wayvnc attach script
sudo tee /etc/greetd/sway-config <<'EOF' >/dev/null
# Sway config for greetd greeter
# Attaches wayvnc to this compositor (for VNC login screen access)
exec /usr/local/bin/greetd-wayvnc-attach

# Launch tuigreet TUI login prompt
exec "tuigreet --remember --remember-session --time --cmd Hyprland"
EOF

# Add sudoers rule to allow greeter user to run wayvncctl without password
# This is needed for the greetd-wayvnc-attach script
sudo tee /etc/sudoers.d/greeter-wayvnc <<'EOF' >/dev/null
greeter ALL=(ALL) NOPASSWD: /usr/bin/wayvncctl
EOF

sudo chmod 0440 /etc/sudoers.d/greeter-wayvnc

# Enable greetd service
sudo systemctl enable greetd.service

echo "✓ greetd display manager configured with tuigreet greeter"
echo "  VNC clients will see login screen via wayvnc"
