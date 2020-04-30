# Predictable Interface Names

An issue presented itself with Vintage Net where various things such
as loading firmware for wifi devices and kernel module load order
would cause network interfaces to come up in different orders. IE
given a usb wifi adapter and a built in wifi adapter, `wlan0` 
could non-deterministicly be assigned to either on boot. This is
particularly an issue when you need one interface to perform an action
that the other can't. For example 80211s meshing on raspberry pi.
(because the built in wifi adapter doesn't support meshing)

[the systemctl documentation](https://www.freedesktop.org/wiki/Software/systemd/PredictableNetworkInterfaceNames#Why)
describes the issue in more detail.

## udevadm output

These notes collected output from `udevadm` below from a few different devices including
* x86 "normal" desktop linux
* raspbain on raspberry pi4
* debian on beaglebone green wifi

### test-builtin

```bash
$ udevadm test-builtin net_id /sys/class/net/enp0s31f6/
Load module index
Parsed configuration file /usr/lib/systemd/network/99-default.link
Created link configuration context.
Using default interface naming scheme 'v245'.
ID_NET_NAMING_SCHEME=v245
ID_NET_NAME_MAC=enx1c1b0d0f918d
ID_OUI_FROM_DATABASE=GIGA-BYTE TECHNOLOGY CO.,LTD.
ID_NET_NAME_PATH=enp0s31f6
Unload module index
Unloaded link configuration context.
```

These values weren't actually that helpful, as udevadm doesn't actually
populate the `ID_NET_NAME_PATH` on beaglebone or raspberry pi systems.
[this stackoverflow question](https://stackoverflow.com/questions/19416919/how-can-i-enable-persistent-network-interface-naming-with-udev-on-arm-devices-ru)
has a few more details

```bash
debian@beaglebone:~$ udevadm test-builtin net_id /sys/class/net/wlan0
Load module index
Network interface NamePolicy= disabled on kernel command line, ignoring.
Parsed configuration file /lib/systemd/network/99-default.link
Created link configuration context.
Using default interface naming scheme 'v240'.
ID_NET_NAMING_SCHEME=v240
ID_NET_NAME_MAC=wlx1cbfce171d79
ID_OUI_FROM_DATABASE=Shenzhen Century Xinyang Technology Co., Ltd
Unload module index
Unloaded link configuration context.
```

```bash
debian@beaglebone:~$ udevadm test-builtin net_id /sys/class/net/wlan1
Load module index
Network interface NamePolicy= disabled on kernel command line, ignoring.
Parsed configuration file /lib/systemd/network/99-default.link
Created link configuration context.
Using default interface naming scheme 'v240'.
ID_NET_NAMING_SCHEME=v240
ID_NET_NAME_MAC=wlx884aea628a7c
ID_OUI_FROM_DATABASE=Texas Instruments
Unload module index
Unloaded link configuration context.
```

### udevadm info

This is a random usb wireless interface

```bash
debian@beaglebone:~$ udevadm info /sys/class/net/wlan0
P: /devices/platform/ocp/47400000.usb/47401c00.usb/musb-hdrc.1/usb1/1-1/1-1.1/1-1.1:1.0/net/wlan0
L: 0
E: DEVPATH=/devices/platform/ocp/47400000.usb/47401c00.usb/musb-hdrc.1/usb1/1-1/1-1.1/1-1.1:1.0/net/wlan0
E: DEVTYPE=wlan
E: INTERFACE=wlan0
E: IFINDEX=4
E: SUBSYSTEM=net
E: USEC_INITIALIZED=85000969
E: net.ifnames=0
E: ID_NET_NAMING_SCHEME=v240
E: ID_NET_NAME_MAC=wlx1cbfce171d79
E: ID_OUI_FROM_DATABASE=Shenzhen Century Xinyang Technology Co., Ltd
E: ID_VENDOR=Ralink
E: ID_VENDOR_ENC=Ralink
E: ID_VENDOR_ID=148f
E: ID_MODEL=802.11_n_WLAN
E: ID_MODEL_ENC=802.11\x20n\x20WLAN
E: ID_MODEL_ID=5370
E: ID_REVISION=0101
E: ID_SERIAL=Ralink_802.11_n_WLAN_1.0
E: ID_SERIAL_SHORT=1.0
E: ID_TYPE=generic
E: ID_BUS=usb
E: ID_USB_INTERFACES=:ffffff:
E: ID_USB_INTERFACE_NUM=00
E: ID_USB_DRIVER=rt2800usb
E: ID_VENDOR_FROM_DATABASE=Ralink Technology, Corp.
E: ID_MODEL_FROM_DATABASE=RT5370 Wireless Adapter
E: ID_PATH=platform-musb-hdrc.1-usb-0:1.1:1.0
E: ID_PATH_TAG=platform-musb-hdrc_1-usb-0_1_1_1_0
E: ID_NET_DRIVER=rt2800usb
E: ID_NET_LINK_FILE=/lib/systemd/network/99-default.link
E: SYSTEMD_ALIAS=/sys/subsystem/net/devices/wlan0
E: TAGS=:systemd:
```

This is the beaglebone green wifi's built in WiFi interface

```bash
debian@beaglebone:~$ udevadm info /sys/class/net/wlan1
P: /devices/platform/ocp/47810000.mmc/mmc_host/mmc2/mmc2:0001/mmc2:0001:2/wl18xx.1.auto/net/wlan1
L: 0
E: DEVPATH=/devices/platform/ocp/47810000.mmc/mmc_host/mmc2/mmc2:0001/mmc2:0001:2/wl18xx.1.auto/net/wlan1
E: DEVTYPE=wlan
E: INTERFACE=wlan1
E: IFINDEX=8
E: SUBSYSTEM=net
E: USEC_INITIALIZED=87963345
E: net.ifnames=0
E: ID_NET_NAMING_SCHEME=v240
E: ID_NET_NAME_MAC=wlx884aea628a7c
E: ID_OUI_FROM_DATABASE=Texas Instruments
E: ID_PATH=platform-47810000.mmc-platform-wl18xx.1.auto
E: ID_PATH_TAG=platform-47810000_mmc-platform-wl18xx_1_auto
E: ID_NET_DRIVER=wl18xx_driver
E: ID_NET_LINK_FILE=/lib/systemd/network/99-default.link
E: SYSTEMD_ALIAS=/sys/subsystem/net/devices/wlan1
E: TAGS=:systemd:
```

Found can0 in /sys/class/net/ and thought it was useful to
document.

```bash
debian@beaglebone:~$ udevadm info /sys/class/net/can0
P: /devices/platform/ocp/481cc000.can/net/can0
L: 0
E: DEVPATH=/devices/platform/ocp/481cc000.can/net/can0
E: INTERFACE=can0
E: IFINDEX=2
E: SUBSYSTEM=net
E: USEC_INITIALIZED=5395551
E: net.ifnames=0
E: ID_PATH=platform-481cc000.can
E: ID_PATH_TAG=platform-481cc000_can
E: ID_NET_DRIVER=c_can_platform
E: ID_NET_LINK_FILE=/lib/systemd/network/99-default.link
E: SYSTEMD_ALIAS=/sys/subsystem/net/devices/can0
E: TAGS=:systemd:
```

Raspberry pi 4's builtin wifi device name

```bash
pi@rpi4:~ $ udevadm info /sys/class/net/wlan0
P: /devices/platform/soc/fe300000.mmcnr/mmc_host/mmc1/mmc1:0001/mmc1:0001:1/net/wlan0
L: 0
E: DEVPATH=/devices/platform/soc/fe300000.mmcnr/mmc_host/mmc1/mmc1:0001/mmc1:0001:1/net/wlan0
E: DEVTYPE=wlan
E: INTERFACE=wlan0
E: IFINDEX=3
E: SUBSYSTEM=net
E: USEC_INITIALIZED=3786636
E: ID_NET_NAMING_SCHEME=v240
E: ID_NET_NAME_MAC=wlxdca63203cdba
E: ID_PATH=platform-fe300000.mmcnr
E: ID_PATH_TAG=platform-fe300000_mmcnr
E: ID_NET_DRIVER=brcmfmac
E: ID_NET_LINK_FILE=/lib/systemd/network/99-default.link
E: SYSTEMD_ALIAS=/sys/subsystem/net/devices/wlan0
E: TAGS=:systemd:
```

Raspberry Pi 4's built in ethernet interface

```bash
pi@rpi4:~ $ udevadm info /sys/class/net/eth0
P: /devices/platform/scb/fd580000.genet/net/eth0
L: 0
E: DEVPATH=/devices/platform/scb/fd580000.genet/net/eth0
E: INTERFACE=eth0
E: IFINDEX=2
E: SUBSYSTEM=net
E: USEC_INITIALIZED=3028720
E: ID_NET_NAMING_SCHEME=v240
E: ID_NET_NAME_MAC=enxdca63203cdb9
E: ID_PATH=platform-fd580000.genet
E: ID_PATH_TAG=platform-fd580000_genet
E: ID_NET_DRIVER=bcmgenet
E: ID_NET_LINK_FILE=/lib/systemd/network/99-default.link
E: SYSTEMD_ALIAS=/sys/subsystem/net/devices/eth0
E: TAGS=:systemd:
```

## systemctl/udev source links

* [get_sys_path](https://github.com/systemd/systemd/blob/484f4e5b2d62e885998fa3c09ed4d58b6c38f987/src/libsystemd/sd-device/sd-device.c#L670-L679)
* [sd_device_get_sysattr_value](https://github.com/systemd/systemd/blob/484f4e5b2d62e885998fa3c09ed4d58b6c38f987/src/libsystemd/sd-device/sd-device.c#L1732-L1805)
* [builtin_net_id](https://github.com/systemd/systemd/blob/484f4e5b2d62e885998fa3c09ed4d58b6c38f987/src/udev/udev-builtin-net_id.c#L774)
