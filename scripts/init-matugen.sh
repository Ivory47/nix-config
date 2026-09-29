#!/usr/bin/env bash

set -Eeuo pipefail

trap 'echo "ERROR: command failed at line $LINENO: $BASH_COMMAND" >&2' ERR

matugen color hex 6750A4
