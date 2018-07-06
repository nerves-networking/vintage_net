# Wired Ethernet using static IP

This is wired Ethernet, but with static IP addresses.

## Required programs

* Busybox ifup/ifdown
* Busybox ip

## Config files

`/etc/network/interfaces`:

```config
auto eth0
iface eth0 inet static
    address 192.168.86.127
    netmask 255.255.255.0
    network 192.168.86.0
    broadcast 192.168.86.255
    gateway 192.168.86.1
    dns-nameservers 192.168.86.1 8.8.8.8
```

`/etc/wpa_supplicant.conf`:

N/A

## Tested

ConnorRigby: Nerves/Buildroot
```elixir
iex(9)> Nerves.Runtime.cmd("ifup", ["eth0"], :info)
{%Nerves.Runtime.OutputLogger{level: :info}, 0}
iex(10)> Nerves.Runtime.cmd("ifconfig", [], :info)

00:00:51.643 [info]  eth0      Link encap:Ethernet  HWaddr B8:27:EB:84:7E:D3  
 
00:00:51.643 [info]            inet addr:192.168.86.127  Bcast:192.168.86.255  Mask:255.255.255.0

00:00:51.643 [info]            UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1

00:00:51.643 [info]            RX packets:0 errors:0 dropped:0 overruns:0 frame:0

00:00:51.643 [info]            TX packets:0 errors:0 dropped:0 overruns:0 carrier:0

00:00:51.643 [info]            collisions:0 txqueuelen:1000 

00:00:51.643 [info]            RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)

00:00:51.643 [info]  

00:00:51.643 [info]  lo        Link encap:Local Loopback  

00:00:51.643 [info]            inet addr:127.0.0.1  Mask:255.0.0.0

00:00:51.643 [info]            UP LOOPBACK RUNNING  MTU:65536  Metric:1

00:00:51.643 [info]            RX packets:4 errors:0 dropped:0 overruns:0 frame:0

00:00:51.643 [info]            TX packets:4 errors:0 dropped:0 overruns:0 carrier:0

00:00:51.643 [info]            collisions:0 txqueuelen:1 

00:00:51.643 [info]            RX bytes:284 (284.0 B)  TX bytes:284 (284.0 B)

00:00:51.643 [info]  

00:00:51.643 [info]  
{%Nerves.Runtime.OutputLogger{level: :info}, 0}
iex(11)> 
nil
iex(12)>
```
