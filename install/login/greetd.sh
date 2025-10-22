#!/bin/bash

# Configure greetd display manager to replace autologin
# greetd provides login screen with optional VNC remote access via wayvnc

# Install greetd display manager with regreet greeter and sway compositor
sudo pacman -S --noconfirm --needed greetd greetd-regreet sway

# Prepare Omarchy branding assets for the greeter
sudo mkdir -p /usr/local/share/omarchy/branding
# Use tokyo-night scenery background (primary choice)
GREETER_BG_SOURCE="$OMARCHY_INSTALL/../themes/tokyo-night/backgrounds/1-scenery-pink-lakeside-sunset-lake-landscape-scenic-panorama-7680x3215-144.png"
if [[ ! -f "$GREETER_BG_SOURCE" ]]; then
  # Fallback to any available background if primary doesn't exist
  GREETER_BG_SOURCE=$(find "$OMARCHY_INSTALL/../themes/tokyo-night/backgrounds/" -type f \( -name "*.png" -o -name "*.jpg" \) | head -1)
fi
if [[ -f "$GREETER_BG_SOURCE" ]]; then
  sudo install -m 0644 "$GREETER_BG_SOURCE" /usr/local/share/omarchy/branding/greeter-background.png
else
  # If no background available, create a solid color fallback
  echo "Warning: No greeter background found, using solid color fallback"
fi

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

# Set background if available, otherwise use solid color fallback
if test -f /usr/local/share/omarchy/branding/greeter-background.png; then
  output * bg /usr/local/share/omarchy/branding/greeter-background.png fill
else
  output * bg "#1a1b26" solid_color
end

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

# Provide Omarchy-specific session entry and hide upstream Hyprland/Sway choices
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/omarchy-advanced.desktop <<'EOF' >/dev/null
[Desktop Entry]
Name=Omarchy Advanced
Comment=Omarchy Advanced Hyprland session
Exec=uwsm start -- hyprland.desktop
Type=Application
DesktopNames=Omarchy-Advanced
EOF

if [[ -f /usr/share/wayland-sessions/hyprland.desktop && ! -f /usr/share/wayland-sessions/hyprland.desktop.orig ]]; then
  sudo cp /usr/share/wayland-sessions/hyprland.desktop /usr/share/wayland-sessions/hyprland.desktop.orig
fi
sudo tee /usr/share/wayland-sessions/hyprland.desktop <<'EOF' >/dev/null
[Desktop Entry]
Name=Hyprland (upstream)
Comment=Hidden upstream Hyprland session
Exec=Hyprland
Type=Application
Hidden=true
NoDisplay=true
EOF

if [[ -f /usr/share/wayland-sessions/sway.desktop && ! -f /usr/share/wayland-sessions/sway.desktop.orig ]]; then
  sudo cp /usr/share/wayland-sessions/sway.desktop /usr/share/wayland-sessions/sway.desktop.orig
fi
sudo tee /usr/share/wayland-sessions/sway.desktop <<'EOF' >/dev/null
[Desktop Entry]
Name=Sway (upstream)
Comment=Hidden upstream Sway session
Exec=sway
Type=Application
Hidden=true
NoDisplay=true
EOF

# Enable greetd service
sudo systemctl enable greetd.service

echo "✓ greetd display manager configured with regreet greeter"
echo "  VNC clients will see login screen via wayvnc"
