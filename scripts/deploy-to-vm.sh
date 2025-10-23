#!/bin/bash
# Deploy Omarchy Advanced changes to running VM for testing
# This script copies files to the VM, then shows you commands to run on the VM
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

# Copy deployment files to VM
echo ""
echo "Copying deployment files to VM..."
scp install/files/usr-local-bin-omarchy-wayvnc-monitor "$SSH_USER@$VM_IP:/tmp/omarchy-wayvnc-monitor" >/dev/null
scp config/systemd/system/omarchy-wayvnc-monitor.service "$SSH_USER@$VM_IP:/tmp/omarchy-wayvnc-monitor.service" >/dev/null
echo "✓ Files copied to /tmp on VM"

# Show instructions for completing deployment on the VM
echo ""
echo "=========================================="
echo "Files Ready for Deployment"
echo "=========================================="
echo ""
echo "The following files are now in /tmp on your VM:"
echo "  /tmp/omarchy-wayvnc-monitor"
echo "  /tmp/omarchy-wayvnc-monitor.service"
echo ""
echo "NEXT STEPS - Run these commands ON YOUR VM terminal:"
echo ""
echo "1. Kill old processes:"
echo "   sudo pkill -9 -f 'omarchy-wayvnc-disconnect-lock'"
echo "   sudo pkill -9 -f 'omarchy-wayvnc-monitor'"
echo ""
echo "2. Stop and disable old user service:"
echo "   systemctl --user stop omarchy-wayvnc-monitor.service 2>/dev/null || true"
echo "   systemctl --user disable omarchy-wayvnc-monitor.service 2>/dev/null || true"
echo ""
echo "3. Stop system service:"
echo "   sudo systemctl stop omarchy-wayvnc-monitor.service 2>/dev/null || true"
echo ""
echo "4. Deploy new monitor script:"
echo "   sudo cp /tmp/omarchy-wayvnc-monitor /usr/local/bin/omarchy-wayvnc-monitor"
echo "   sudo chmod +x /usr/local/bin/omarchy-wayvnc-monitor"
echo ""
echo "5. Deploy systemd service:"
echo "   sudo cp /tmp/omarchy-wayvnc-monitor.service /etc/systemd/system/"
echo "   sudo chmod 644 /etc/systemd/system/omarchy-wayvnc-monitor.service"
echo ""
echo "6. Enable and start the service:"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl enable --now omarchy-wayvnc-monitor.service"
echo ""
echo "7. Verify it's running:"
echo "   ps aux | grep omarchy-wayvnc | grep -v grep"
echo ""
echo "=========================================="
