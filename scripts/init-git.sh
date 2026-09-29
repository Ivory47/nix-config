#!/usr/bin/env bash

set -Eeuo pipefail

trap 'echo "ERROR: command failed at line $LINENO: $BASH_COMMAND" >&2' ERR

git config --global user.name "Ivory47"
git config --global user.email "148820959+Ivory47@users.noreply.github.com"
