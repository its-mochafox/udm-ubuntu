# udm-ubuntu

Boot genuine Ubuntu Server on a Ubiquiti UDM-Pro from a SATA SSD, with automatic fallback to stock UniFi OS when the SSD is removed.

## How it works

The UDM-Pro's U-Boot only accepts kernels signed with Ubiquiti's RSA key (legacy image support is compiled out; unsigned FITs are rejected by a required image-level signature). So this project doesn't replace the kernel: the device boots its **own signed 4.19 kernel** with modified boot arguments (`root=/dev/sda1`) pointing at an Ubuntu rootfs on the SATA SSD. The result is genuine Ubuntu userland (noble, arm64) on Ubiquiti's hardware.

The build:

1. Fetches the official `ubuntu-base` arm64 rootfs
2. Installs `ubuntu-minimal` + `ubuntu-standard` + OpenSSH + tools
3. Creates `root` with a **random build-time password** (in build artifacts) and the standard `ubuntu` / `ubuntu` sudo user
4. Configures the internal RTL8370B switch chip so all **8 LAN ports work** out of the box
5. Sets up networkd: DHCP on LAN ports, link-local management on the WAN RJ45
6. On first boot: regenerates SSH host keys and grows the rootfs to fill the disk

## The 8 LAN ports

The UDM-Pro's 8 RJ45 LAN ports sit behind a Realtek RTL8370B switch chip. They work via:

- The switch chip's CPU port is **9** (the swconfig help text incorrectly says 8)
- Each port N (0-7) maps to **SVLAN 4094-N** (descending), tagged to the CPU port
- On the Linux side, each port appears as an **802.1ad subinterface** on `switch0` (the renamed eth3)
- `switch-init.service` runs before `systemd-networkd` to configure the chip and create interfaces

This requires two Ubiquiti binaries (`swconfig` and `libsw.so`) that are not in this repository. They are **extracted automatically from your device's stock firmware** on the internal SD card during first boot. No manual step needed, and nothing proprietary is shipped in this repo.

## Quick start

### Build (any Linux host or CI)

```bash
sudo apt install parted e2fsprogs xz-utils curl qemu-user-static
sudo ./build.sh
```

Or push a `v*` tag and the GitHub Action builds on a native arm64 runner.

### Install on a UDM-Pro

1. Flash the image to a 2.5" SATA SSD (`xzcat udm-ubuntu.img.xz > /dev/sdX`)
2. Install the SSD in the UDM-Pro's bay
3. Follow [docs/install.md](docs/install.md) for the two per-device setup steps (staging the device tree + configuring U-Boot)

## What you get

```
OS:       Ubuntu 24.04 LTS (noble) aarch64
Kernel:   4.19.152-ui-alpine (Ubiquiti's signed kernel)
Ports:    8x RJ45 LAN (RTL8370B switch, gigabit)
           1x RJ45 WAN (eth1, also used for management)
           2x SFP+ WAN (eth9/eth10)
LAN:      DHCP on all ports, 802.1ad SVLAN per port
SSH:      enabled, root + ubuntu users
Fallback: remove the SSD to boot stock UniFi OS
```

## Repository layout

```
build.sh                          build orchestrator (Linux/CI)
config.sh                         build settings (suite, size, users)
packages.list                     apt packages installed into the image
scripts/provision.sh              runs inside the image chroot
rootfs-overlay/                   copied verbatim onto the image
  usr/local/sbin/switch-init.sh   RTL8370B switch chip configuration
  usr/local/sbin/udm-firstboot.sh first-boot init (SSH keys, rootfs grow)
  etc/systemd/system/             switch-init + firstboot services
  etc/systemd/network/            networkd configs (LAN, mgmt, WAN)
  etc/fstab                       root mount
docs/install.md                   per-device install guide
.github/workflows/build.yml       CI: build + release on tags
```

## Security

- `ROOT_PASSWORD.txt` is generated at build time and stored in build artifacts. It is never committed to the repository.
- The `ubuntu`/`ubuntu` account uses cloud-image convention with passwordless sudo.
- SSH host keys are generated on first boot, never baked into the image.
- Change all passwords before putting this on a real network.

## License

The build scripts and configuration in this repository are provided as-is. The Ubuntu packages are covered by their respective licenses. The `swconfig` and `libsw.so` binaries (which you extract separately) are Ubiquiti proprietary software. Do not redistribute them.
