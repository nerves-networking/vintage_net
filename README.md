# 🍇 VintageNet

[![CircleCI](https://circleci.com/gh/nerves-networking/vintage_net.svg?style=svg)](https://circleci.com/gh/nerves-networking/vintage_net)
[![Coverage Status](https://coveralls.io/repos/github/nerves-networking/vintage_net/badge.svg?branch=master)](https://coveralls.io/github/nerves-networking/vintage_net?branch=master)
[![Hex version](https://img.shields.io/hexpm/v/vintage_net.svg "Hex version")](https://hex.pm/packages/vintage_net)

> **_NOTE:_**  This library is a work in progress without sufficient
> documentation. It will get there, but the current Nerves networking libraries
> are more stable, tested for what they do, and integrated into most other
> Nerves libraries and examples. If your device is multi-homed (i.e., you use
> two or more network interfaces) or if you want to configure the network in
> a way that's not supported by nerves_network, then this is your library.

`VintageNet` is network configuration library built specifically for [Nerves
Project](https://nerves-project.org) devices. It has the following features:

* Ethernet and WiFi support included. Extendible to other technologies
* Default configurations specified in your Application config
* Runtime updates to configurations are persisted and applied on next boot
  (configurations are obfuscated by default to hide WiFi passphrases)
* Simple subscription to network status change events
* Connect to multiple networks at a time and prioritize which interfaces are
  used (Ethernet over WiFi over cellular)
* Internet connection monitoring and failure detection (currently slow and
  simplistic)

The following network configurations are supported:

* [x] Wired Ethernet, IPv4 DHCP
* [x] Wired Ethernet, IPv4 static IP
* [x] WiFi password-less and WEP
* [x] WPA2 PSK and EAP
* [ ] USB gadget mode Ethernet, IPv4 DHCP server to supply host IP address
* [ ] Cellular networks
* [x] WiFi AP mode
* [ ] IPv6

`VintageNet` takes a different approach to networking from `nerves_network`. It
supports calling "old school" Linux utilities like `ifup` and `ifdown` to
configure networks. While this has many limitations, it can be a timesaver for
migrating a known working Linux setup to Nerves. After that you can change the setup
to call the `ip` command directly and supervise the daemons that you may need
with [MuonTrap](https://github.com/fhunleth/muontrap). And from there you can
replace C implementations with Elixir and Erlang ones if you desire.

Another important difference is that `VintageNet` doesn't attempt to make
incremental modifications to configurations. It completely tears down an
interface's connection and then brings up new configurations in a fresh state.
Network reconfiguration is assumed to be an infrequent event so while this can
cause a hiccup in the network connectivity, it removes state machine code that
made `nerves_network` hard to maintain.

## Installation

The `vintage_net` and `nerves_init_gadget` packages are not compatible. If you
are using `nerves_init_gadget`, you will need to remove it from your dependency
list and add back in things it supplies like `nerves_runtime` and
`nerves_firmware_ssh`.

The package can be installed by adding `vintage_net` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vintage_net, "~> 0.3", targets: @all_targets},
    {:busybox, "~> 0.1", targets: @all_targets}
  ]
end
```

If you have your own custom Nerves system, it's possible to modify that system's
Busybox configuration to enable all of the networking tools used by
`vintage_net`. See the end of this document for the needed settings. If you do
that, delete the `:busybox` dependency above.

See
[vintage_net_example](https://github.com/nerves-networking/vintage_net_example)
for a minimal example project.

## Configuration

`VintageNet` has many application configuration keys. Most defaults are fine. At
a minimum, you'll want to specify a default configuration and default regulatory
domain if using WiFi. In your main `config.exs`, add the following:

```elixir
config :vintage_net,
  regulatory_domain: "US",
  config: [
    {"eth0", %{type: VintageNet.Technology.Ethernet, ipv4: %{method: :dhcp}}},
    {"wlan0", %{type: VintageNet.Technology.WiFi}}
  ]
```

This sets the regulatory domain to the US (set to your [ISO 3166-1 alpha-2
country code](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2). This code is
passed on to the drivers for WiFi and other wireless networking technologies so
that they comply with local regulations. If you need a global default, set to
"00" or don't set at all.  Unfortunately, this may mean that an access point
isn't visible if it is running on a frequency that's allowed in your country,
but not globally.

The `config` section is a list of network configurations. The one shown above
configures DHCP on wired Ethernet and minimally starts up a WiFi LAN so that
it's possible to scan for networks. The typical setup is to provide generic
defaults here. Static IP addresses, WiFi SSIDs and credentials are more
appropriately configured at run-time. `VintageNet` persists configurations too.
Details on network configuration are described later.

The following table describes the other application config keys.

Key                | Description
 ----------------- | ---------------------------
config             | A list of default network configurations
tmpdir             | Path to a temporary directory for VintageNet
to_elixir_socket   | Name to use for the Unix domain socket for C to Elixir communication
bin_ifup           | Path to `ifup`
bin_ifdown         | Path to `ifdown`
bin_chat           | Path to `chat`
bin_pppd           | Path to `pppd`
bin_mknod          | Path to `mknod`
bin_killall        | Path to `killall`
bin_wpa_supplicant | Path to `wpa_supplicant`
bin_ip             | Path to `ip`
udhcpc_handler     | Module for handling notifications from `udhcpc`
resolvconf         | Path to `/etc/resolv.conf`
persistence        | Module for persisting network configurations
persistence_dir    | Path to a directory for storing persisted configurations
persistence_secret | A 16-byte secret or an MFA for getting a secret
internet_host      | IP address for host to `ping` to check for Internet connectivity. Must be a tuple of integers (`{1, 1, 1, 1}`) or binary representation (`"1.1.1.1"`)
regulatory_domain  | ISO 3166-1 alpha-2 country (`00` for global, `US`, etc.)

## Network interface configuration

`VintageNet` supports several network technologies out of the box and
third-party libraries can provide more via the `VintageNet.Technology`
behaviour.

Configurations are Elixir maps. These are specified in three places:

1. The `vintage_net` application config (e.g., your `config.exs`)
2. Locally saved configuration (see the `VintageNet.Persistence` behaviour for
   replacing the default)
3. Calling `VintageNet.configure/2` to change the configuration at run-time

When `vintage_net` starts, it applies saved configurations first and if any
thing is wrong with those configs, it reverts to the application config. A good
practice is to have safe defaults for all network interfaces in the application
config.

The only required key in the configuration maps is `:type`. All other keys
follow from the type. `:type` should be set to a module that implements the
`VintageNet.Technology` behaviour. The following are included:

* `VintageNet.Technology.Ethernet` - Standard wired Ethernet
* `VintageNet.Technology.WiFi` - Client configurations for 802.11 WiFi
* `VintageNet.Technology.Mobile` - Cellular configurations (likely to be
  refactored to a separate library)
* `VintageNet.Technology.Null` - An empty configuration useful for turning off a
  configuration

The following sections describe the types in more detail.

### Wired Ethernet

Wired Ethernet interfaces typically have names like `"eth0"`, `"eth1"`, etc.
when using Nerves.

An example configuration for enabling an Ethernet interface that dynamically
gets an IP address is:

```elixir
config :vintage_net,
  config: [
    {"eth0",
     %{
       type: VintageNet.Technology.Ethernet,
       ipv4: %{
         method: :dhcp
       }
     }}
  ]
```

You can also set the configuration at runtime:

```elixir
iex> VintageNet.configure("eth0", %{type: VintageNet.Technology.Ethernet, ipv4: %{method: :dhcp}})
:ok
```

Here's a static IP configuration:

```elixir
iex>   VintageNet.configure("eth0", %{
    type: VintageNet.Technology.Ethernet,
    ipv4: %{
      method: :static,
      address: "192.168.9.232",
      prefix_length: 24,
      gateway: "192.168.9.1",
      name_servers: ["1.1.1.1"]
    }
  })
:ok
```

In the above, IP addresses were passed as strings for convenience, but it's also
possible to pass tuples like `{192, 168, 9, 232}` as is more typical in Elixir
and Erlang. VintageNet internally works with tuples.

The following fields are supported:

* `:method` - Set to `:dhcp`, `:static`, or `:disabled`. If `:static`, then at
  least an IP address and mask need to be set. `:disabled` enables the interface
  and doesn't apply an IP configuration
* `:address` - the IP address for static IP addresses
* `:prefix_length` - the number of bits in the IP address to use for the subnet
  (e.g., 24)
* `:netmask` - either this or `prefix_length` is used to determine the subnet.
* `:gateway` - the default gateway for this interface (optional)
* `:name_servers` - a list of name servers for static configurations (optional)
* `:domain` - a search domain for DNS

Wired Ethernet connections are monitored for Internet connectivity if a default
gateway is available. When internet-connected, they are preferred over all other
network technologies even when the others provide default gateways.

### WiFi

WiFi network interfaces typically have names like `"wlan0"` or `"wlan1"` when
using Nerves. Most of the time, there's only one WiFi interface and its
`"wlan0"`. Some WiFi adapters expose separate interfaces for 2.4 GHz and 5 GHz
and they can be configured independently.

An example WiFi configuration looks like this:

```elixir
config :vintage_net,
  config: [
    {"wlan0",
     %{
       type: VintageNet.Technology.WiFi,
       wifi: %{
         key_mgmt: :wpa_psk,
         psk: "a_passphrase_or_psk",
         ssid: "my_network_ssid"
       },
       ipv4: %{
         method: :dhcp
       }
     }}
  ]
```

The `:ipv4` key is the same as in Wired Ethernet.

The `:wifi` key has the following common fields:

* `:ap_scan` -  See `wpa_supplicant` documentation. The default for this, 1,
  should work for nearly all users.
* `:bgscan` - Periodic background scanning to support roaming within an ESS.
  * `:simple`
  * `{:simple, args}` - args is a string to be passed to the `simple` wpa module
  * `:learn`
  * `{:learn, args}` args is a string to be passed to the `learn` wpa module
* `:passive_scan`
  * 0:  Do normal scans (allow active scans) (default)
  * 1:  Do passive scans.
* `:regulatory_domain`: Two character country code. Technology configuration
  will take priority over Application configuration
* `:networks` - A list of Wi-Fi networks to configure. In client mode,
  VintageNet connects to the first available network in the list. In host mode,
  the list should have one entry with SSID and password information.
  * `:mode` -
    * `:infrastructure` (default) - Normal operation. Associate with an AP
    * `:ap` - access point mode
    * `:ibss` - peer to peer mode (not supported)
  * `:ssid` - The SSID for the network
  * `:key_mgmt` - WiFi security mode (`:wpa_psk` for WPA2, `:none` for no
    password or WEP)
  * `:psk` - A WPA2 passphrase or the raw PSK. If a passphrase is passed in, it
    will be converted to a PSK and discarded.
  * `:priority` - The priority to set for a network if you are using multiple
    network configurations
  * `:scan_ssid` - Scan with SSID-specific Probe Request frames (this can be
    used to find APs that do not accept broadcast SSID or use multiple SSIDs;
    this will add latency to scanning, so enable this only when needed)

See the [official
docs](https://w1.fi/cgit/hostap/plain/wpa_supplicant/wpa_supplicant.conf) for
the complete list of options.

Here's an example:

```elixir
iex> VintageNet.configure("wlan0", %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            key_mgmt: :wpa_psk,
            psk: "a_passphrase_or_psk",
            ssid: "my_network_ssid"
          }
        ]
      },
      ipv4: %{method: :dhcp}
    })
```

Example of WEP:

```elixir
iex> VintageNet.configure("wlan0", %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            ssid: "my_network_ssid",
            wep_key0: "42FEEDDEAFBABEDEAFBEEFAA55",
            key_mgmt: :none,
            wep_tx_keyidx: 0
          }
        ]
      },
      ipv4: %{method: :dhcp}
    })
