#!/bin/bash
set -e

# Define version
VBOX_VERSION="7.0.18"
CODENAME=$(lsb_release -cs)

echo "🔧 Installing prerequisites..."
sudo apt update
sudo apt install -y wget gnupg2 software-properties-common

echo "🔑 Adding Oracle GPG key..."
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo gpg --dearmor -o /usr/share/keyrings/oracle-virtualbox.gpg

echo "📦 Adding VirtualBox APT repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/oracle-virtualbox.gpg] https://download.virtualbox.org/virtualbox/debian $CODENAME contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list

echo "🔄 Updating package lists..."
sudo apt update

echo "🚀 Installing VirtualBox $VBOX_VERSION..."
sudo apt install -y virtualbox-$VBOX_VERSION

echo "📥 Downloading Extension Pack..."
wget https://download.virtualbox.org/virtualbox/$VBOX_VERSION/Oracle_VM_VirtualBox_Extension_Pack-$VBOX_VERSION.vbox-extpack

echo "📦 Installing Extension Pack..."
sudo VBoxManage extpack install Oracle_VM_VirtualBox_Extension_Pack-$VBOX_VERSION.vbox-extpack --replace

echo "✅ VirtualBox $VBOX_VERSION installation complete!"
virtualbox --help | head -n 3
