#!/bin/bash
set -e

echo "🔧 Installing prerequisites..."
sudo apt update
sudo apt install -y wget gnupg software-properties-common

echo "🔑 Adding HashiCorp GPG key..."
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "📦 Adding HashiCorp APT repository..."
UBUNTU_CODENAME=$(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $UBUNTU_CODENAME main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

echo "🔄 Updating package lists..."
sudo apt update

echo "🚀 Installing Vagrant..."
sudo apt install -y vagrant

echo "✅ Vagrant installation complete!"
vagrant --version