```

Enterprise Wi-Fi (WPA-EAP) support mostly passes through to the
`wpa_supplicant`. Instructions for enterprise network for Linux
should map. For example:

```elixir
iex> VintageNet.configure("wlan0", %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            ssid: "testing",
            key_mgmt: :wpa_eap,
            pairwise: "CCMP TKIP",
            group: "CCMP TKIP",
            eap: "PEAP",
            identity: "user1",
            password: "supersecret",
            phase1: "peapver=auto",
            phase2: "MSCHAPV2"
          }
        ]
      },
      ipv4: %{method: :dhcp}
})
```

Network adapters that can run as an Access Point can be configured as follows:

```elixir
iex> VintageNet.configure("wlan0", %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            mode: :ap,
            ssid: "test ssid",
            key_mgmt: :none
          }
        ]
      },
      ipv4: %{
        method: :static,
        address: "192.168.24.1",
        netmask: "255.255.255.0"
      },
      dhcpd: %{
        start: "192.168.24.2",
        end: "192.168.24.10"
      }
})
```

If your device may be installed in different countries, you should override the
default regulatory domain to the desired country at runtime.  VintageNet uses
the global domain by default and that will restrict the set of available Wi-Fi
frequencies in some countries. For example:

```elixir
iex> VintageNet.configure("wlan0", %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        regulatory_domain: "US",
        networks: [
          %{
            ssid: "testing",
            key_mgmt: :wpa_psk,
            psk: "super secret"
          }
        ]
      },
      ipv4: %{method: :dhcp}
})
```

### LTE

TBD

```elixir
```

### USB gadget mode

VintageNet comes with a technology to setup usb gadget devices.
This will use OneDHCPD to configure the ip address automatically.

```elixir
  config :vintage_net, [
    config: [
      {"usb0", %{type: VintageNet.Technology.Gadget}}},
    ]
  ]
