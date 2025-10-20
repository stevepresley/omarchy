#!/bin/bash

# Conditionally enable or disable autologin based on advanced mode settings

# Read advanced state file if it exists
if [[ -f "$OMARCHY_ADVANCED_STATE" ]]; then
  enable_autologin=$(jq -r '.enable_autologin' "$OMARCHY_ADVANCED_STATE")
else
  # Default: autologin enabled if no state file (standard behavior)
  enable_autologin="true"
fi

if [[ "$enable_autologin" == "false" ]]; then
  echo "Disabling autologin (password required at boot)..."

  # Disable omarchy-seamless-login service
  sudo systemctl disable omarchy-seamless-login.service 2>/dev/null || true

  # Enable getty for tty1 (standard login prompt)
  sudo systemctl enable getty@tty1.service

  # Create .bash_profile to auto-start Hyprland on tty1 after login
  cat > "$HOME/.bash_profile" << 'EOF'
# Start Hyprland on tty1 after login
if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
  exec uwsm start -- hyprland.desktop
fi

# Source bashrc for interactive shells
[[ -f ~/.bashrc ]] && . ~/.bashrc
EOF

  echo "✓ Autologin disabled - password will be required at boot"
else
  echo "Autologin enabled (seamless boot to desktop)"
fi
