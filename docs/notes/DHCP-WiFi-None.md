# WiFi w/ no security using DHCP

This is standard unauthenticated WiFi. It would be nice if we somehow supported clicking through captive portals somehow, but that's beyond the scope of this unless someone knows of an easy way.

## Required programs

* Busybox ifup/ifdown
* Busybox ip
* Busybox udhcpc
* wpa_supplicant

## Config files

`/etc/network/interfaces`:

```config
auto wlan0
iface wlan0 inet dhcp
    pre-up wpa_supplicant -B w -i wlan0 -c /etc/wpa_supplicant.conf -dd
    post-down killall -q wpa_supplicant
```

`/etc/wpa_supplicant.conf`:

```config
ctrl_interface=/var/run/wpa_supplicant
ap_scan=1

network={
ssid="AndroidAP"
scan_ssid=1
key_mgmt=NONE
}

```

## Tested

ConnorRigby Nerves/Buildroot:

```elixir
iex(6)> Nerves.Runtime.cmd("ifup", ["wlan0"], :info)
00:00:25.002 [info]  Daemonize..
 
00:00:25.002 [info]  
 
00:00:25.019 [info]  udhcpc: started, v1.27.2
 
00:00:25.019 [info]  
 
00:00:25.130 [info]  udhcpc: sending discover
 
00:00:25.130 [info]  
 
00:00:28.213 [info]  udhcpc: sending discover
 
00:00:28.213 [info]  
 
00:00:31.286 [info]  udhcpc: sending select for 192.168.43.95
 
00:00:31.286 [info]  
 
00:00:31.370 [info]  udhcpc: lease of 192.168.43.95 obtained, lease time 3600
 
00:00:31.370 [info]  
 
00:00:31.381 [info]  deleting routers
 
00:00:31.381 [info]  
 
00:00:31.405 [info]  adding dns 192.168.43.1
 
00:00:31.405 [info]  
{%Nerves.Runtime.OutputLogger{level: :info}, 0}
```