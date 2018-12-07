# Basic AP Mode configuration


## Required Programs

1. Busybox ip
1. hostapd
1. dnsmasq


## Configs

`/etc/dnsmasq.conf`:

```
interface=wlan0      # Use interface wlan0
listen-address=192.168.50.1 # Explicitly specify the address to listen on, this should be the configured static ip in /etc/network/interfaces file
bind-interfaces      # Bind to the interface to make sure we aren't sending things elsewhere
server=8.8.8.8       # Forward DNS requests to Google DNS
domain-needed        # Don't forward short names
bogus-priv           # Never forward addresses in the non-routed address spaces.
dhcp-range=192.168.50.1,192.168.50.150,12h # assign IP addresses in that range, and give a 12 hour lease time
```

`/etc/hostapd/hostapd.conf`:


```
interface=wlan0

driver=nl80211

ssid=Pi3-AP

hw_mode=g

channel=6

ieee80211n=1

wmm_enabled=1

ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]

macaddr_acl=0

auth_algs=1

ignore_broadcast_ssid=0

wpa=2

wpa_key_mgmt=WPA-PSK

wpa_passphrase=raspberry

rsn_pairwise=CCMP
```


`/etc/network/interfaces`:


```
allow-hotplug wlan0
iface wlan0 inet static
  address 192.168.50.1
  netmask 255.255.255.0
  network 192.168.50.0
  broadcast 192.168.50.255
```


## Guide

Since, in our example we are not using `pre-up`/`post-up` scripts we are going to
work through setting this up manually. However, kept in mind there are ways
to make bringing up the AP more automated.

### Clean start

To be sure the system network is in a good state run:

```
$ /etc/init.d/S41dhcpd restart
$ ip link set wlan0 down
```

This should help clean up any extra network configs that will get in the way. Again,
I think there better ways that scripts and init systems could help, but this is good for
active testing.

### Bringing Things Up

Next, bring the `wlan0` interface again, and this should load the config from
`/etc/network/interfaces`.

Then start the `dnsmasq` service like so:

```
/etc/init.d/S80dnsmasq start
```

If all that works then run:

```
hostapd /etc/hostapd/hostapd.conf
```

This won't run in the background so you can see the log directly. You should
see `wlan0: AP-ENABLED`, and then the name of the AP network will appear in your
wireless networks. You can connect to that AP and see the connection
log. After connecting, from your host test by running `ping` on the
the configured IP address.

A lot of the manual stuff can be automated, configured, or scripted away.



## Output Examples

Tested by Matt Ludwigs on [rpi3_nettest](https://github.com/fhunleth/fhunleth-buildroot-experiments)

Running `hostpad`

```
# hostapd /etc/hostapd/hostapd.conf
Configuration file: /etc/hostapd/hostapd.conf
Failed to create interface mon.wlan0: -95 (Operation not supported)
wlan0: Could not connect to kernel driver
Using interface wlan0 with hwaddr b8:27:eb:13:a3:06 and ssid "Pi3-AP"
[ 5833.256928] IPv6: ADDRCONF(NETDEV_CHANGE): wlan0: link becomes ready
wlan0: interface state UNINITIALIZED->ENABLED
wlan0: AP-ENABLED
```


Connecting to the AP:

```
wlan0: STA 9c:b6:d0:0c:e3:8d IEEE 802.11: associated
wlan0: AP-STA-CONNECTED 9c:b6:d0:0c:e3:8d
wlan0: STA 9c:b6:d0:0c:e3:8d WPA: pairwise key handshake completed (RSN)
```

Ping the static IP:


```
λ  ~/code/nerves_network_ng (ap-mode-updates)  $ ping 192.168.50.1
PING 192.168.50.1 (192.168.50.1) 56(84) bytes of data.
64 bytes from 192.168.50.1: icmp_seq=1 ttl=64 time=103 ms
64 bytes from 192.168.50.1: icmp_seq=2 ttl=64 time=8.47 ms
64 bytes from 192.168.50.1: icmp_seq=3 ttl=64 time=24.0 ms
64 bytes from 192.168.50.1: icmp_seq=4 ttl=64 time=9.03 ms
64 bytes from 192.168.50.1: icmp_seq=5 ttl=64 time=90.6 ms
64 bytes from 192.168.50.1: icmp_seq=6 ttl=64 time=5.82 ms
64 bytes from 192.168.50.1: icmp_seq=7 ttl=64 time=9.07 ms
^C
--- 192.168.50.1 ping statistics ---
7 packets transmitted, 7 received, 0% packet loss, time 6009ms
```


