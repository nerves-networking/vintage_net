# Dual Wired Ethernet using DHCP

This is the typical wired Ethernet setup.

## Required programs

* Busybox ifup/ifdown
* Busybox ip
* Busybox udhcpc

## Config files

`/etc/network/interfaces`:

```config
auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet dhcp
```

`/etc/wpa_supplicant.conf`:

N/A

## Tested

No
