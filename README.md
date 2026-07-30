# proxmox-tools
proxmox のコマンドを一括化したりするコマンドラインツールです

## スクリプト

### pve-importdisk.sh
既存の VM にディスクをインポートする。

```
./pve-importdisk.sh [vmID] [imagePath] [targetPool] [diskNum]
```

- `diskNum` は省略可能（デフォルト: `0`）
- 既に同じスロット（`scsi<diskNum>`）にディスクが存在する場合は上書きを防ぐためエラー停止します

オプション（環境変数で上書き可能）:

| 変数        | デフォルト | 説明                                                                 |
| ----------- | ---------- | -------------------------------------------------------------------- |
| `DISK_SIZE` | (なし)     | インポート後にリサイズするディスクサイズ (例: `20G`)。未指定時はそのままのサイズ |

例:

```
# 通常のインポート (diskNum=0)
./pve-importdisk.sh 100 /tmp/ubuntu-22.04.img local-lvm

# diskNum を明示指定
./pve-importdisk.sh 100 /tmp/ubuntu-22.04.img local-lvm 1

# インポート後に 20G にリサイズ
DISK_SIZE=20G ./pve-importdisk.sh 100 /tmp/ubuntu-22.04.img local-lvm 0
```

### pve-create-template.sh
cloud image から VM テンプレートを作成し、指定したリソースプールに割り当てる。

```
./pve-create-template.sh [vmID] [imagePath] [resourcePool] [diskPool]
```

オプション（環境変数で上書き可能）:

| 変数        | デフォルト                | 説明                                                          |
| ----------- | ------------------------- | ------------------------------------------------------------- |
| `VM_NAME`   | `template-<vmID>`         | VM 名                                                         |
| `MEMORY`    | `2048`                    | メモリ (MB)                                                   |
| `CORES`     | `2`                       | CPU コア数                                                    |
| `NET0`      | `virtio,bridge=vmbr0`     | ネットワーク設定                                              |
| `CI_IMAGE`  | `<diskPool>:cloudinit`    | cloud-init 用イメージの場所                                   |
| `DISK_SIZE` | `10G`                     | ディスクサイズ。cloud image がこれより大きい場合はエラー停止  |

例:

```
# 2GB / 2core のテンプレートを作成
./pve-create-template.sh 9000 /tmp/ubuntu-22.04.img my-pool local-lvm

# メモリとコア数を指定して作成
MEMORY=4096 CORES=4 ./pve-create-template.sh 9001 /tmp/debian-12.img my-pool local-lvm

# ディスクサイズを 20G に指定して作成
DISK_SIZE=20G ./pve-create-template.sh 9002 /tmp/fedora-40.img my-pool local-lvm
```
