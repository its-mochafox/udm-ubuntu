#!/bin/bash
# udm-firstboot.sh - one-shot first boot tasks.
#   * regenerate SSH host keys (never baked into a distributed image)
#   * grow the root filesystem to fill the physical disk
set -euo pipefail

MARKER=/var/lib/udm-firstboot.done
[ -f "$MARKER" ] && exit 0

echo "udm-firstboot: regenerating SSH host keys"
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A

echo "udm-firstboot: growing root filesystem to fill the disk"
ROOT_DEV="$(findmnt -n -o SOURCE /)"
case "$ROOT_DEV" in
    /dev/sda1|/dev/nvme0n1p1)
        resize2fs "$ROOT_DEV" || echo "udm-firstboot: resize2fs failed (non-fatal)" ;;
    *) echo "udm-firstboot: unexpected root device $ROOT_DEV, skipping resize" ;;
esac

touch "$MARKER"
echo "udm-firstboot: complete"
