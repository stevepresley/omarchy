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

# CLEANUP: Kill old processes and disable old user service
echo ""
echo "Cleaning up old monitor processes..."
ssh -t "$SSH_USER@$VM_IP" "sudo pkill -9 -f 'omarchy-wayvnc-disconnect-lock' || true"
ssh -t "$SSH_USER@$VM_IP" "sudo pkill -9 -f 'omarchy-wayvnc-monitor' || true"
ssh "$SSH_USER@$VM_IP" "systemctl --user stop omarchy-wayvnc-monitor.service 2>/dev/null || true"
ssh "$SSH_USER@$VM_IP" "systemctl --user disable omarchy-wayvnc-monitor.service 2>/dev/null || true"
ssh -t "$SSH_USER@$VM_IP" "sudo systemctl stop omarchy-wayvnc-monitor.service 2>/dev/null || true"
echo "✓ Old processes killed and user service disabled"

# Deploy new system script
echo ""
echo "Deploying new wayvnc monitor script..."
scp install/files/usr-local-bin-omarchy-wayvnc-monitor "$SSH_USER@$VM_IP:/tmp/omarchy-wayvnc-monitor"
ssh -t "$SSH_USER@$VM_IP" "sudo cp /tmp/omarchy-wayvnc-monitor /usr/local/bin/omarchy-wayvnc-monitor && sudo chmod +x /usr/local/bin/omarchy-wayvnc-monitor"
echo "✓ New system script deployed to /usr/local/bin/"

# Deploy systemd service (system service, runs as root)
echo ""
echo "Deploying systemd service..."
scp config/systemd/system/omarchy-wayvnc-monitor.service "$SSH_USER@$VM_IP:/tmp/omarchy-wayvnc-monitor.service"
ssh -t "$SSH_USER@$VM_IP" "sudo cp /tmp/omarchy-wayvnc-monitor.service /etc/systemd/system/ && sudo chmod 644 /etc/systemd/system/omarchy-wayvnc-monitor.service"
echo "✓ Systemd service deployed"

# Enable the monitor service at system level (runs as root to access wayvnc socket)
echo ""
echo "Enabling wayvnc disconnect monitor..."
ssh -t "$SSH_USER@$VM_IP" "sudo systemctl daemon-reload && sudo systemctl enable --now omarchy-wayvnc-monitor.service"
echo "✓ wayvnc disconnect monitor enabled (running as root system service)"

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
