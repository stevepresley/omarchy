#!/bin/bash

# Conditionally install and enable SSH server based on advanced mode settings

# Read advanced state file if it exists
if [[ -f "$OMARCHY_ADVANCED_STATE" ]]; then
  enable_ssh=$(jq -r '.enable_ssh' "$OMARCHY_ADVANCED_STATE")
else
  # Default: SSH disabled if no state file
  enable_ssh="false"
fi

if [[ "$enable_ssh" == "true" ]]; then
  echo "Enabling SSH server..."

  # Install openssh
  sudo pacman -S --noconfirm --needed openssh

  # Enable and start SSH service
  sudo systemctl enable sshd
  sudo systemctl start sshd

  echo "✓ SSH server enabled and started"
else
  echo "SSH server disabled (not requested in advanced mode)"
fi
