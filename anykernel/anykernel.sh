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
  SLOT=$(getprop ro.boot.slot_suffix 2>/dev/null)

  # Mount /vendor partition (this is where init loads module from)
  for blkpath in \
    "/dev/block/by-name/vendor${SLOT}" \
    "/dev/block/by-name/vendor" \
    "/dev/block/bootdevice/by-name/vendor${SLOT}" \
    "/dev/block/bootdevice/by-name/vendor"; do
    if [ -e "$blkpath" ]; then
      ui_print "Found vendor at $blkpath"
      mkdir -p /vendor
      mount -t ext4 -o rw "$blkpath" /vendor 2>/dev/null && break
      mount "$blkpath" /vendor 2>/dev/null && break
    fi
  done
  mount -o rw,remount /vendor 2>/dev/null || true

  # Install to /vendor/lib/modules (where init.target.rc loads from)
  if [ -d "/vendor/lib/modules" ]; then
    cp -f modules/vendor_dlkm/lib/modules/qca_cld3_wlan.ko /vendor/lib/modules/
    chmod 644 /vendor/lib/modules/qca_cld3_wlan.ko
    ui_print "WLAN module installed to /vendor/lib/modules/"
  else
    mkdir -p /vendor/lib/modules
    cp -f modules/vendor_dlkm/lib/modules/qca_cld3_wlan.ko /vendor/lib/modules/
    chmod 644 /vendor/lib/modules/qca_cld3_wlan.ko
    ui_print "WLAN module installed to /vendor/lib/modules/ (created)"
  fi
fi
