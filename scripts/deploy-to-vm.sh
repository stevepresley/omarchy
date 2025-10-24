#!/bin/bash
# Deploy Omarchy Advanced wayvnc monitor - ONE COMMAND, ONE PASSWORD
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

# Setup SSH control socket for connection multiplexing
# This allows all SSH/SCP commands to reuse the same authenticated session
CONTROL_SOCKET="/tmp/ssh-deploy-control-%h-%p-%r"
SSH_OPTS="-o ControlMaster=yes -o ControlPath=$CONTROL_SOCKET -o ControlPersist=5m"

echo "Establishing SSH connection (you will enter password once)..."
ssh $SSH_OPTS -o ConnectTimeout=5 "$SSH_USER@$VM_IP" "echo 'SSH OK'" || {
  echo "ERROR: Cannot connect to $VM_IP via SSH"
  exit 1
}
echo "✓ SSH connection established"

echo ""
echo "Deploying wayvnc monitor..."

# Copy all files in one batch (reuses SSH session, no password needed)
scp $SSH_OPTS -q install/files/usr-local-bin-omarchy-wayvnc-monitor "$SSH_USER@$VM_IP:/tmp/omarchy-wayvnc-monitor"
scp $SSH_OPTS -q config/systemd/system/omarchy-wayvnc-monitor.service "$SSH_USER@$VM_IP:/tmp/omarchy-wayvnc-monitor.service"
scp $SSH_OPTS -q scripts/deploy-wayvnc-monitor.sh "$SSH_USER@$VM_IP:/tmp/deploy-wayvnc-monitor.sh"
echo "✓ Files copied to /tmp on VM"

# Execute deployment script (reuses SSH session)
ssh $SSH_OPTS -t "$SSH_USER@$VM_IP" sudo bash /tmp/deploy-wayvnc-monitor.sh

echo ""
echo "=========================================="
echo "✓ Deployment Complete!"
echo "=========================================="
