#!/bin/bash
# cloud image から VM テンプレートを作成する
#
# args... [vmID] [imagePath] [resourcePool] [diskPool]
#
# オプション（環境変数で上書き可能）:
#   VM_NAME   VM 名            (デフォルト: template-<vmID>)
#   MEMORY    メモリ(MB)        (デフォルト: 2048)
#   CORES     CPU コア数        (デフォルト: 2)
#   NET0      ネットワーク設定  (デフォルト: virtio,bridge=vmbr0)
#   CI_IMAGE  cloud-init 用イメージ (デフォルト: diskPool:cloudinit)
#   DISK_SIZE ディスクサイズ    (デフォルト: 10G)
#             cloud image がこれより大きい場合はエラーで停止する

set -euo pipefail

# サイズ文字列 (例: 10G, 512M, 1T) を bytes に変換
size_to_bytes() {
    local size="$1"
    local num unit
    num=$(echo "$size" | grep -oE '^[0-9]+')
    unit=$(echo "$size" | grep -oE '[A-Za-z]+$' | tr 'a-z' 'A-Z')
    case "$unit" in
        T|TB) echo $((num * 1024 * 1024 * 1024 * 1024)) ;;
        G|GB) echo $((num * 1024 * 1024 * 1024)) ;;
        M|MB) echo $((num * 1024 * 1024)) ;;
        K|KB) echo $((num * 1024)) ;;
        *) echo "$num" ;;
    esac
}

# bytes を人間が読みやすい形式に
bytes_to_human() {
    numfmt --to=iec "$1"
}

if [ $# -ne 4 ]; then
    echo not enough arguments.
    echo "args... [vmID] [imagePath] [resourcePool] [diskPool]"
    exit 1
fi

VM_ID="$1"
IMAGE_PATH="$2"
RESOURCE_POOL="$3"
DISK_POOL="$4"

VM_NAME="${VM_NAME:-template-$VM_ID}"
MEMORY="${MEMORY:-2048}"
CORES="${CORES:-2}"
NET0="${NET0:-virtio,bridge=vmbr0}"
CI_IMAGE="${CI_IMAGE:-$DISK_POOL:cloudinit}"
DISK_SIZE="${DISK_SIZE:-10G}"

# cloud image のサイズをチェック
if [ ! -f "$IMAGE_PATH" ]; then
    echo "ERROR: image not found: $IMAGE_PATH"
    exit 1
fi

IMAGE_BYTES=$(qemu-img info --output=json "$IMAGE_PATH" | grep -o '"virtual-size":[0-9]*' | head -1 | cut -d: -f2)
TARGET_BYTES=$(size_to_bytes "$DISK_SIZE")

echo "cloud image size: $(bytes_to_human "$IMAGE_BYTES") (target: $DISK_SIZE)"

if [ "$IMAGE_BYTES" -gt "$TARGET_BYTES" ]; then
    echo "ERROR: cloud image ($(bytes_to_human "$IMAGE_BYTES")) is larger than DISK_SIZE ($DISK_SIZE)."
    echo "Please specify a larger DISK_SIZE (e.g. DISK_SIZE=20G $0 ...)."
    exit 1
fi

echo "create VM $VM_ID ($VM_NAME)..."
qm create "$VM_ID" --name "$VM_NAME" --memory "$MEMORY" --cores "$CORES" --net0 "$NET0"

echo "import disk from $IMAGE_PATH to $DISK_POOL..."
qm importdisk "$VM_ID" "$IMAGE_PATH" "$DISK_POOL"

echo "attach disk as scsi0..."
qm set "$VM_ID" --scsihw virtio-scsi-pci --scsi0 "$DISK_POOL:vm-$VM_ID-disk-0"

echo "resize disk to $DISK_SIZE..."
qm resize "$VM_ID" scsi0 "$DISK_SIZE"

echo "add cloud-init drive..."
qm set "$VM_ID" --ide2 "$CI_IMAGE" --boot c --bootdisk scsi0

echo "add serial console for cloud-init..."
qm set "$VM_ID" --serial0 socket --vga serial0

echo "convert to template..."
qm template "$VM_ID"

echo "assign to resource pool $RESOURCE_POOL..."
qm set "$VM_ID" --pool "$RESOURCE_POOL"

echo "done. template $VM_ID created in pool '$RESOURCE_POOL'."
