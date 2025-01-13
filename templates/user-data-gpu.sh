#!/bin/bash
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
set -e
%{ if enable_debug_logging ~}
set -x
%{ endif ~}

${pre_install}

# Base system setup
apt-get -qq update
systemctl stop unattended-upgrades
systemctl disable unattended-upgrades


# Configure Docker daemon with NVIDIA runtime
cat > /etc/docker/daemon.json <<EOF
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
EOF

# Restart Docker to apply changes
systemctl restart docker

# Install CloudWatch agent
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm -f ./amazon-cloudwatch-agent.deb
amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:${ssm_key_cloudwatch_agent_config}

# Setup GitHub runner
mkdir -p /opt/actions-runner
chown -R ubuntu:ubuntu /opt/actions-runner
${install_runner}

# Setup permissions and groups
usermod -aG docker ubuntu
chmod u+s /usr/bin/nvidia-smi
usermod -aG video ubuntu

# Create work directories with proper permissions
mkdir -p /home/ubuntu/actions-runner/_work
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner/_work
chmod 755 /home/ubuntu/actions-runner/_work

# Create nf-test default directory with proper permissions
mkdir -p /home/ubuntu/tests
chown -R ubuntu:ubuntu /home/ubuntu/tests
chmod 777 /home/ubuntu/tests

# Function to log failure and diagnostic information
log_failure() {
    echo "ERROR: $1"
    echo "--- System Information ---"
    uname -a
    echo "--- NVIDIA Driver Information ---"
    nvidia-smi -q || true
    echo "--- Docker Information ---"
    docker info || true
    echo "--- Journal Logs ---"
    journalctl -u nvidia-persistenced --no-pager | tail -n 20 || true
}

# Comprehensive GPU verification
echo "Starting comprehensive GPU verification..."

# Check 1: Verify NVIDIA driver installation
echo "Verifying NVIDIA driver installation..."
if ! nvidia-smi; then
    log_failure "nvidia-smi check failed"
    exit 1
fi

# Check 2: Verify NVIDIA Container Toolkit
echo "Verifying NVIDIA Container Toolkit..."
if ! nvidia-ctk --version; then
    log_failure "NVIDIA Container Toolkit check failed"
    exit 1
fi

# Check 3: Test GPU access within container
echo "Testing GPU access within container..."
if ! docker run --rm --gpus all nvidia/cuda:12.0.1-base-ubuntu22.04 nvidia-smi; then
    log_failure "Docker GPU check failed"
    exit 1
fi

# Check 4: Testing CUDA capabilities
echo "Testing CUDA capabilities..."
if ! docker run --rm --gpus all nvidia/cuda:12.0.1-base-ubuntu22.04 nvidia-smi -q | grep "CUDA Version"; then
    log_failure "CUDA capability check failed"
    exit 1
fi

echo "GPU verification completed successfully"

${post_install}

# Start the runner
cd /opt/actions-runner
${start_runner}