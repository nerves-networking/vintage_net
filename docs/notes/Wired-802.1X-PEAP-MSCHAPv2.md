`/etc/network/interfaces`:

```config
auto eth0
iface eth0 inet dhcp
    wpa-driver wired
    wpa-conf /etc/wpa_supplicant.conf
```

`/etc/wpa_supplicant.conf`:

```config
network={
    key_mgmt=IEEE8021X
    pairwise=CCMP
    identity="USERNAME"
    password="PASSWORD"
    ca_cert="/usr/share/ca-certificates/my-root-ca/my-root.crt"
    eap=PEAP
    eapol_flags=0
    phase2="auth=MSCHAPV2"
}
```

Tested:
jmerriweather on Raspbian
