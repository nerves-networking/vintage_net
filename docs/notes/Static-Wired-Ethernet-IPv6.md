`/etc/network/interfaces`:

```config
auto eth0
iface eth0 inet6 static
     address 2001:db8::c0ca:1eaf
     netmask 64
     gateway 2001:db8::1ead:ed:beef
```

`/etc/wpa_supplicant.conf`:

N/A

Tested:
ConnorRigby Nerves/Buildroot

```
iex(4)> Nerves.Runtime.cmd("ifup", ["eth0"], :info)

00:00:57.453 [info]  ip: RTNETLINK answers: Operation not supported
 
00:00:57.453 [info]  
 
00:00:57.713 [info]  ip: RTNETLINK answers: Operation not supported
 
00:00:57.713 [info]  
{%Nerves.Runtime.OutputLogger{level: :info}, 1}
iex(5)> Nerves.Runtime.cmd("modprobe", ["ipv6"], :info)
[ 9261.336194] NET: Registered protocol family 10

02:34:21.331 [info]  [ 9261.336194] NET: Registered protocol family 10
{%Nerves.Runtime.OutputLogger{level: :info}, 0}
iex(6)> Nerves.Runtime.cmd("ifup", ["eth0"], :info)    
{%Nerves.Runtime.OutputLogger{level: :info}, 0}
iex(7)> Nerves.Runtime.cmd("ifconfig", ["eth0"], :info) 

02:35:47.582 [info]  eth0      Link encap:Ethernet  HWaddr B8:27:EB:84:7E:D3  
 
02:35:47.582 [info]            inet6 addr: fe80::ba27:ebff:fe84:7ed3/64 Scope:Link

02:35:47.582 [info]            inet6 addr: 2001:db8::c0ca:1eaf/64 Scope:Global

02:35:47.582 [info]            UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1

02:35:47.582 [info]            RX packets:275 errors:0 dropped:0 overruns:0 frame:0

02:35:47.582 [info]            TX packets:13 errors:0 dropped:0 overruns:0 carrier:0

02:35:47.582 [info]            collisions:0 txqueuelen:1000 

02:35:47.583 [info]            RX bytes:18146 (17.7 KiB)  TX bytes:1086 (1.0 KiB)

02:35:47.583 [info]  

02:35:47.583 [info]  
{%Nerves.Runtime.OutputLogger{level: :info}, 0}
iex(8)> 

```