```

## Persistence

By default, VintageNet stores network configuration to disk. If you are
migrating from `nerves_network` you may already have a persistence
implementation. To disable the default persistence, configure `vintage_net` as
follows:

```elixir
config :vintage_net,
  persistence: VintageNet.Persistence.Null
```

## Debugging

Debugging networking issues is not fun. When you're starting out with
`vintage_net`, it is highly recommended to connect to your target using a method
that doesn't require networking to work. This could be a UART connection to an
IEx console on a Nerves device or maybe just hooking up a keyboard and monitor.

If having trouble, first check `VintageNet.info()` to verify the configuration
and connection status:

```elixir
iex> VintageNet.info
VintageNet 0.3.0

All interfaces:       ["eth0", "lo", "tap0", "wlan0"]
Available interfaces: ["eth0", "wlan0"]

Interface eth0
  Type: VintageNet.Technology.Ethernet
  Present: true
  State: :configured
  Connection: :internet
  Configuration:
    %{ipv4: %{method: :dhcp}, type: VintageNet.Technology.Ethernet}

Interface wlan0
  Type: VintageNet.Technology.WiFi
  Present: true
  State: :configured
  Connection: :internet
  Configuration:
    %{
      ipv4: %{method: :dhcp},
      type: VintageNet.Technology.WiFi,
      wifi: %{
        key_mgmt: :wpa_psk,
        mode: :infrastructure,
        psk: "******",
        ssid: "MyLAN"
      }
    }
