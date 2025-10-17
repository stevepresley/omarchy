#!/bin/bash

# Conditionally install and configure wayvnc based on advanced mode settings

# Read advanced state file if it exists
if [[ -f "$OMARCHY_ADVANCED_STATE" ]]; then
  enable_wayvnc=$(jq -r '.enable_wayvnc' "$OMARCHY_ADVANCED_STATE")
else
  # Default: wayvnc disabled if no state file
  enable_wayvnc="false"
fi

if [[ "$enable_wayvnc" == "true" ]]; then
  echo "Enabling wayvnc (VNC remote access)..."

  # Install wayvnc
  sudo pacman -S --noconfirm --needed wayvnc

  # Create the wayvnc startup script
  cat > ~/start-wayvnc.sh <<'EOF'
#!/bin/bash
# Wait for Virtual-1 to be ready
while ! hyprctl monitors | grep -q "Virtual-1"; do
    sleep 0.5
done

# Create and configure VNC display
hyprctl output create headless VNC-1
sleep 0.5
hyprctl keyword monitor "VNC-1,1920x1080@60,auto,1,mirror,Virtual-1"
wayvnc -o VNC-1 0.0.0.0 5900
EOF

  # Make the script executable
  chmod +x ~/start-wayvnc.sh

  # Add to Hyprland autostart
  if ! grep -q "start-wayvnc.sh" ~/.config/hypr/autostart.conf; then
    echo "exec-once = ~/start-wayvnc.sh" >> ~/.config/hypr/autostart.conf
  fi

  # Get IP address for user information
  ip_address=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)

  # Store VNC info for display on the finished screen
  mkdir -p /tmp/omarchy
  echo "$ip_address" > /tmp/omarchy/vnc_ip.txt

  echo "✓ wayvnc installed and configured"
else
  echo "wayvnc disabled (not requested in advanced mode)"
fi
