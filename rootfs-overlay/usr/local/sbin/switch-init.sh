#!/bin/bash
# switch-init.sh - configure the RTL8370B switch chip for the UDM-Pro's 8 LAN ports.
# Called by switch-init.service before systemd-networkd starts.
#
# If swconfig is not installed (first boot), it is extracted from the stock
# firmware on the internal SD card. The internal SD is always present -
# the kernel boots from it.
set -e

# --- Extract switch tools from stock firmware if needed ---
if [ ! -x /usr/local/bin/swconfig ]; then
    echo "switch-init: extracting swconfig from stock firmware..."
    modprobe loop 2>/dev/null || true
    mkdir -p /mnt/stockfw /mnt/stock

    # Mount the firmware partition (contains the squashfs rootfs image)
    mount /dev/boot3 /mnt/stockfw 2>/dev/null || true
    mount -t squashfs -o ro,loop /mnt/stockfw/rootfs /mnt/stock 2>/dev/null || true

    if [ -f /mnt/stock/usr/sbin/swconfig ]; then
        cp /mnt/stock/usr/sbin/swconfig /usr/local/bin/
        cp /mnt/stock/usr/lib/libsw.so /usr/local/lib/
        chmod +x /usr/local/bin/swconfig
        echo "switch-init: swconfig + libsw.so extracted"
    else
        echo "switch-init: WARNING: stock firmware not found, switch ports will not work"
        echo "switch-init: (the internal SD card must be present for extraction)"
        umount /mnt/stock /mnt/stockfw 2>/dev/null || true
        exit 1
    fi

    umount /mnt/stock /mnt/stockfw 2>/dev/null || true
    ldconfig 2>/dev/null || true
fi

# --- Configure the switch chip ---

modprobe ubnthal 2>/dev/null || true

# Rename eth3 (the SoC's switch-facing port) to switch0
ip link set eth3 down 2>/dev/null || true
ip link set eth3 name switch0 2>/dev/null || true
ip link set switch0 up

# CPU port is 9 (the swconfig help incorrectly says 8)
swconfig dev switch0 vlan 1 set ports "0 1 2 3 4 5 6 7 9t"

# SVLAN mapping: port N gets SVLAN (4094-N), descending
# Port 0 = SVLAN 4094, Port 1 = SVLAN 4093, ... Port 7 = SVLAN 4087
for port in 0 1 2 3 4 5 6 7; do
    sv=$((4094 - port))
    swconfig dev switch0 svlan $sv set ports "${port} 9t"
done

# Enable VLAN mode and set PVID on all ports
for p in 0 1 2 3 4 5 6 7 9; do
    swconfig dev switch0 port $p set enable_vlan 1
    swconfig dev switch0 port $p set pvid 1
done
swconfig dev switch0 set apply

# Set promiscuous mode on the CPU-facing interface
ip link set switch0 promisc on

# Create 802.1ad SVLAN subinterfaces for each LAN port
# lan1 = SVLAN 4094 (port 0), lan2 = SVLAN 4093 (port 1), etc.
for i in 1 2 3 4 5 6 7 8; do
    sv=$((4095 - i))
    ip link add link switch0 name lan$i type vlan id $sv protocol 802.1ad 2>/dev/null || true
    ip link set lan$i up
done

# Static management on eth1 (WAN RJ45, out-of-band)
ip addr add 169.254.200.99/16 dev eth1 2>/dev/null || true
ip link set eth1 up

echo "switch-init: all 8 LAN ports configured"
