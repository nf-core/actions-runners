#!/bin/bash
# This script is designed for Deep Learning Base OSS Nvidia Driver GPU AMI
# Configure logging
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# Prevent unattended-upgrades from interfering with package installation
systemctl stop unattended-upgrades
systemctl disable unattended-upgrades
pkill -f unattended-upgrade || true

# Enable debug logging if specified
%{ if enable_debug_logging ~}
set -x
%{ endif ~}

# Pre-install hook
%{ if pre_install != "" ~}
${pre_install}
%{ endif ~}
# Configure kernel modules and networking
cat << EOF > /etc/modules-load.d/bridge.conf
br_netfilter
EOF
cat << EOF > /etc/sysctl.d/99-docker-bridge.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
# Apply sysctl settings without reboot
modprobe br_netfilter
sysctl -p /etc/sysctl.d/99-docker-bridge.conf
# Install CloudWatch agent if enabled
%{ if enable_cloudwatch_agent ~}
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm -f ./amazon-cloudwatch-agent.deb
amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:${ssm_key_cloudwatch_agent_config}
%{ endif ~}
# Create directories and set ownership
mkdir -p /opt/actions-runner
chown -R ubuntu:ubuntu /opt/actions-runner
# Install the GitHub runner
${install_runner}
# Add the user to the docker group
usermod -aG docker ubuntu
# Install NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt-get update
apt-get install -y nvidia-container-toolkit
# Configure Docker daemon with GPU support
cat > /etc/docker/daemon.json <<'EOF'
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    },
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOF
# Ensure necessary environment variables for Docker and systemd
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
# Configure nvidia-container-runtime
nvidia-ctk runtime configure --runtime=docker
# Restart Docker to apply new settings
systemctl restart docker
systemctl enable docker
# Verify NVIDIA driver installation
nvidia-smi
# Set GPU permissions
chmod u+s /usr/bin/nvidia-smi
usermod -aG video ubuntu
# Set environment variables for GPU access
echo 'export NVIDIA_VISIBLE_DEVICES=all' >> /home/ubuntu/.bashrc
echo 'export NVIDIA_DRIVER_CAPABILITIES=compute,utility' >> /home/ubuntu/.bashrc
# Post-install hook
%{ if post_install != "" ~}
${post_install}
%{ endif ~}
# Start the runner
cd /opt/actions-runner
${start_runner}
# Function to verify GPU setup with retries
verify_gpu_setup() {
    local max_attempts=3
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        echo "GPU verification attempt $attempt of $max_attempts"
        
        # Check NVIDIA driver
        if ! nvidia-smi &>/dev/null; then
            echo "Warning: nvidia-smi command failed on attempt $attempt"
            attempt=$((attempt + 1))
            sleep 5
            continue
        fi
        
        # Check NVIDIA Container Toolkit
        if ! nvidia-ctk --version &>/dev/null; then
            echo "Warning: NVIDIA Container Toolkit not properly installed"
            attempt=$((attempt + 1))
            sleep 5
            continue
        fi
        # Test Docker GPU support
        CUDA_TEST_IMAGE="nvidia/cuda:12.0.1-base-ubuntu22.04"
        echo "Pulling CUDA test image: $CUDA_TEST_IMAGE"
        if ! docker pull $CUDA_TEST_IMAGE; then
            echo "Warning: Failed to pull CUDA test image on attempt $attempt"
            attempt=$((attempt + 1))
            sleep 5
            continue
        fi
        
        if docker run --rm --gpus all $CUDA_TEST_IMAGE nvidia-smi; then
            echo "GPU setup verification successful"
            # Test CUDA capability
            if docker run --rm --gpus all $CUDA_TEST_IMAGE nvidia-smi -L | grep "GPU 0"; then
                echo "CUDA capability verified"
                return 0
            fi
        fi
        
        echo "Warning: Docker GPU test failed on attempt $attempt"
        attempt=$((attempt + 1))
        sleep 5
    done
    
    echo "Warning: GPU setup verification failed after $max_attempts attempts"
    return 1
}
# Run verification
echo "Docker version: $(docker --version)"
echo "Docker info: $(docker info)"
echo "Current user groups: $(groups ubuntu)"
verify_gpu_setup
# Clean up
docker system prune -f