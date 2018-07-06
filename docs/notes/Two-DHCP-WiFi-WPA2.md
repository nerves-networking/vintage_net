`/etc/network/interfaces`:

```config
iface wlan0 inet dhcp
    pre-up wpa_supplicant -B -Dwext -iwlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf
    post-down killall -q wpa_supplicant
```

`/etc/wpa_supplicant.conf`:
```
country=US
network={
ssid="TestSSID"
psk="supersecret"
key_mgmt=WPA-PSK
priority=1
id_str="test-lower-priority"
}
network={
ssid="TestSSID2"
psk="supersecret2"
key_mgmt=WPA-PSK
priority=2
id_str="test-higher-priority"
}
```

Tested:
No