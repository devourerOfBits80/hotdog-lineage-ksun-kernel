#!/sbin/sh
properties() { 'kernel.string=KernelSU-Next for OnePlus 7T Pro (LineageOS)
kernel.made=GitHub Actions
kernel.compiler=Auto-detected AOSP prebuilts
device.name1=hotdog
device.name2=OnePlus7TPro
device.name3=OP7TPro
device.name4=HD1913
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
'; }

block=auto
is_slot_device=1
ramdisk_compression=auto
patch_vbmeta_flag=auto

. tools/ak3-core.sh

IMAGE_NAME=""
for candidate in __IMAGE_NAME__ Image.gz-dtb Image.gz Image.lz4-dtb Image.lz4 Image; do
  if [ -f "$candidate" ]; then
    IMAGE_NAME="$candidate"
    break
  fi
done
if [ -z "$IMAGE_NAME" ]; then
  ui_print "Kernel image not found."
  abort
fi

split_boot
flash_boot

# Install WLAN module if present
if [ -f "modules/vendor_dlkm/lib/modules/qca_cld3_wlan.ko" ]; then
  ui_print "Installing WLAN module..."
  mount /vendor_dlkm 2>/dev/null || true
  mount -o rw,remount /vendor_dlkm 2>/dev/null || true
  if [ -d "/vendor_dlkm/lib/modules" ]; then
    cp -f modules/vendor_dlkm/lib/modules/qca_cld3_wlan.ko /vendor_dlkm/lib/modules/
    chmod 644 /vendor_dlkm/lib/modules/qca_cld3_wlan.ko
    ui_print "WLAN module installed to /vendor_dlkm/lib/modules/"
  else
    ui_print "Warning: /vendor_dlkm/lib/modules not found, skipping WLAN module"
  fi
fi
