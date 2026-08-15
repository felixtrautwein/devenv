#!/usr/bin/env bash
# PlatformIO toolchain for microcontroller development.
set -euo pipefail

apt-get update
apt-get install -y --no-install-recommends \
    clang \
    udev \
    x11-apps
apt-get clean
rm -rf /var/lib/apt/lists/*

curl -fsSL https://raw.githubusercontent.com/platformio/platformio-core/develop/platformio/assets/system/99-platformio-udev.rules \
    -o /etc/udev/rules.d/99-platformio-udev.rules
