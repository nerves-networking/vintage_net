# WiFi Read Only File System Setup

Nerves systems are read-only file systems. However, in order to manage
network configurations dynamically, we will need to provide a way to write
configuration files for Linux network tooling to use.  The goal of this
document is to explain how we can accomplish within the context of WiFi
to provide dynamic networking configurations on a Nerves system.

## System commands

We will be using Linux network tooling to accomplish network configurations.
The system will assume these programs are available:

1. `ip`
1. `udhcpc` and `dhcpcd`
1. `wpa_supplicant`
1. `ping`

Also, ensure that `dhcpcd` is running.

Also, we will want to create a working networking directory for our configurations.
For this, we will use `/tmp/nerves-network`.

## Clean Start

If you are doing development or testing you might want to ensure
that your system is in a clean networking state first. That is
to say, all networking state is in a non-working state so that
we can simulate bring up the WiFi interface in this manner.

Run:

```
ip link set wlan0 down
ip link set eth0 down
```

If you run

```
ip link ls up
```

There should be no output. If there is an interface, you set it to
down as we did for the other interfaces. If you run `ping google.com`
you should get any network traffic

## Example

At this point, our system should be in a state to write a configuration,
start everything up and be connected to WiFi.

First,  we will want to make a wpa configuration file.  A basic `wap_supplicant.conf`
file will have this structure:

```
ctrl_interface=/var/run/wpa_supplicant
network={
        ssid="My SSID"
        psk="My PSK"
}
```

There are more advanced configurations, but a simple one will do for our example for now.

Those file contents, with your SSID and PSK, should be written
to `/tmp/nerves-network/wpa_supplicant.conf`. At this point, there
are three steps we need to do to in order to get WiFi working.

### Start `wpa_supplicant`

We are going to start `wpa_supplicant` and have it run as a daemon.

```
wpa_supplicant -B -i wlan0 -c /tmp/nerves-network/wpa_supplicant.conf -d
```

### Bring the interface up

Next, we want to use `ip` to bring the `wlan0` interface up.

```
ip link set wlan0 up
```

### Get IP adress from DHCP server

Then we have to request an IP address from the DHCP server like so:

```
udhcp -i wlan0

udhcpc: started, v1.29.2
udhcpc: sending discover
udhcpc: sending select for 192.168.0.18
udhcpc: lease of 192.168.0.18 obtained, lease time 3600
deleting routers
adding dns 68.105.28.11
adding dns 68.105.29.11
adding dns 68.105.28.12
```

Your addresses will be different but the important piece of information
is that the lease was obtained. From here you can do a few things
to check on your work. The quickest test is to `ping google.com`.
That should work at this point.

Also, you can run some `ip addr show wlan0` and you will see the
assigned IP address in the output:

```
# ip addr show wlan0
2: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast qlen 1000
    link/ether b8:27:eb:13:a3:06 brd ff:ff:ff:ff:ff:ff
    inet 192.168.0.18/24 brd 192.168.0.255 scope global wlan0
       valid_lft forever preferred_lft forever
    inet6 2600:8800:8d05:2b00::2/128 scope global dynamic
       valid_lft 3363sec preferred_lft 1563sec
    inet6 2600:8800:8d05:2b00:356f:15e7:b53f:dc1a/64 scope global dynamic
       valid_lft 86395sec preferred_lft 86395sec
    inet6 fe80::d336:bde7:28fa:49a3/64 scope link
       valid_lft forever preferred_lft forever

```
