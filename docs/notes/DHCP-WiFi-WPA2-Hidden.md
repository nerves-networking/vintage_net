# WiFi w/ WPA2 to hidden AP using DHCP

This is standard authenticated WiFi, but to an AP that doesn't broadcast its SSID.

## Required programs

* Busybox ifup/ifdown
* Busybox ip
* Busybox udhcpc
* wpa_supplicant

## Config files

`/etc/network/interfaces`:

```config
iface wlan0 inet dhcp
    pre-up wpa_supplicant -B -Dwext -iwlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf
    post-down killall -q wpa_supplicant
```

`/etc/wpa_supplicant.conf`:

```config
country=US
network={
ssid="TestSSID"
psk="supersecret"
key_mgmt=WPA-PSK
scan_ssid=1
}
```

## Tested

No
