#!/bin/bash

# Configure greetd display manager to replace autologin
# greetd provides login screen with optional VNC remote access via wayvnc

# Install greetd display manager with regreet greeter and sway compositor
sudo pacman -S --noconfirm --needed greetd greetd-regreet sway

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
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
display_name="${WAYLAND_DISPLAY:-wayland-1}"
socket="${runtime_dir}/${display_name}"

if [[ -S "$socket" ]]; then
  sudo wayvncctl --socket /tmp/wayvncctl-0 attach "$socket"
fi
EOF

sudo chmod +x /usr/local/bin/greetd-wayvnc-attach

# Create Sway configuration for greeter
# This runs regreet (graphical greeter) and wayvnc attach script
sudo tee /etc/greetd/sway-config <<'EOF' >/dev/null
# Sway config for greetd greeter
# Attaches wayvnc to this compositor (for VNC login screen access)
exec /usr/local/bin/greetd-wayvnc-attach

# Launch regreet graphical login prompt
exec regreet
EOF

# Add sudoers rule to allow greeter user to run wayvncctl without password
# This is needed for the greetd-wayvnc-attach script
sudo tee /etc/sudoers.d/greeter-wayvnc <<'EOF' >/dev/null
greeter ALL=(ALL) NOPASSWD: /usr/bin/wayvncctl
EOF

sudo chmod 0440 /etc/sudoers.d/greeter-wayvnc

# Enable greetd service
sudo systemctl enable greetd.service

echo "✓ greetd display manager configured with regreet greeter"
echo "  VNC clients will see login screen via wayvnc"
