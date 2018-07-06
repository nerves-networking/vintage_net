This is an advanced config that I don't know if we can/want to support by default. It has some extra dependencies to work properly.

# /etc/network/interfaces
```config
iface uap0 inet static
    address 10.3.141.1
    netmask 255.255.255.0
    up iw phy phy0 interface add uap0 type __ap
    post-up hostapd -dd -B -i uap0 -P /var/run/hostapd.uap0.pid /etc/hostapd.uap0.conf
    post-down kill $(cat /var/run/hostapd.uap0.pid)
    down iw dev uap0 del
```

# /etc/wpa_supplicant.wlan0.conf
```config
# standard client config
```

# /etc/hostapd.uap0.conf
```config
interface=uap0
ssid=_AP_SSID_
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=_AP_PASSWORD_
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
```

# /etc/dnsmasq.uap0.conf
```config
# standard dhcp + captive portal stuff on iface uap0
```