# udm-ubuntu

Boot genuine Ubuntu Server on a Ubiquiti UDM-Pro from a SATA SSD.

## How it works

The UDM-Pro's U-Boot only accepts kernels signed with Ubiquiti's RSA key. This project doesn't replace the kernel. The device boots its **own signed 4.19 kernel** with modified boot arguments (`root=/dev/sda1`) pointing at an Ubuntu rootfs on the SATA SSD.

## Build

```bash
sudo apt install parted e2fsprogs xz-utils curl qemu-user-static
sudo ./build.sh
```

## License

Provided as-is.
