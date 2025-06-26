#!/bin/bash
set -e

KEY_DIR="/root/.ssh"
KEY_PATH="$KEY_DIR/id_rsa"

# Ensure SSH key exists

if [ ! -f "$KEY_PATH" ]; then
  echo "🔐 SSH key not found at $KEY_PATH, generating one now..."
  mkdir -p "$KEY_DIR"
  ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f "$KEY_PATH" -N ""
  chmod 600 "$KEY_PATH" "$KEY_PATH.pub"
fi

# Output the public key

echo "⚠️  Add the following SSH public key to GitLab:"
cat "$KEY_PATH.pub"
