#!/bin/bash
# Deploy Omarchy Advanced changes to running VM for testing
# Usage: ./scripts/deploy-to-vm.sh <vm-ip-address> [ssh-user]
# Example: ./scripts/deploy-to-vm.sh 192.168.50.73 steve

set -e

# Get VM IP and SSH user from arguments
VM_IP="${1:-}"
SSH_USER="${2:-steve}"

if [[ -z "$VM_IP" ]]; then
  echo "Usage: $0 <vm-ip-address> [ssh-user]"
  echo "Example: $0 192.168.50.73 steve"
  exit 1
fi

# Setup SSH with password caching using ssh-agent
# This allows us to run multiple sudo commands without repeated prompts
eval "$(ssh-agent -s)" >/dev/null 2>&1
ssh-add -K ~/.ssh/id_rsa >/dev/null 2>&1 || true

# Verify SSH connectivity
echo "Testing SSH connection to $VM_IP as $SSH_USER..."
if ! ssh -o ConnectTimeout=5 "$SSH_USER@$VM_IP" "echo 'SSH OK'" >/dev/null 2>&1; then
  echo "ERROR: Cannot connect to $VM_IP via SSH"
  exit 1
fi

echo "✓ SSH connection successful"

# Get the Omarchy installation path on VM
OMARCHY_PATH=$(ssh "$SSH_USER@$VM_IP" 'echo ${OMARCHY_PATH:-$HOME/.local/share/omarchy}' 2>/dev/null)
echo "Omarchy path on VM: $OMARCHY_PATH"

# Copy deployment files to VM first
echo ""
echo "Copying deployment files to VM..."
scp install/files/usr-local-bin-omarchy-wayvnc-monitor "$SSH_USER@$VM_IP:/tmp/omarchy-wayvnc-monitor" >/dev/null
scp config/systemd/system/omarchy-wayvnc-monitor.service "$SSH_USER@$VM_IP:/tmp/omarchy-wayvnc-monitor.service" >/dev/null
echo "✓ Files copied to /tmp"

# Create a single SSH session that runs all cleanup and deployment commands
# This way sudo password is only asked once
echo ""
echo "Running cleanup and deployment on VM (sudo password may be requested once)..."
ssh -t "$SSH_USER@$VM_IP" bash << 'DEPLOY_SCRIPT'
set -e

# Cleanup: Kill old processes
echo "Cleaning up old monitor processes..."
sudo pkill -9 -f 'omarchy-wayvnc-disconnect-lock' || true
sudo pkill -9 -f 'omarchy-wayvnc-monitor' || true
systemctl --user stop omarchy-wayvnc-monitor.service 2>/dev/null || true
systemctl --user disable omarchy-wayvnc-monitor.service 2>/dev/null || true
sudo systemctl stop omarchy-wayvnc-monitor.service 2>/dev/null || true
echo "✓ Old processes killed and user service disabled"

# Ensure /tmp files are in place (they should be from scp)
echo ""
echo "Deploying new wayvnc monitor script..."
if [[ -f /tmp/omarchy-wayvnc-monitor ]]; then
  sudo cp /tmp/omarchy-wayvnc-monitor /usr/local/bin/omarchy-wayvnc-monitor
  sudo chmod +x /usr/local/bin/omarchy-wayvnc-monitor
  echo "✓ New system script deployed to /usr/local/bin/"
else
  echo "ERROR: /tmp/omarchy-wayvnc-monitor not found!"
  exit 1
fi

# Deploy systemd service
echo ""
echo "Deploying systemd service..."
if [[ -f /tmp/omarchy-wayvnc-monitor.service ]]; then
  sudo cp /tmp/omarchy-wayvnc-monitor.service /etc/systemd/system/
  sudo chmod 644 /etc/systemd/system/omarchy-wayvnc-monitor.service
  echo "✓ Systemd service deployed"
else
  echo "ERROR: /tmp/omarchy-wayvnc-monitor.service not found!"
  exit 1
fi

# Enable the monitor service
echo ""
echo "Enabling wayvnc disconnect monitor..."
sudo systemctl daemon-reload
sudo systemctl enable --now omarchy-wayvnc-monitor.service
echo "✓ wayvnc disconnect monitor enabled (running as root system service)"
DEPLOY_SCRIPT

# Show testing instructions
echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Scripts deployed:"
echo "  - omarchy-wayvnc-disconnect-lock (monitors wayvnc events)"
echo "  - omarchy-wayvnc-reattach-greeter (re-attaches to greeter)"
echo "  - omarchy-show-splash (login transition splash screen)"
echo ""
echo "Testing Instructions:"
echo ""
echo "Test 1: VNC Disconnect Lock (Issue 24)"
echo "  1. Connect to VM via VNC"
echo "  2. Login with credentials"
echo "  3. Verify monitor is running:"
echo "     ssh $SSH_USER@$VM_IP 'sudo systemctl status omarchy-wayvnc-monitor.service'"
echo "  4. Disconnect VNC"
echo "  5. Wait 2 seconds, reconnect"
echo "  6. EXPECTED: See login prompt (greeter), not unlocked session"
echo ""
echo "Test 2: wayvnc Monitor Events (Issue 24)"
echo "  Check monitor logs:"
echo "  ssh $SSH_USER@$VM_IP 'sudo journalctl -u omarchy-wayvnc-monitor.service -f'"
echo ""
echo "Test 3: Session Exit Re-attach (Issue 26)"
echo "  1. Login via greeter (console or VNC)"
echo "  2. Open menu: SUPER+ESC"
echo "  3. Select 'Relaunch'"
echo "  4. On console: Greeter appears"
echo "  5. On VNC: EXPECTED - should see greeter (not grey screen)"
echo ""
echo "Test 4: Check Splash Script"
echo "  ls -la $OMARCHY_PATH/bin/omarchy-show-splash"
echo ""
echo "=========================================="
