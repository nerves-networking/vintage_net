# WiFi w/ WPA2 using DHCP

This is standard authenticated WiFi.

## Required programs

* Busybox ifup/ifdown
* Busybox ip
* Busybox udhcpc
* wpa_supplicant

## Config files

`/etc/network/interfaces`:

```config
iface wlan0 inet dhcp
    pre-up wpa_supplicant -B w -i wlan0 -c /etc/wpa_supplicant.conf -dd
    post-down killall -q wpa_supplicant
```

`/etc/wpa_supplicant.conf`:

```
ctrl_interface=/var/run/wpa_supplicant
ap_scan=1

network={
ssid="FarmBotHQ"
scan_ssid=1
proto=WPA RSN
key_mgmt=WPA-PSK
pairwise=CCMP TKIP
group=CCMP TKIP
psk="SUPER SECRET"
}

```

## Tested

ConnorRigby Nerves/Buildroot: 

```elixir
Nerves.Runtime.cmd("ifup", ["wlan0"], :info)
[ TONS OF WPA OUTPUT ]
00:00:19.900 [info]  Daemonize..

00:00:19.900 [info]  
 
00:00:19.921 [info]  udhcpc: started, v1.27.2
 
00:00:19.921 [info]  
 
00:00:20.010 [info]  udhcpc: sending discover
 
00:00:20.010 [info]  
 
00:00:23.103 [info]  udhcpc: sending discover
 
00:00:23.103 [info]  
 
00:00:26.183 [info]  udhcpc: sending discover
 
00:00:26.183 [info]  
 
00:00:29.242 [info]  udhcpc: sending select for 192.168.86.129
 
00:00:29.242 [info]  
 
00:00:29.320 [info]  udhcpc: lease of 192.168.86.129 obtained, lease time 86400
 
00:00:29.320 [info]  
 
00:00:29.331 [info]  deleting routers
 
00:00:29.331 [info]  
 
00:00:29.356 [info]  adding dns 192.168.86.1
 
00:00:29.356 [info]  
{%Nerves.Runtime.OutputLogger{level: :info}, 0}
 
```