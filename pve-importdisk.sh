if [ $# -lt 3 ] || [ $# -gt 4 ]; then
    echo not enough arguments.
    echo "args... [vmID] [imagePath] [targetPool] [diskNum (default: 0)]"
    echo ""
    echo "options (environment variables):"
    echo "  DISK_SIZE  disk size to resize after import (e.g. 20G). default: no resize"
    exit 1
fi

VMID=$1
IMAGE_PATH=$2
TARGET_POOL=$3
DISK_NUM=${4:-0}
DISK_VOL="$TARGET_POOL:vm-$VMID-disk-$DISK_NUM"

# check if the target disk slot already exists
EXISTING=$(qm config "$VMID" 2>/dev/null | awk '/^scsi'"$DISK_NUM"':/ {print $2}')
if [ -n "$EXISTING" ]; then
    echo "error: scsi$DISK_NUM already exists on VM $VMID ($EXISTING)"
    echo "aborting to prevent overwriting an existing disk."
    exit 1
fi

echo qm import Disk...
qm importdisk "$VMID" "$IMAGE_PATH" "$TARGET_POOL"
echo set Disk...
qm set "$VMID" --scsihw virtio-scsi-pci --scsi"$DISK_NUM" "$DISK_VOL"

if [ -n "$DISK_SIZE" ]; then
    echo resize Disk to $DISK_SIZE...
    qm resize "$VMID" "scsi$DISK_NUM" "$DISK_SIZE"
fi
