#!/usr/bin/env bash

pkill -f "quickshell -c status-bar"
qs -c status-bar &
