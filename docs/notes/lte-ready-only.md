# LTE Read Only Filesystem

When working with LTE modems a useful program is `pppd`. There are various ways to configure `pppd`,
but most of them rely on some hardcoded system paths. Unfortunately, this can provide a challenge
when working with a read-only file system. This document is to outline how to connect to an LTE
network with `pppd` while working within the context of a read-only file system.

## System Requirements

1. `pppd`
1. `route`
1. `usb-modeswitch`
1. `ip`

## Required Hardware

1. Huawei USB LTE modem
1. Twilio sim card

## Config

Since we are working in a read-only file system we are going to have to use the `/tmp` directory
to store a config. Assuming we are working in the context of Nerves lets create this config at
this location: `/tmp/nerves-network/chatscripts/twilio`. The chatscript can be downloaded from
[Twilio's PPP script repo](https://github.com/twilio/wireless-ppp-scripts). For convenience
here is the contents of the script:

```
# See http://consumer.huawei.com/solutions/m2m-solutions/en/products/support/application-guides/detail/mu509-65-en.htm?id=82047

# Exit execution if module receives any of the following strings:
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

## Example

### Setup

Before we start `pppd` we need to make sure that our system is in a state to work with `PPP`.

First, if your system does not automatically load the Kernel module for our USB modem and for
our system to work with `PPP`.

Second, we will watch to make sure the USB mode is not mass storage by runnings:

```
usb_modeswitch -v 12d1 -p 14fe -J
```

If everything is good so far can run `ip link show` and we should the `wwan0` interface. However, we are not
able to connect to the internet yet.

### Connecting

Here we are going to run `pppd`. In non-read-only file systems, we could provide what is called an _options_
file in the `/etc/ppp/peers/_provider_` where _provider_ for us would be twilio. Practically speaking, this
is the configuration options for the twilio provider that will be used by `pppd`. However, we are unable to
write this provider file in a read-only file system, so we will have do provide options in a different way.
If you read the man page for `pppd` you will see that there are many ways to provide these options, but all
of them assume file paths we cannot write to. The last way we are able to provide these options is directly
from the CLI command. So, we do this like so:

```
pppd connect "/usr/sbin/chat -v -f /tmp/nerves-network/chatscripts/twilio" /dev/ttyUSB0 115200 noipdefault usepeerdns defaultroute persist noauth
```

You can read about all the options you can pass on the man page for `pppd`, but these should get us connected
to our twilio service.

To see if we are able to connect we can `cat` the `/var/log/messages` and should see:

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

Now we can run `ip link show` and see the `ppp0` interface.

Lastly, we need to add the `ppp0` to the routing table by running `route add default dev ppp0`.

To test try to ping `google.com`. This might take a few seconds the first time,
but after that everything should run smoothly.

