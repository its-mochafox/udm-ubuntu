#!/bin/bash
# build.sh - assemble a bootable Ubuntu rootfs disk image for the Ubiquiti UDM-Pro.
#
# The UDM-Pro boot chain (SPI U-Boot -> signed FIT kernel from internal SD) is
# untouched by this image; the kernel is Ubiquiti's own signed 4.19 and boots this
# rootfs via root=/dev/sda1 (see docs/install.md for the per-device U-Boot setup).
#
# Requires: Linux with root (losetup/mount), parted, e2fsprogs, xz-utils.
# On arm64 hosts the chroot runs natively; on x86-64 it runs under qemu-user-static.
set -euo pipefail

cd "$(dirname "$0")"
source ./config.sh

export OUT_DIR
mkdir -p "$OUT_DIR"
IMAGE="$OUT_DIR/udm-ubuntu-${SUITE}.img"

NATIVE_ARCH="$(uname -m)"
if [ "$NATIVE_ARCH" = "aarch64" ]; then
    CHROOT_PREFIX=""
else
    echo ">> non-arm64 host: using qemu-user-static for the chroot"
    if ! command -v qemu-aarch64-static >/dev/null; then
        echo "!! install qemu-user-static first" >&2
        exit 1
    fi
    CHROOT_PREFIX="qemu-aarch64-static"
fi

echo ">> fetching Ubuntu base rootfs"
[ -f "$BASE_TARBALL" ] || curl -fSL -o "$BASE_TARBALL" "$BASE_URL/$BASE_TARBALL"

echo ">> creating ${IMAGE_SIZE} image"
rm -f "$IMAGE"
truncate -s "$IMAGE_SIZE" "$IMAGE"

echo ">> partitioning (GPT, single root partition)"
parted -s "$IMAGE" mklabel gpt mkpart primary ext4 1MiB 100%

echo ">> setting up loop device"
LOOP="$(losetup --find --show -P "$IMAGE")"
ROOTDEV="${LOOP}p1"
cleanup() {
    set +e
    umount -R "$MNT" 2>/dev/null
    losetup -d "$LOOP" 2>/dev/null
}
trap cleanup EXIT

echo ">> formatting root partition"
mkfs.ext4 -F -L "$ROOT_LABEL" "$ROOTDEV"

MNT="$(mktemp -d)"
echo ">> unpacking base rootfs to $MNT"
mount "$ROOTDEV" "$MNT"
tar --numeric-owner -xzf "$BASE_TARBALL" -C "$MNT"

if [ -n "$CHROOT_PREFIX" ]; then
    cp "$(command -v qemu-aarch64-static)" "$MNT/usr/bin/"
fi

echo ">> preparing chroot"
mount -t proc proc "$MNT/proc"
mount --rbind /sys "$MNT/sys"
mount --rbind /dev "$MNT/dev"
mount --rbind /dev/pts "$MNT/dev/pts"

cp packages.list scripts/provision.sh config.sh "$MNT/tmp/"
if [ -n "$CHROOT_PREFIX" ]; then
    chroot "$MNT" "$CHROOT_PREFIX" /bin/bash /tmp/provision.sh
else
    chroot "$MNT" /bin/bash /tmp/provision.sh
fi

echo ">> applying rootfs overlay"
if [ -d rootfs-overlay ]; then
    cp -a rootfs-overlay/. "$MNT/"
fi
ln -sf /lib/systemd/system/serial-getty@.service \
    "$MNT/etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service"
echo "/usr/local/lib" > "$MNT/etc/ld.so.conf.d/ubnt.conf"

echo ">> capturing build root password"
mv "$MNT/tmp/ROOT_PASSWORD.txt" "$OUT_DIR/ROOT_PASSWORD.txt"
chmod 600 "$OUT_DIR/ROOT_PASSWORD.txt"

echo ">> cleaning up rootfs"
rm -f "$MNT/usr/bin/qemu-aarch64-static" "$MNT"/tmp/{packages.list,provision.sh,config.sh}
rm -f "$MNT/etc/machine-id" "$MNT"/etc/ssh/ssh_host_*
rm -rf "$MNT/var/lib/apt/lists/"*
umount -R "$MNT"
losetup -d "$LOOP"
trap - EXIT

echo ">> compressing image"
xz -T0 -6 "$IMAGE"
( cd "$OUT_DIR" && sha256sum "${IMAGE##*/}.xz" > "${IMAGE##*/}.xz.sha256" )

echo ">> build complete:"
ls -la "$OUT_DIR"
