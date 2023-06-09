#!/usr/bin/env bash
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common
sudo apt-get update
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu  $(lsb_release -cs)  stable"
sudo apt update
sudo apt-get install docker-ce
sudo systemctl start docker
sudo groupadd docker
sudo usermod -aG docker ubuntu

# Install Node > 19.0, to make editorconfig / prettier etc. work
curl -fsSL https://deb.nodesource.com/setup_19.x | sudo -E bash - &&\
sudo apt-get install -y nodejs
sudo apt-get install -y npm

# Setup actions to be able to write to certain directories when installing libraries
sudo chmod -R 777 /usr/local/lib
sudo chmod -R 777 /usr/local/bin
sudo chmod -R 777 /usr/lib

# Install conda
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && bash Miniconda3-latest-Linux-x86_64.sh

# Install singularity
sudo apt-get update && sudo apt-get install -y \
    build-essential \
    uuid-dev \
    libgpgme-dev \
    squashfs-tools \
    libseccomp-dev \
    wget \
    pkg-config \
    git \
    cryptsetup-bin \
    uidmap \
    openjdk-18-jre-headless
wget https://github.com/sylabs/singularity/releases/download/v3.11.1/singularity-ce_3.11.1-jammy_amd64.deb
sudo dpkg -i singularity-ce_3.11.1-jammy_amd64.deb

# PHP Composer for website stuff
sudo apt install php-cli unzip 
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

#
# Run this part of the script after adding a new user "runner"
# who should be made part of usergroup(s) docker and sudo to be able to run the services!
#

# Add "runner" user, change to it and add it to the required groups, work needs to be in the same directory as on regular GHA runners
sudo useradd runnner
sudo usermod -a -G docker runner

# Change to runner user
sudo su runner

# Set the npm prefix
npm config set prefix /usr/local

# Continue with the regular setup under user runner and make sure work is in the home of runner as written in the readme file
