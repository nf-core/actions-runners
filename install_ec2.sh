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
#Install Node > 19.0, to make editorconfig work
curl -fsSL https://deb.nodesource.com/setup_19.x | sudo -E bash - &&\
sudo apt-get install -y nodejs
sudo apt-get install -y npm
#Install latest npm version
sudo chmod -R 777 /usr/local/lib
sudo chmod -R 777 /usr/local/bin/
#install conda
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && bash Miniconda3-latest-Linux-x86_64.sh
#install singularity
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
#PHP Composer for website stuff
sudo apt install php-cli unzip 
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
