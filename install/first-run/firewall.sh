# Allow nothing in, everything out
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow ports for LocalSend
sudo ufw allow 53317/udp
sudo ufw allow 53317/tcp

# Allow SSH in
sudo ufw allow 22/tcp

# Conditionally allow VNC if wayvnc is enabled in advanced mode
#if [[ -f "$OMARCHY_ADVANCED_STATE" ]]; then
#  enable_wayvnc=$(jq -r '.enable_wayvnc' "$OMARCHY_ADVANCED_STATE")
#  if [[ "$enable_wayvnc" == "true" ]]; then
    sudo ufw allow 5900/tcp comment 'wayvnc-remote-access'
#  fi
#fi

# Allow Docker containers to use DNS on host
sudo ufw allow in proto udp from 172.16.0.0/12 to 172.17.0.1 port 53 comment 'allow-docker-dns'

# Turn on the firewall
sudo ufw --force enable

# Enable UFW systemd service to start on boot
sudo systemctl enable ufw

# Turn on Docker protections
sudo ufw-docker install
sudo ufw reload