```

If you're using [Toolshed](https://github.com/fhunleth/toolshed), try running
the following:

```elixir
iex> ifconfig
lo: flags=[:up, :loopback, :running]
    inet 127.0.0.1  netmask 255.0.0.0
    inet ::1  netmask ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff
    hwaddr 00:00:00:00:00:00

eth0: flags=[:up, :broadcast, :running, :multicast]
    inet 192.168.9.131  netmask 255.255.255.0  broadcast 192.168.9.255
    inet fe80::6264:5ff:fee1:4045  netmask ffff:ffff:ffff:ffff::
    hwaddr 60:64:05:e1:40:45

wlan0: flags=[:up, :broadcast, :running, :multicast]
    inet 192.168.9.175  netmask 255.255.255.0  broadcast 192.168.9.255
    inet fe80::20c:e7ff:fe11:3d46  netmask ffff:ffff:ffff:ffff::
    hwaddr 00:0c:e7:11:3d:46
```

Or ping:

```elixir
iex> ping "nerves-project.com"
Press enter to stop
Response from nerves-project.com (96.126.123.244): time=48.87ms
Response from nerves-project.com (96.126.123.244): time=42.856ms
Response from nerves-project.com (96.126.123.244): time=43.097ms
```

You can also specify an interface to use with `ping`:

```elixir
iex> ping "nerves-project.com", ifname: "wlan0"
Press enter to stop
Response from nerves-project.com (96.126.123.244): time=57.817ms
Response from nerves-project.com (96.126.123.244): time=46.796ms

iex> ping "nerves-project.com", ifname: "eth0"
Press enter to stop
Response from nerves-project.com (96.126.123.244): time=47.923ms
Response from nerves-project.com (96.126.123.244): time=48.688ms
```

If it looks like nothing is working, check the logs. On Nerves devices, this
is frequently done by calling `RingLogger.next` or `RingLogger.attach`.

At a last resort, please open a GitHub issue. We would be glad to help. We only
have one ask and that is that you get us started with an improvement to our
documentation or code so that the next person to run into the issue will have an
easier time. Thanks!

## Properties

`VintageNet` maintains a key/value store for retrieving information on
networking information:

```elixir
iex> VintageNet.get(["interface", "eth0", "connection"])
:internet

iex> VintageNet.get_by_prefix([])
[
  {["interface", "eth0", "connection"], :internet},
  {["interface", "eth0", "state"], :configured},
  {["interface", "eth0", "type"], VintageNet.Technology.Ethernet},
  {["interface", "wlan0", "connection"], :internet},
  {["interface", "wlan0", "state"], :configured},
  {["interface", "wlan0", "type"], VintageNet.Technology.WiFi}
]
```

You can also subscribe to keys and receive a message every time it or one its
child keys changes:

```elixir
iex> VintageNet.subscribe(["interface", "eth0"])
:ok

