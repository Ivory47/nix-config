#!/usr/bin/env bash

# stops script when something goes wrong
set -euo pipefail

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
sudo -v

if [ -d "/etc/nixos.bak" ] || [ -L "/etc/nixos.bak" ]; then
    echo "directory /etc/nixos.bak already exists"
    exit 1
fi 

echo "Backing up /etc/nixos to /etc/nixos.bak..."
sudo mv /etc/nixos /etc/nixos.bak
echo "Linking system config..."
sudo ln -s "$SCRIPT_DIR/system" /etc/nixos
sudo ln -s /etc/nixos.bak/hardware-configuration.nix "$SCRIPT_DIR/system/"

if [ ! -d "$REAL_HOME/.config" ]; then
    echo "creating .config directory..."
    mkdir -p "$REAL_HOME/.config"
fi 

if [ -d "$REAL_HOME/.config/home-manager" ] || [ -L "$REAL_HOME/.config/home-manager" ]; then
    echo "directory $REAL_HOME/.config/home-manager already exists"
    exit 1
fi 

echo "Linking user config..."
ln -s "$SCRIPT_DIR/home-manager" "$REAL_HOME/.config/home-manager"
