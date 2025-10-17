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

  # Install wayvnc and jq (for JSON parsing in startup script)
  sudo pacman -S --noconfirm --needed wayvnc jq

  # Create the wayvnc startup script
  cat > ~/start-wayvnc.sh <<'EOF'
#!/bin/bash

# Log file for debugging
LOGFILE="$HOME/.local/share/wayvnc.log"
mkdir -p "$(dirname "$LOGFILE")"

echo "$(date): Starting wayvnc setup..." >> "$LOGFILE"

# Wait for Hyprland to be ready
echo "$(date): Waiting for Hyprland..." >> "$LOGFILE"
timeout=30
elapsed=0
while ! hyprctl monitors &>/dev/null; do
    sleep 0.5
    elapsed=$((elapsed + 1))
    if [ $elapsed -gt $((timeout * 2)) ]; then
        echo "$(date): ERROR: Timeout waiting for Hyprland" >> "$LOGFILE"
        exit 1
    fi
done

# Get the primary monitor name
PRIMARY_MONITOR=$(hyprctl monitors -j | jq -r '.[0].name')
echo "$(date): Primary monitor detected: $PRIMARY_MONITOR" >> "$LOGFILE"

# Start wayvnc directly on the primary monitor
echo "$(date): Starting wayvnc on $PRIMARY_MONITOR at 0.0.0.0:5900..." >> "$LOGFILE"
wayvnc -o "$PRIMARY_MONITOR" 0.0.0.0 5900 >> "$LOGFILE" 2>&1
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
