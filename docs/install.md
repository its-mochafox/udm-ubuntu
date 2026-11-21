# Installing on a UDM-Pro

The image handles the **SSD side**. Two per-device setup steps are needed on the UDM-Pro itself (once per device): staging the device tree on the internal SD card, and teaching U-Boot to prefer the SSD when present.

The switch tools (`swconfig` and `libsw.so`) are extracted automatically from the stock firmware on the internal SD card during first boot. No manual step needed.

## What the boot chain looks like

```
SPI flash U-Boot
  └─ bootcmd (modified, saved via saveenv)
       ├─ /udmpro-v2.dtb on SD? ──► stock signed FIT kernel (from internal SD)
       │                            + /udmpro-v2.dtb + root=/dev/sda1 ──► Ubuntu
       └─ no DTB / load error ──► original stock chain ──► UnifiOS
```

The kernel is always Ubiquiti's own RSA-signed 4.19 FIT from the internal SD card. U-Boot on these devices has legacy image support disabled and enforces a required image-level signature, so custom kernels cannot be booted. The SSD is purely the root filesystem.

## 1. Flash the SSD

Write the image to a 2.5" SATA SSD:

```
xzcat udm-ubuntu-noble.img.xz > /dev/sdX    # whole-disk image: GPT included
```

Install the SSD in the UDM-Pro's bay. First boot automatically:
- Extracts `swconfig` + `libsw.so` from the stock firmware on the internal SD
- Configures the RTL8370B switch chip (all 8 LAN ports)
- Regenerates SSH host keys
- Grows the rootfs to fill the disk

## 2. Stage the device tree on the internal SD (run on stock UnifiOS)

The Ubuntu path needs `udmpro-v2.dtb` on the internal SD's boot1 partition (the same ext4 filesystem U-Boot already reads `/uImage` from). Run this on the **stock** UnifiOS console as root:

```bash
curl -fL -o /mnt/.stage/udmpro-v2.dtb <release URL>/udmpro-v2.dtb
mkdir -p /mnt/b1 && mount /dev/boot1 /mnt/b1
mv /mnt/.stage/udmpro-v2.dtb /mnt/b1/
sync && cd / && umount /mnt/b1
```

A clean unmount matters here: U-Boot's ext4 driver does not replay the journal.

## 3. Teach U-Boot to boot the SSD when present (serial console)

Attach a serial console to the UDM-Pro (115200 8N1, 3.3V, e.g. a Flipper Zero GPIO UART bridge). Interrupt autoboot with ESC ESC during the 2-second window, then at the `ALPINE_UBNT_UDM_ALL>` prompt:

```
setenv bootstock 'run load_fdt; run loadbootargs; run multiboot'
setenv bootubuntu 'ext4load usb 0 0x08000004 uImage; ext4load usb 0 0x3b16300 /udmpro-v2.dtb; setenv rootfs /dev/sda1; run loadbootargs; run bootunsign; run bootstock'
setenv bootcmd 'usb start; ext4load usb 0 0x08000004 /udmpro-v2.dtb; if test $? -eq 0; then run bootubuntu; fi; run bootstock'
saveenv
```

The `bootcmd` checks for `/udmpro-v2.dtb` on the internal SD card. If the file exists (you staged it in step 2), it boots Ubuntu. If it's absent or the load fails, it falls through to the stock chain:

- **SSD in + DTB staged**: Ubuntu
- **SSD removed**: kernel panics on missing root. Remove the DTB to fully restore stock.
- **DTB removed from SD**: stock UniFi OS regardless of SSD state

Power-cycle to test.

## Access

* Serial console: ttyS0, root / (password from build artifacts), or `ubuntu` / `ubuntu`
* SSH: enabled on any port with a lease
* The RJ45 WAN port carries a static link-local management address `169.254.200.99` for out-of-band provisioning
* All 8 LAN ports (`lan1` through `lan8`) are DHCP clients. Plug a cable into any port and it gets an address.

## Recovery

Nothing here is destructive to the stock system. The SD card's boot files are untouched apart from one added `.dtb`, and the U-Boot env changes are reversible with `env default -a; saveenv` at the U-Boot prompt. Remove the `.dtb` from the SD card and/or pull the SSD to return the device to stock UniFi OS.
