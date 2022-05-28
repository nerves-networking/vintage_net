# LTE

Test using Huawei LTE USB modem with Twilio

## Required Programs

1. Busybox ip
1. ppp
1. usb-modeswitch
1. pon

## Required Hardware

1. Huawei USB LTE modem

## Configs

The configs can be found at [Twilio's Github repo](https://github.com/twilio/wireless-ppp-scripts)

`/etc/chatscripts/twilio`:

```
# See http://consumer.huawei.com/solutions/m2m-solutions/en/products/support/application-guides/detail/mu509-65-en.htm?id=82047

# Exit executition if module receives any of the following strings:
ABORT 'BUSY'
ABORT 'NO CARRIER'
ABORT 'NO DIALTONE'
ABORT 'NO DIAL TONE'
ABORT 'NO ANSWER'
ABORT 'DELAYED'
TIMEOUT 10
REPORT CONNECT

# Module will send the string AT regardless of the string it receives
"" AT

# Instructs the modem to disconnect from the line, terminating any call in progress. All of the functions of the command shall be completed before the modem returns a result code.
OK ATH

# Instructs the modem to set all parameters to the factory defaults.
OK ATZ

# Result codes are sent to the Data Terminal Equipment (DTE).
OK ATQ0

# Define PDP context
OK AT+CGDCONT=1,"IP","wireless.twilio.com"

# ATDT = Attention Dial Tone
OK ATDT*99***1#

# Don't send any more strings when it receives the string CONNECT. Module considers the data links as having been set up.
CONNECT ''

```

`/etc/ppp/peers/twilio`:

```
# The options script can specify the device used for the PPP dial-up connection, string transmission speed, hardware acceleration, overflow, and more

connect "/usr/sbin/chat -v -f /etc/chatscripts/twilio"

# Where is modem connect?
# Device needs to be in modem mode
# Locate gsm modem with "dmesg | grep gsm"
/dev/ttyUSB0

# Specify the baud rate (bit/s) used in the PPP dial-up connection. For
# Huawei modules, it is recommended that you set this parameter to 115200
115200

# Disables the default behaviour when no local IP address is specified, which is to determine (if possible) the local IP address from the hostname. With this option, the peer will have to supply the local IP address during IPCP negotiation (unless it specified explicitly on the command line or in an options file).
noipdefault

# Ask the peer for up to 2 DNS server addresses. The addresses supplied by the peer (if any) are passed to the /etc/ppp/ip-up script in the environment variables DNS1 and DNS2, and the environment variable USEPEERDNS will be set to 1. In addition, pppd will create an /etc/ppp/resolv.conf file containing one or two `nameserver` lines with the address(es) supplied by the peer.

usepeerdns

# Add a default route to the system routing tables, using the peer as the gateway, when IPCP negotiation is successfully completed. This entry is removed when the PPP connection is broken. This option is privileged if the nodefaultroute option has been specified.

defaultroute

# Do not exit after a connection is terminated; instead try to reopen the connection. The maxfail option still has an effect on persistent connections.
persist

# Do not require the peer to authenticate itself. This option is privileged.
noauth
```

## Guide

Tested by Matt Ludwigs on [rpi3_nettest](https://github.com/fhunleth/fhunleth-buildroot-experiments)

### Enable Drivers (if not already enabled)

```
$ modprobe huawei_cdc_ncm
$ modprobe option
$ modprobe bsd_comp
$ modprobe ppp_deflate
```

### Switch USB modem from mass storage

By default the modem will register itself
as a mass storage device. Run the below command
to switch its mode:

```
usb_modeswitch -v 12d1 -p 14fe -J
```

After loading the drivers and switch the mode you should see
the interface `wwan0` show up:

```
$ ip link show

1: lo: <LOOPBACK> mtu 65536 qdisc noop qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: wlan0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc pfifo_fast qlen 1000
    link/ether b8:27:eb:13:a3:06 brd ff:ff:ff:ff:ff:ff
3: eth0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc pfifo_fast qlen 1000
    link/ether b8:27:eb:46:f6:53 brd ff:ff:ff:ff:ff:ff
4: wwan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast qlen 1000
    link/ether 00:1e:10:1f:00:00 brd ff:ff:ff:ff:ff:ff
```

Run `pon` on the twilio service to connect:

```
$ pon twilio
```

This will return with no output. To see what
happened run:

```
$ cat /var/log/messages
```

You should see something along the lines of this:

```
Jan  1 00:53:46 nettest daemon.info dhcpcd[112]: wwan0: waiting for carrier
Jan  1 00:53:46 nettest daemon.info dhcpcd[112]: wwan0: carrier acquired
Jan  1 00:53:46 nettest daemon.info dhcpcd[112]: wwan0: IAID 10:1f:00:00
Jan  1 00:53:46 nettest daemon.info dhcpcd[112]: wwan0: adding address fe80::453c:384b:9d79:45cc
Jan  1 00:53:46 nettest daemon.info dhcpcd[112]: wwan0: soliciting an IPv6 router
Jan  1 00:53:47 nettest daemon.info dhcpcd[112]: wwan0: soliciting a DHCP lease
Jan  1 00:53:52 nettest daemon.info dhcpcd[112]: wwan0: probing for an IPv4LL address
Jan  1 00:53:57 nettest daemon.info dhcpcd[112]: wwan0: using IPv4LL address 169.254.62.145
Jan  1 00:53:57 nettest daemon.info dhcpcd[112]: wwan0: adding route to 169.254.0.0/16
Jan  1 00:53:57 nettest daemon.info dhcpcd[112]: wwan0: adding default route
Jan  1 00:53:59 nettest daemon.warn dhcpcd[112]: wwan0: no IPv6 Routers available
Jan  1 00:55:30 nettest daemon.notice pppd[213]: pppd 2.4.7 started by root, uid 0
Jan  1 00:55:31 nettest local2.info chat[214]: abort on (BUSY)
Jan  1 00:55:31 nettest local2.info chat[214]: abort on (NO CARRIER)
Jan  1 00:55:31 nettest local2.info chat[214]: abort on (NO DIALTONE)
Jan  1 00:55:31 nettest local2.info chat[214]: abort on (NO DIAL TONE)
Jan  1 00:55:31 nettest local2.info chat[214]: abort on (NO ANSWER)
Jan  1 00:55:31 nettest local2.info chat[214]: abort on (DELAYED)
Jan  1 00:55:31 nettest local2.info chat[214]: timeout set to 10 seconds
Jan  1 00:55:31 nettest local2.info chat[214]: report (CONNECT)
Jan  1 00:55:31 nettest local2.info chat[214]: send (AT^M)
Jan  1 00:55:31 nettest local2.info chat[214]: expect (OK)
Jan  1 00:55:31 nettest local2.info chat[214]: ^M
Jan  1 00:55:31 nettest local2.info chat[214]: OK
Jan  1 00:55:31 nettest local2.info chat[214]:  -- got it
Jan  1 00:55:31 nettest local2.info chat[214]: send (ATH^M)
Jan  1 00:55:31 nettest local2.info chat[214]: expect (OK)
Jan  1 00:55:31 nettest local2.info chat[214]: ^M
Jan  1 00:55:31 nettest local2.info chat[214]: ^M
Jan  1 00:55:31 nettest local2.info chat[214]: OK
Jan  1 00:55:31 nettest local2.info chat[214]:  -- got it
Jan  1 00:55:31 nettest local2.info chat[214]: send (ATZ^M)
Jan  1 00:55:31 nettest local2.info chat[214]: expect (OK)
Jan  1 00:55:31 nettest local2.info chat[214]: ^M
Jan  1 00:55:31 nettest local2.info chat[214]: ^M
Jan  1 00:55:31 nettest local2.info chat[214]: OK
Jan  1 00:55:31 nettest local2.info chat[214]:  -- got it
Jan  1 00:55:31 nettest local2.info chat[214]: send (ATQ0^M)
Jan  1 00:55:31 nettest local2.info chat[214]: expect (OK)
Jan  1 00:55:31 nettest local2.info chat[214]: ^M
Jan  1 00:55:31 nettest local2.info chat[214]: ^M
Jan  1 00:55:31 nettest local2.info chat[214]: OK
Jan  1 00:55:31 nettest local2.info chat[214]:  -- got it
Jan  1 00:55:31 nettest local2.info chat[214]: send (AT+CGDCONT=1,"IP","wireless.twilio.com"^M)
Jan  1 00:55:32 nettest local2.info chat[214]: expect (OK)
Jan  1 00:55:32 nettest local2.info chat[214]: ^M
Jan  1 00:55:32 nettest local2.info chat[214]: ^M
Jan  1 00:55:32 nettest local2.info chat[214]: OK
Jan  1 00:55:32 nettest local2.info chat[214]:  -- got it
Jan  1 00:55:32 nettest local2.info chat[214]: send (ATDT*99***1#^M)
Jan  1 00:55:32 nettest local2.info chat[214]: expect (CONNECT)
Jan  1 00:55:32 nettest local2.info chat[214]: ^M
Jan  1 00:55:32 nettest local2.info chat[214]: ^M
Jan  1 00:55:32 nettest local2.info chat[214]: CONNECT
Jan  1 00:55:32 nettest local2.info chat[214]:  -- got it
Jan  1 00:55:32 nettest local2.info chat[214]: send (^M)
Jan  1 00:55:32 nettest daemon.info pppd[213]: Serial connection established.
Jan  1 00:55:32 nettest daemon.info pppd[213]: Using interface ppp0
Jan  1 00:55:32 nettest daemon.notice pppd[213]: Connect: ppp0 <--> /dev/ttyUSB0
Jan  1 00:55:35 nettest daemon.warn pppd[213]: Could not determine remote IP address: defaulting to 10.64.64.64
Jan  1 00:55:35 nettest daemon.err pppd[213]: not replacing existing default route through wwan0
Jan  1 00:55:35 nettest daemon.notice pppd[213]: local  IP address 26.35.123.110
Jan  1 00:55:35 nettest daemon.notice pppd[213]: remote IP address 10.64.64.64
Jan  1 00:55:35 nettest daemon.notice pppd[213]: primary   DNS address 10.177.0.34
Jan  1 00:55:35 nettest daemon.notice pppd[213]: secondary DNS address 10.177.0.210
```

Now when running `ip link` you should see the `ppp0` interface:

```
$ ip link show

1: lo: <LOOPBACK> mtu 65536 qdisc noop qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: wlan0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc pfifo_fast qlen 1000
    link/ether b8:27:eb:13:a3:06 brd ff:ff:ff:ff:ff:ff
3: eth0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc pfifo_fast qlen 1000
    link/ether b8:27:eb:46:f6:53 brd ff:ff:ff:ff:ff:ff
4: wwan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast qlen 1000
    link/ether 00:1e:10:1f:00:00 brd ff:ff:ff:ff:ff:ff
5: ppp0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast qlen 3
    link/ppp
```

And `ip addr` should show the ip address for `ppp0`:

```
$ ip addr show ppp0

5: ppp0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast qlen 3
    link/ppp
    inet 26.35.123.110 peer 10.64.64.64/32 scope global ppp0
       valid_lft forever preferred_lft forever
```

Lastly, add the route to the routing table for the default:

```
$ route add default dev ppp0
```

Doing the above step might be able to be automated by
adding to the ip-up scripts in the `/etc/ppp` directory.

To test everything went well you should be able to ping Google:

```
# ping google.com
PING google.com (172.217.11.174): 56 data bytes
64 bytes from 172.217.11.174: seq=0 ttl=54 time=157.092 ms
64 bytes from 172.217.11.174: seq=1 ttl=54 time=76.497 ms
64 bytes from 172.217.11.174: seq=2 ttl=54 time=79.785 ms
^C
--- google.com ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss

```