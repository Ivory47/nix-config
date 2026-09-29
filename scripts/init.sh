#!/usr/bin/env bash

set -Eeuo pipefail

trap 'echo "ERROR: command failed at line $LINENO: $BASH_COMMAND" >&2' ERR

run_step() {
    echo
    echo "==> $1"
    shift
    "$@"
}

run_step "Linking configuration" ./link.sh

# run_step "Creating local configuration" \
#     cp /etc/nixos/local/template.nix /etc/nixos/local/local-config.nix

run_step "Initializing Git" ./init-git.sh

echo
echo "==> Setup completed successfully!"
