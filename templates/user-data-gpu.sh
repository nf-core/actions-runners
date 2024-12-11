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

# Fix duplicate NVIDIA repos
rm -f /etc/apt/sources.list.d/cuda-ubuntu2204-x86_64.list


systemctl restart docker

# Install CloudWatch agent
%{ if enable_cloudwatch_agent ~}
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm -f ./amazon-cloudwatch-agent.deb
amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:${ssm_key_cloudwatch_agent_config}
%{ endif ~}

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
chmod 777 /home/ubuntu/tests  # Ensuring full read/write/execute permissions for nf-test

# Simple GPU verification - using AMI's default setup
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.0.1-base-ubuntu22.04 nvidia-smi

${post_install}

cd /opt/actions-runner
${start_runner}