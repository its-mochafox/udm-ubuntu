#!/bin/bash
# Configure the RTL8370B switch chip for the UDM-Pro's 8 LAN ports.
# Called by switch-init.service before systemd-networkd starts.
# Requires swconfig (from stock firmware) at /usr/local/bin/swconfig
set -e

modprobe ubnthal 2>/dev/null || true

ip link set eth3 down 2>/dev/null || true
ip link set eth3 name switch0 2>/dev/null || true
ip link set switch0 up

# CPU port is 9 (the swconfig help incorrectly says 8)
swconfig dev switch0 vlan 1 set ports "0 1 2 3 4 5 6 7 9t"

# SVLAN mapping: port N gets SVLAN (4094-N), descending
for port in 0 1 2 3 4 5 6 7; do
    sv=$((4094 - port))
    swconfig dev switch0 svlan $sv set ports "${port} 9t"
done

for p in 0 1 2 3 4 5 6 7 9; do
    swconfig dev switch0 port $p set enable_vlan 1
    swconfig dev switch0 port $p set pvid 1
done
swconfig dev switch0 set apply

ip link set switch0 promisc on

for i in 1 2 3 4 5 6 7 8; do
    sv=$((4095 - i))
    ip link add link switch0 name lan$i type vlan id $sv protocol 802.1ad 2>/dev/null || true
    ip link set lan$i up
done

ip addr add 169.254.200.99/16 dev eth1 2>/dev/null || true
ip link set eth1 up

echo "switch-init: all 8 LAN ports configured"
