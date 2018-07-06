# WiFi AP w/ a static IP address and DHCP server

Set up a wireless access point, and serve dhcp addresses on it. Helpful for serving a single webpage for configuration utilities etc.

## Required programs

* Busybox ifup/ifdown
* Busybox ip
* Busybox udhcpd
* wpa_supplicant

## Config files

`/etc/network/interfaces`:
```
auto wlan0
iface wlan0 inet static
    address 10.0.0.1
    netmask 255.255.255.0
    network 10.0.0.0
    broadcast 10.0.0.255
    gateway 10.0.0.1
    dns-nameservers 10.0.0.1 1.1.1.1
    dns-domain acme.com
    dns-search acme.com
    pre-up wpa_supplicant -B w -i wlan0 -c /etc/wpa_supplicant.conf -dd; udhcpd /etc/udhcpcd.conf
    post-down killall -q wpa_supplicant; killall -q udhcpcd
```

`/etc/wpa_supplicant.conf`:
```
ctrl_interface=/var/run/wpa_supplicant
ap_scan=1

country=US
network={
ssid="TestSSID"
mode=2
psk="supersecret"
key_mgmt=WPA-PSK
}
```

`/etc/udhcpd.conf`:

```
start 		10.0.0.2
end		10.0.0.20
interface	wlan0
```

## Tested

ConnorRigby Nerves/Buildroot:

```elixir
iex()> Nerves.Runtime.cmd("ifup", ["wlan0"], :info)
```
