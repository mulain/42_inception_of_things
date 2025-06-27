#!/bin/bash
set -e

echo "🔧 Updating package lists..."
sudo apt update

echo "📦 Installing Git and curl..."
sudo apt install -y git curl

echo "✅ Installation complete!"

# Show versions
git --version
curl --version | head -n 1
