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

# Create deployment script on VM
echo ""
echo "Creating deployment script on VM..."
ssh "$SSH_USER@$VM_IP" cat > /tmp/deploy-wayvnc.sh << 'DEPLOY_SCRIPT'
#!/bin/bash
set -e

echo "Killing old processes..."
sudo pkill -9 -f 'omarchy-wayvnc-disconnect-lock' || true
sudo pkill -9 -f 'omarchy-wayvnc-monitor' || true

echo "Stopping and disabling old user service..."
systemctl --user stop omarchy-wayvnc-monitor.service 2>/dev/null || true
systemctl --user disable omarchy-wayvnc-monitor.service 2>/dev/null || true

echo "Stopping system service..."
sudo systemctl stop omarchy-wayvnc-monitor.service 2>/dev/null || true

echo "Deploying new monitor script..."
sudo cp /tmp/omarchy-wayvnc-monitor /usr/local/bin/omarchy-wayvnc-monitor
sudo chmod +x /usr/local/bin/omarchy-wayvnc-monitor

echo "Deploying systemd service..."
sudo cp /tmp/omarchy-wayvnc-monitor.service /etc/systemd/system/
sudo chmod 644 /etc/systemd/system/omarchy-wayvnc-monitor.service

echo "Enabling and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable --now omarchy-wayvnc-monitor.service

echo "Verifying..."
ps aux | grep omarchy-wayvnc | grep -v grep

echo "✓ Deployment complete!"
DEPLOY_SCRIPT

ssh "$SSH_USER@$VM_IP" chmod +x /tmp/deploy-wayvnc.sh
echo "✓ Deployment script created at /tmp/deploy-wayvnc.sh"

# Show final instructions
echo ""
echo "=========================================="
echo "Ready to Deploy!"
echo "=========================================="
echo ""
echo "Run this command on your VM to complete deployment:"
echo ""
echo "  /tmp/deploy-wayvnc.sh"
echo ""
echo "=========================================="
