# Wired Ethernet using DHCP

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
```

`/etc/wpa_supplicant.conf`:

N/A

Tested: ConnorRigby on Nerves/Buildroot

```elixir
iex(1)> Nerves.Runtime.cmd("ifup", ["eth0"], :info)

00:00:30.469 [info]  udhcpc: started, v1.27.2

00:00:30.469 [info]

00:00:30.570 [info]  udhcpc: sending discover

00:00:30.570 [info]

00:00:33.653 [info]  udhcpc: sending discover

00:00:33.653 [info]

00:00:33.740 [info]  udhcpc: sending select for 192.168.86.127

00:00:33.740 [info]

00:00:33.830 [info]  udhcpc: lease of 192.168.86.127 obtained, lease time 86400

00:00:33.830 [info]

00:00:33.840 [info]  deleting routers

00:00:33.840 [info]

00:00:33.878 [info]  adding dns 192.168.86.1

00:00:33.878 [info]
{%Nerves.Runtime.OutputLogger{level: :info}, 0}
```

## Getting events back to Elixir

### Events

*
