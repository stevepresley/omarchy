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

# Copy the deployment helper script
echo ""
echo "Copying deployment helper script..."
scp scripts/deploy-wayvnc-monitor.sh "$SSH_USER@$VM_IP:/tmp/deploy-wayvnc-monitor.sh" >/dev/null
echo "✓ Helper script copied"

echo ""
echo "=========================================="
echo "✓ Files Ready for Deployment"
echo "=========================================="
echo ""
echo "To complete deployment, SSH to your VM and run:"
echo ""
echo "  ssh $SSH_USER@$VM_IP"
echo "  bash /tmp/deploy-wayvnc-monitor.sh"
echo ""
echo "=========================================="
