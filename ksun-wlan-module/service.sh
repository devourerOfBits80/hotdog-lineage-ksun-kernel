#!/system/bin/sh
MODDIR=${0%/*}

# Load custom WLAN module with compatible vermagic
# System's original module will fail to load due to vermagic mismatch
# This runs at late_start service stage

if ! lsmod | grep -q wlan; then
  insmod "$MODDIR/wlan.ko"
fi