iex> flush
{VintageNet, ["interface", "eth0", "state"], :configuring, :configured, %{}}
```

The message format is `{VintageNet, name, old_value, new_value, metadata}`

### Global properties

Property               | Values           | Description
 --------------------- | ---------------- | -----------
`available_interfaces` | `[eth0, ...]`    | Currently available network interfaces in priority order. E.g., the first one is used by default
`connection`           | `:disconnected`, `:lan`, `:internet` | The overall network connection status. This is the best status of all interfaces.

### Common network interface properties

All network interface properties can be found under `["interface", ifname]` in
the `PropertyTable`.  The following table lists out properties common to all
interfaces:

Property      | Values              | Description
 ------------ | ------------------- | -----------
`type`        | `VintageNet.Technology.Ethernet`, etc. | The type of the interface
`state`       | `:configured`, `:configuring`, etc. | The state of the interface from `VintageNet`'s point of view.
`connection`  | `:disconnected`, `:lan`, `:internet` | This provides a determination of the Internet connection status
`lower_up`    | `true` or `false`   | This indicates whether the physical layer is "up". E.g., a cable is connected or WiFi associated
`mac_address` | "11:22:33:44:55:66" | The interface's MAC address as a string
`addresses`   | [address_info]      | This is a list of all of the addresses assigned to this interface

Specific types of interfaces provide more parameters.

### Wired Ethernet status

No additional parameters

### WiFi status

Property        | Values           | Description
 -------------- | ---------------- | -----------
`access_points` | [%AccessPoint{}] | A list of access points as found by the most recent scan
`clients`       | ["11:22:33:44:55:66"] | A list of clients connected to the access point when using `mode: :ap`
`current_ap`    | %AccessPoint{}   | The currently associated access point

Access points are identified by their BSSID. Information about an access point
has the following form:

```elixir
%VintageNet.WiFi.AccessPoint{
  band: :wifi_5_ghz,
  bssid: "8a:8a:20:88:7a:50",
  channel: 149,
  flags: [:wpa2_psk_ccmp, :ess],
  frequency: 5745,
  signal_dbm: -76,
  signal_percent: 57,
  ssid: "MyNetwork"
}
```

Applications can scan for access points in a couple ways. The first is to call
`VintageNet.scan("wlan0")`, wait for a second, and then call
`VintageNet.get(["interface", "wlan0", "access_points"])`. This works for
scanning networks once or twice. A better way is to subscribe to the
`"access_points"` property and then call `VintageNet.scan("wlan0")` on a timer.
The `"access_points"` property updates as soon as the WiFi module notifies that
it is complete so applications don't need to guess how long to wait.

### LTE status

Property         | Values           | Description
 --------------- | ---------------- | -----------
`signal_percent` | 0 - 100          | This is a rough measure of signal strength from 0 (none) to 100 (all bars)

## System Requirements

### Kernel Requirements

IMPORTANT: `CONFIG_IP_MULTIPLE_TABLES=y` is critical. VintageNet is completely
depended on source IP-based routing to work.

* `CONFIG_IP_ADVANCED_ROUTER=y`
* `CONFIG_IP_MULTIPLE_TABLES=y`
* `CONFIG_IP_ROUTE_VERBOSE=y` - (optional)

### Busybox Requirements

To avoid enabling these, add `{:busybox, "~> 0.1"}` to your `mix` dependencies.

* `CONFIG_UDHCPC=y` - `udhcpc` DHCP Client
* `CONFIG_UDHCPD=y` - `udhcpd` DHCP Server (optional)
* `CONFIG_IFUP=y` - `ifup`
* `CONFIG_IFDOWN=y` `ifdown`
* `CONFIG_RUN_PARTS=y`
* `CONFIG_MKTEMP=y`

### Buildroot Requirements

* `BR2_PACKAGE_WPA_SUPPLICANT`

### Additional Requirements for Access Point Mode

* `CONFIG_UDHCPD` (in busybox)
* `BR2_PACKAGE_WPA_SUPPLICANT_HOTSPOT`

### Additional Requirements for LTE

#### Kernel modules (defconfig)

* `CONFIG_PPP=m`
* `CONFIG_PPP_BSDCOMP=m`
* `CONFIG_PPP_DEFLATE=m`
* `CONFIG_PPP_ASYNC=m`
* `CONFIG_PPP_SYNC_TTY=m`
* `CONFIG_USB_NET_CDC_NCM=m`
* `CONFIG_USB_SERIAL_OPTION=m`

#### System deps

* `pppd`
* `mknod`
