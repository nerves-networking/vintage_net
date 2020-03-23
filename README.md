![vintage net logo](assets/logo.png)

[![Hex version](https://img.shields.io/hexpm/v/vintage_net.svg "Hex version")](https://hex.pm/packages/vintage_net)
[![API docs](https://img.shields.io/hexpm/v/vintage_net.svg?label=hexdocs "API docs")](https://hexdocs.pm/vintage_net/VintageNet.html)
[![CircleCI](https://circleci.com/gh/nerves-networking/vintage_net.svg?style=svg)](https://circleci.com/gh/nerves-networking/vintage_net)
[![Coverage Status](https://coveralls.io/repos/github/nerves-networking/vintage_net/badge.svg?branch=master)](https://coveralls.io/github/nerves-networking/vintage_net?branch=master)

> **_NOTE:_**  If you've been using `vintage_net` `v0.6.x` or earlier, we split
> out network technology support out to separate libraries in `v0.7.0`. You'll
> need to add those libraries to your `mix` dependency list and rename some
> atoms.  Configurations stored on deployed devices will be automatically
> updated.  See the [v0.7.0 release
> notes](https://github.com/nerves-networking/vintage_net/releases/tag/v0.7.0)
> for details.

`VintageNet` is network configuration library built specifically for [Nerves
Project](https://nerves-project.org) devices. It has the following features:

* Ethernet and WiFi support included. Extendible to other technologies
* Default configurations specified in your Application config
* Runtime updates to configurations are persisted and applied on next boot
  (configurations are obfuscated by default to hide WiFi passphrases)
* Simple subscription to network status change events
* Connect to multiple networks at a time and prioritize which interfaces are
  used (Ethernet over WiFi over cellular)
* Internet connection monitoring and failure detection

> **TL;DR:** Don't care about any of this and just want the string to copy/paste
> to set up networking? See the [VintageNet Cookbook](https://github.com/nerves-networking/vintage_net/blob/master/docs/cookbook.md).

The following network configurations are supported:

* [x] Wired Ethernet, IPv4 DHCP
* [x] Wired Ethernet, IPv4 static IP
* [x] WiFi password-less and WEP
* [x] WPA2 PSK and EAP
* [x] USB gadget mode Ethernet, IPv4 DHCP server to supply host IP address
* [x] Cellular networks (see `vintage_net_mobile` for details)
* [x] WiFi AP mode
* [ ] IPv6

`vintage_net` takes a different approach to networking from `nerves_network`.
Its focus is on building and applying network configurations. Where
`nerves_network` provided configurable state machines, `vintage_net` turns
human-readable configurations into everything from configuration files and calls
to [`ip`](https://linux.die.net/man/8/ip) to starting up networking `GenServers`
and routing table updates. This makes it easier to add support for new network
technologies and features. While Elixir and Erlang were great to implement
network protocols in, it was frequently more practical to reuse embedded Linux
implementations. Importantly, though, `vintage_net` monitors Linux daemons under
its OTP supervision tree so failures on both the "C" and Elixir sides propagate
in the expected ways.

Another important difference is that `VintageNet` doesn't attempt to make
incremental modifications to configurations. It completely tears down an
interface's connection and then brings up new configurations in a fresh state.
Network reconfiguration is assumed to be an infrequent event so while this can
cause a hiccup in the network connectivity, it removes state machine code that
made `nerves_network` hard to maintain.

## Installation

First, if you're modifying an existing project, you will need to remove
`nerves_network` and `nerves_init_gadget`. `vintage_net` doesn't work with
either of them. You'll get an error if any project references those packages.

There are two routes to integrating `vintage_net`:

1. Use [nerves_pack](https://hex.pm/packages/nerves_pack). `nerves_pack` is like
   `nerves_init_gadget`, but for `vintage_net`.
2. Copy and paste from
   [vintage_net_example](https://github.com/nerves-networking/vintage_net_example)

The next step is to make sure that your Nerves system is compatible. The
official Nerves systems released after 12/11/2019 work without modification. If
rolling your own Nerves port, you will need the following Linux kernel options
enabled:

* `CONFIG_IP_ADVANCED_ROUTER=y`
* `CONFIG_IP_MULTIPLE_TABLES=y`

Then make sure that you have the following Busybox options enabled:

* `CONFIG_IFCONFIG=y` - `ifconfig` ifconfig
* `CONFIG_UDHCPC=y` - `udhcpc` DHCP Client
* `CONFIG_UDHCPD=y` - `udhcpd` DHCP Server (optional)

You can avoid making the Busybox changes by adding `:busybox` to your project's
mix dependencies:

```elixir
    {:busybox, "~> 0.1", targets: @all_targets}
```

Finally, you'll need to choose what network connection technologies that you
want available in your firmware. If using `nerves_pack`, you'll get support for
wired Ethernet, WiFi, and USB gadget networking automatically. Otherwise, add
one or more of the following to your dependency list:

* [`vintage_net_ethernet`](https://github.com/nerves-networking/vintage_net_ethernet) - Standard wired Ethernet
* [`vintage_net_wifi`](https://github.com/nerves-networking/vintage_net_wifi) - Client configurations for 802.11 WiFi
* [`vintage_net_direct`](https://github.com/nerves-networking/vintage_net_direct) - Direct connections like those used for USB gadget
* [`vintage_net_mobile`](https://github.com/nerves-networking/vintage_net_mobile) - Support for a few cellular modems

## Configuration

`VintageNet` has many application configuration keys. Most defaults are fine. At
a minimum, you'll want to specify a default configuration and default regulatory
domain if using WiFi. In your main `config.exs`, add the following:

```elixir
config :vintage_net,
  regulatory_domain: "US",
  config: [
    {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}},
    {"wlan0", %{type: VintageNetWiFi}}
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
`VintageNet.Technology` behaviour. The following are common technologies:

* [`VintageNetEthernet`](https://github.com/nerves-networking/vintage_net_ethernet) - Standard wired Ethernet
* [`VintageNetWiFi`](https://github.com/nerves-networking/vintage_net_wifi) - Client configurations for 802.11 WiFi
* [`VintageNetDirect`](https://github.com/nerves-networking/vintage_net_direct) - Direct connections like those used for USB gadget
  connections
* `VintageNet.Technology.Null` - An empty configuration useful for turning off a
  configuration

See the links above for specific documentation.

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
  Type: VintageNetEthernet
  Present: true
  State: :configured
  Connection: :internet
  Configuration:
    %{ipv4: %{method: :dhcp}, type: VintageNetEthernet}

Interface wlan0
  Type: VintageNetWiFi
  Present: true
  State: :configured
  Connection: :internet
  Configuration:
    %{
      ipv4: %{method: :dhcp},
      type: VintageNetWiFi,
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
  {["interface", "eth0", "type"], VintageNetEthernet},
  {["interface", "wlan0", "connection"], :internet},
  {["interface", "wlan0", "state"], :configured},
  {["interface", "wlan0", "type"], VintageNetWiFi}
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
`type`        | `VintageNetEthernet`, etc. | The type of the interface
`state`       | `:configured`, `:configuring`, etc. | The state of the interface from `VintageNet`'s point of view.
`connection`  | `:disconnected`, `:lan`, `:internet` | This provides a determination of the Internet connection status
`lower_up`    | `true` or `false`   | This indicates whether the physical layer is "up". E.g., a cable is connected or WiFi associated
`mac_address` | "11:22:33:44:55:66" | The interface's MAC address as a string
`addresses`   | [address_info]      | This is a list of all of the addresses assigned to this interface

Specific types of interfaces provide more parameters.

