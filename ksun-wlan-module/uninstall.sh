#!/system/bin/sh

# Unload WLAN module when removing this KernelSU module
if lsmod | grep -q wlan; then
  rmmod wlan 2>/dev/null || true
fi
