#!/usr/bin/env bash

pkill -f "quickshell -c status-bar"
qs -c status-bar &


pkill -f "quickshell -c app-launcher"
qs -c app-launcher &
