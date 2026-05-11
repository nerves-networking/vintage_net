<!--
SPDX-FileCopyrightText: None
SPDX-License-Identifier: CC0-1.0
-->

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
key_mgmt=NONE
wep_tx_keyidx=0
wep_key0=42FEEDDEAFBABEDEAFBEEFAA55
}
```

Tested:
No