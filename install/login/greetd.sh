#!/bin/bash

# Configure greetd display manager to replace autologin
# greetd provides login screen with optional VNC remote access via wayvnc

# Install greetd display manager with regreet greeter and sway compositor
sudo pacman -S --noconfirm --needed greetd greetd-regreet sway

# Prepare Omarchy branding directory (for future use)
sudo mkdir -p /usr/local/share/omarchy/branding

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
# This runs regreet (graphical login) and wayvnc attach script
sudo tee /etc/greetd/sway-config <<'EOF' >/dev/null
# Sway config for greetd greeter
# Attaches wayvnc to this compositor (for VNC login screen access)

# Use solid color background (tokyo-night dark blue)
output * bg "#1a1b26" solid_color

exec /usr/local/bin/greetd-wayvnc-attach

# Launch regreet graphical login prompt
# Note: regreet will show session picker if multiple sessions exist
# Since we delete all other sessions, only Omarchy Advanced should appear
exec regreet
EOF

# Add sudoers rule to allow greeter user to run wayvncctl without password
# This is needed for the greetd-wayvnc-attach script
sudo tee /etc/sudoers.d/greeter-wayvnc <<'EOF' >/dev/null
greeter ALL=(ALL) NOPASSWD: /usr/bin/wayvncctl
EOF

sudo chmod 0440 /etc/sudoers.d/greeter-wayvnc

# Provide Omarchy-specific session entry and hide upstream Hyprland/Sway choices
# We create the session files with Hidden=true so UWSM can find them but regreet won't display them
sudo mkdir -p /usr/share/wayland-sessions

# Create Omarchy session
sudo tee /usr/share/wayland-sessions/omarchy-advanced.desktop <<'EOF' >/dev/null
[Desktop Entry]
Name=Omarchy Advanced
Comment=Omarchy Advanced Hyprland session
Exec=uwsm start -- hyprland.desktop
Type=Application
Categories=System
EOF

# Create hidden Hyprland session files so UWSM can find them but regreet won't display them
sudo tee /usr/share/wayland-sessions/hyprland.desktop <<'EOF' >/dev/null
[Desktop Entry]
Name=Hyprland
Exec=uwsm start -- hyprland
Type=Application
Hidden=true
EOF

sudo tee /usr/share/wayland-sessions/hyprland-uwsm.desktop <<'EOF' >/dev/null
[Desktop Entry]
Name=Hyprland (uwsm-managed)
Exec=uwsm start -- hyprland
Type=Application
Hidden=true
EOF

# Create hidden Sway session file
sudo tee /usr/share/wayland-sessions/sway.desktop <<'EOF' >/dev/null
[Desktop Entry]
Name=Sway
Exec=sway
Type=Application
Hidden=true
EOF

# Create systemd override that ensures Hidden=true on every boot
# This handles cases where packages reinstall session files without Hidden=true
sudo mkdir -p /etc/systemd/system/greetd.service.d
sudo tee /etc/systemd/system/greetd.service.d/hide-unwanted-sessions.conf <<'EOF' >/dev/null
[Service]
ExecStartPre=/bin/bash -c 'for f in /usr/share/wayland-sessions/hyprland.desktop /usr/share/wayland-sessions/hyprland-uwsm.desktop /usr/share/wayland-sessions/sway.desktop; do [ -f "$f" ] && grep -q "^Hidden=true" "$f" || (sed -i "/^Type=/a Hidden=true" "$f" 2>/dev/null || echo "[Desktop Entry]\nHidden=true" >> "$f"); done'
EOF

# Create a pacman hook to ensure Hidden=true if packages get updated
sudo mkdir -p /etc/pacman.d/hooks
sudo tee /etc/pacman.d/hooks/omarchy-hide-unwanted-sessions.hook <<'EOF' >/dev/null
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = hyprland
Target = hyprland-uwsm
Target = sway

[Action]
Description = Hiding unwanted Wayland sessions (keeping only Omarchy Advanced visible)
When = PostTransaction
Exec = /bin/bash -c 'for f in /usr/share/wayland-sessions/hyprland.desktop /usr/share/wayland-sessions/hyprland-uwsm.desktop /usr/share/wayland-sessions/sway.desktop; do [ -f "$f" ] && grep -q "^Hidden=true" "$f" || sed -i "/^Type=/a Hidden=true" "$f"; done'
EOF

# Enable greetd service
sudo systemctl enable greetd.service
sudo systemctl daemon-reload

echo "✓ greetd display manager configured with regreet greeter"
echo "  VNC clients will see login screen via wayvnc"
echo "  Only 'Omarchy Advanced' session will appear in greeter"
