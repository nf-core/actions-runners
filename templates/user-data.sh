#!/bin/bash
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1


# AWS suggest to create a log for debug purpose based on https://aws.amazon.com/premiumsupport/knowledge-center/ec2-linux-log-user-data/
# As side effect all command, set +x disable debugging explicitly.
#
# An alternative for masking tokens could be: exec > >(sed 's/--token\ [^ ]* /--token\ *** /g' > /var/log/user-data.log) 2>&1
set +x

%{ if enable_debug_logging }
set -x
%{ endif }

${pre_install}

# Install AWS CLI
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    awscli \
    build-essential \
    curl \
    git \
    iptables \
    jq \
    uidmap \
    unzip \
    wget \
    openjdk-17-jdk \
    python3.11 \
    python3.11-venv

# alias python3 with python
alias python=python3

user_name=ubuntu
user_id=$(id -ru $user_name)

# install and configure cloudwatch logging agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:${ssm_key_cloudwatch_agent_config}

# configure systemd for running service in users accounts
cat >/etc/systemd/user@UID.service <<-EOF

[Unit]
Description=User Manager for UID %i
After=user-runtime-dir@%i.service
Wants=user-runtime-dir@%i.service

[Service]
LimitNOFILE=infinity
LimitNPROC=infinity
User=%i
PAMName=systemd-user
Type=notify

[Install]
WantedBy=default.target

EOF

echo export XDG_RUNTIME_DIR=/run/user/$user_id >>/home/$user_name/.bashrc

systemctl daemon-reload
systemctl enable user@UID.service
systemctl start user@UID.service

curl -fsSL https://get.docker.com/rootless >>/opt/rootless.sh && chmod 755 /opt/rootless.sh
su -l $user_name -c /opt/rootless.sh
echo export DOCKER_HOST=unix:///run/user/$user_id/docker.sock >>/home/$user_name/.bashrc
echo export PATH=/home/$user_name/bin:$PATH >>/home/$user_name/.bashrc

# Change storage driver to fuse-overlayfs
apt-get install -y fuse-overlayfs
mkdir -p "/home/$user_name/.config/docker"
cat > "/home/$user_name/.config/docker/daemon.json" <<-EOF

{
  "storage-driver": "fuse-overlayfs"
}

EOF
chown -R "$user_name" "/home/$user_name/.config/docker"

# Run docker service by default
loginctl enable-linger $user_name
su -l $user_name -c "systemctl --user enable docker"

${install_runner}

# config runner for rootless docker
cd /opt/actions-runner/
echo DOCKER_HOST=unix:///run/user/$user_id/docker.sock >>.env
echo PATH=/home/$user_name/bin:$PATH >>.env

# Restart docker to use fuse-overlayfs storage driver
sudo runuser $user_name -l -c "systemctl --user restart docker"

# add extra nextflow config for to make docker run on AWS
echo "docker.userEmulation = true" > nextflow.config
# echo "docker.fixOwnership = true" >> nextflow.config
echo "docker.runOptions = '--platform=linux/amd64'" >> nextflow.config

# Create and set permissions for Nextflow work directories
mkdir -p /home/ubuntu/tests
chown -R ubuntu:ubuntu /home/ubuntu/tests
chmod 2775 /home/ubuntu/tests  # Set SGID bit and give group write permissions

mkdir -p /opt/actions-runner/_work/tools/tools

${post_install}

cd /opt/actions-runner

${start_runner}
