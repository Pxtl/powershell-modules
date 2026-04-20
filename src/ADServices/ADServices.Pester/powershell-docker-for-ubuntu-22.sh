#!/bin/bash
###################################
# Prerequisites

# this .sh script will configure a vanilla 22.04 docker image (running as root) to be able to run the tests.
# container installed with `docker run -d --privileged --name my-container ubuntu:22.04 tail -f /dev/null`
# connect to containers with `docker exec -it my-container /bin/bash`
# wipe containers with `docker rm ubuntu:22.04`

cd ~

# Update the list of packages
apt-get update

# Install pre-requisite packages.
apt-get install -y wget apt-transport-https software-properties-common

# Get the version of Ubuntu
source /etc/os-release

# Download the Microsoft repository keys
wget -q https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb

# Register the Microsoft repository keys
dpkg -i packages-microsoft-prod.deb

# Delete the Microsoft repository keys file
rm packages-microsoft-prod.deb

# Update the list of packages after we added packages.microsoft.com
apt-get update

###################################
# Install PowerShell
apt-get install -y powershell

# Add Docker's official GPG key:
apt-get update
apt-get install ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update

apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

###################################
# Hacks to get Docker working on Ubuntu 22.04

sed -i 's/ulimit -Hn 524288/ulimit -n 524288/' /etc/init.d/docker
apt install -y fuse-overlayfs
echo '{ "storage-driver": "fuse-overlayfs" }' > /etc/docker/daemon.json
service start docker

###################################
# Dotnet SDK
 
apt install -y dotnet-sdk-8.0 micro

###################################
# Test ADServices

cd ~
git clone https://github.com/Pxtl/powershell-modules.git
cd ~/powershell-modules/src/ADServices

dotnet build

pwsh -C 'Install-Module Pester -Force'
pwsh -C '& ./Tests/Integration/Invoke-IntegrationTest.ps1'