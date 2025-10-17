stop_install_log

echo_in_style() {
  echo "$1" | tte --canvas-width 0 --anchor-text c --frame-rate 640 print
}

clear
echo
tte -i ~/.local/share/omarchy/logo.txt --canvas-width 0 --anchor-text c --frame-rate 920 laseretch
echo

# Display installation time if available
if [[ -f $OMARCHY_INSTALL_LOG_FILE ]] && grep -q "Total:" "$OMARCHY_INSTALL_LOG_FILE" 2>/dev/null; then
  echo
  TOTAL_TIME=$(tail -n 20 "$OMARCHY_INSTALL_LOG_FILE" | grep "^Total:" | sed 's/^Total:[[:space:]]*//')
  if [ -n "$TOTAL_TIME" ]; then
    echo_in_style "Installed in $TOTAL_TIME"
  fi
else
  echo_in_style "Finished installing"
fi

if sudo test -f /etc/sudoers.d/99-omarchy-installer; then
  sudo rm -f /etc/sudoers.d/99-omarchy-installer &>/dev/null
  echo
  echo_in_style "Remember to remove USB installer!"
fi

# Display VNC access information if wayvnc was enabled
if [[ -f /tmp/omarchy/vnc_ip.txt ]]; then
  vnc_ip=$(cat /tmp/omarchy/vnc_ip.txt)
  echo
  echo
  echo "═══════════════════════════════════════════════════════════"
  echo "           VNC Access Information"
  echo "═══════════════════════════════════════════════════════════"
  echo
  echo "Once the system reboots, it may be accessed via VNC at:"
  echo
  echo "  vnc://${vnc_ip}:5900"
  echo
  echo "If prompted, you may ignore the encryption prompts to connect."
  echo
  echo "═══════════════════════════════════════════════════════════"
  echo
fi

# Exit gracefully if user chooses not to reboot
if gum confirm --padding "0 0 0 $((PADDING_LEFT + 32))" --show-help=false --default --affirmative "Reboot Now" --negative "" ""; then
  # Create marker file for automated script (ISO installation)
  sudo mkdir -p /var/tmp
  sudo touch /var/tmp/omarchy-install-completed

  # Clear screen to hide any shutdown messages
  clear

  # Try to reboot (works for manual installations, automated script handles ISO reboots)
  if command -v systemctl &>/dev/null; then
    systemctl reboot --no-wall 2>/dev/null || true
  else
    reboot 2>/dev/null || true
  fi

  # If reboot didn't work (e.g., in chroot), exit gracefully
  echo "Installation complete. System will reboot shortly..."
  exit 0
fi
