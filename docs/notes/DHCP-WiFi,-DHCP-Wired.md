# Dual wired and wireless connections

DHCP on both wireless and wired interfaces, useful for a mobile device that could either be plugged in at home or using WiFi on the go

## Required programs

* Busybox ifup/ifdown
* Busybox ip
* Busybox udhcpc
* wpa_supplicant

## Config files

`/etc/network/interfaces`:

```config
auto eth0
iface eth0 inet dhcp

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
Nerves.Runtime.cmd("ifup", ["-a"], :info)
[ Couldn't capture eth0 logs, but it came up ]
[ TONS OF WPA LOGS ]
00:00:55.324 [info]  Daemonize..

00:00:55.324 [info]  
 
00:00:55.343 [info]  udhcpc: started, v1.27.2
 
00:00:55.343 [info]  
 
00:00:55.410 [info]  udhcpc: sending discover
 
00:00:55.410 [info]  
 
00:00:58.513 [info]  udhcpc: sending discover
 
00:00:58.513 [info]  
 
00:01:01.593 [info]  udhcpc: sending discover
 
00:01:01.593 [info]  
 
00:01:01.670 [info]  udhcpc: sending select for 192.168.86.129
 
00:01:01.670 [info]  
 
00:01:01.750 [info]  udhcpc: lease of 192.168.86.129 obtained, lease time 86400
 
00:01:01.750 [info]  
 
00:01:01.761 [info]  deleting routers
 
00:01:01.761 [info]  
 
00:01:01.786 [info]  adding dns 192.168.86.1

```

## Questions

1. What happens when both are connected? Which one gets priority?
