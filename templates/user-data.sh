#!/bin/bash
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
set +x
%{ if enable_debug_logging }
set -x
%{ endif }

${pre_install}

# Essential packages including Singularity
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    awscli curl git jq unzip wget \
    openjdk-17-jdk python3.11 python3.11-venv \
    singularity-container

# Singularity setup
mkdir -p /opt/singularity/{tmp,cache}
chmod 777 /opt/singularity/{tmp,cache}

user_name=ubuntu
user_id=$(id -ru $user_name)

# Cloudwatch agent setup
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:${ssm_key_cloudwatch_agent_config}

# Docker rootless setup
curl -fsSL https://get.docker.com/rootless >>/opt/rootless.sh && chmod 755 /opt/rootless.sh
su -l $user_name -c /opt/rootless.sh

# Environment setup
cat >>/home/$user_name/.bashrc <<EOF
export XDG_RUNTIME_DIR=/run/user/$user_id
export DOCKER_HOST=unix:///run/user/$user_id/docker.sock
export PATH=/home/$user_name/bin:$PATH
export SINGULARITY_TMPDIR=/opt/singularity/tmp
export APPTAINER_TMPDIR=/opt/singularity/tmp
export SINGULARITY_CACHEDIR=/opt/singularity/cache
export APPTAINER_CACHEDIR=/opt/singularity/cache
EOF

# Docker config
mkdir -p "/home/$user_name/.config/docker"
echo '{"storage-driver":"fuse-overlayfs"}' > "/home/$user_name/.config/docker/daemon.json"
chown -R "$user_name" "/home/$user_name/.config/docker"

loginctl enable-linger $user_name
su -l $user_name -c "systemctl --user enable docker"

${install_runner}

cd /opt/actions-runner/
echo "DOCKER_HOST=unix:///run/user/$user_id/docker.sock" >>.env
echo "PATH=/home/$user_name/bin:$PATH" >>.env
sudo runuser $user_name -l -c "systemctl --user restart docker"

# Nextflow config
cat > nextflow.config <<EOF
docker.userEmulation = true
docker.runOptions = '--platform=linux/amd64'
EOF

# Directory setup
mkdir -p /home/ubuntu/tests /opt/actions-runner/_work/{tools/tools,modules/modules}
chown -R ubuntu:ubuntu /home/ubuntu/tests /opt/actions-runner/_work
chmod -R 2775 /home/ubuntu/tests /opt/actions-runner/_work

# Cleanup script
cat > /opt/actions-runner/cleanup.sh <<'EOF'
#!/bin/bash
clean_dir() { [ -d "$1" ] && rm -rf "$1"/* 2>/dev/null || echo "Directory not found: $1"; }
clean_dir "/opt/actions-runner/_work/modules/modules"
clean_dir "/opt/actions-runner/_work/tools/tools"
clean_dir "/home/ubuntu/tests"
EOF
chmod +x /opt/actions-runner/cleanup.sh
chown ubuntu:ubuntu /opt/actions-runner/cleanup.sh

mkdir -p /opt/actions-runner/hooks
echo '#!/bin/bash' > /opt/actions-runner/hooks/post-job.sh
echo '/opt/actions-runner/cleanup.sh' >> /opt/actions-runner/hooks/post-job.sh
chmod +x /opt/actions-runner/hooks/post-job.sh
chown ubuntu:ubuntu /opt/actions-runner/hooks/post-job.sh

su -l $user_name -c "git config --global --add safe.directory /opt/actions-runner/_work/tools/tools"
su -l $user_name -c "git config --global --add safe.directory /opt/actions-runner/_work/modules/modules"

${post_install}

cd /opt/actions-runner
${start_runner}