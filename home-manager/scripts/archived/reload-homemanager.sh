#!/usr/bin/env bash

set -e

QUICKSHELL_DIR="$HOME/.config/home-manager/quickshell/status-bar"

QT_QML_PATH="$(nix eval --raw nixpkgs#qt6.qtdeclarative)/lib/qt-6/qml"
QUICKSHELL_QML_PATH="$(nix eval --raw nixpkgs#quickshell)/lib/qt-6/qml"

cat > "$QUICKSHELL_DIR/.qmlls.ini" <<EOF
[General]
importPaths=$QT_QML_PATH:$QUICKSHELL_QML_PATH
EOF

home-manager switch --flake "$HOME/.config/home-manager" -b backup

source "$HOME/.zshrc"
