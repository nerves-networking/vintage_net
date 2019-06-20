# 🍇 VintageNet

[![CircleCI](https://circleci.com/gh/nerves-networking/vintage_net.svg?style=svg)](https://circleci.com/gh/nerves-networking/vintage_net)
[![Coverage Status](https://coveralls.io/repos/github/nerves-networking/vintage_net/badge.svg?branch=master)](https://coveralls.io/github/nerves-networking/vintage_net?branch=master)
[![Hex version](https://img.shields.io/hexpm/v/vintage_net.svg "Hex version")](https://hex.pm/packages/vintage_net)

> **_NOTE:_**  This library is very much a work in progress without sufficient
> documentation. It will get there, but the current Nerves libraries are much
> more stable, tested for what they do, and integrated into most other Nerves
> libraries and examples. Most importantly, the official Nerves systems do not
> contain some of the programs and kernel configuration needed to make this
> work.

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
* [ ] Wired Ethernet, IPv4 static IP
* [x] WiFi password-less and WEP
* [x] WPA2 PSK and EAP
* [ ] USB gadget mode Ethernet, IPv4 DHCP server to supply host IP address
* [ ] Cellular networks
* [x] WiFi AP mode
* [ ] IPv6

`VintageNet` takes a different approach to networking from `nerves_network`. It
supports calling "old school" Linux utilities like `ifup` and `ifdown` to
configure networks. While this isn't ideal, some network configurations are only
documented for Linux systems and this can be a huge timesaver for getting an
unusual network configuration working. `VintageNet` supports a migration path to
pulling configuration back into Elixir piecemeal.  Additionally, `VintageNet`
doesn't attempt to make incremental modifications to configurations. It
completely tears down an interface's connection and then brings up new
configurations in a fresh state. Network reconfiguration is assumed to be an
infrequent event so while this can cause a hiccup in the network connectivity,
it removes most of the state machine code that made `nerves_network` hard to
maintain.

## Installation

The `vintage_net` and `nerves_init_gadget` packages are not compatible. If you
are using `nerves_init_gadget`, you will need to remove it from your dependency
list and add back in things it supplies like `nerves_runtime` and
`nerves_firmware_ssh`.

When [available in Hex](https://hex.pm/docs/publish), the package can be
installed by adding `vintage_net` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vintage_net, "~> 0.1.0", targets: @all_targets}
  ]
end
```

Erlang/OTP provides many libraries for debugging networking issues. You may also
want to add [Toolshed](https://github.com/fhunleth/toolshed) to your dependencies
so that you can have more familiar looking tools like `ifconfig` and `ping` at
the IEx prompt.

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
it's possible to scan for networks. Details on network configuration are
described later.

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
internet_host      | IP address for host to `ping` to check for Internet connectivity
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

Currently only IPv4 support using DHCP is supported:

```elixir
%{type: VintageNet.Technology.Ethernet, ipv4: %{method: :dhcp}}
```

For example, to set the configuration at runtime:

```elixir
iex> VintageNet.configure("eth0", %{type: VintageNet.Technology.Ethernet, ipv4: %{method: :dhcp}})
:ok
```

Wired Ethernet connections are monitored for Internet connectivity. When
internet-connected, they are preferred over all other network technologies even
when the others provide default gateways.

### WiFi

WiFi network interfaces typically have names like `"wlan0"` or `"wlan1"` when
using Nerves. Most of the time, there's only one WiFi interface and its
`"wlan0"`. Some WiFi adapters expose separate interfaces for 2.4 GHz and 5 GHz
and they can be configured independently.

WiFi configuration looks like this:

```elixir
%{
  type: VintageNet.Technology.WiFi,
  wifi: %{
    key_mgmt: :wpa_psk,
    mode: :client,
    psk: "a_passphrase_or_psk",
    ssid: "my_network_ssid"
  },
  ipv4: %{method: :dhcp}
}
```

The `:ipv4` key is the same as in Wired Ethernet and only DHCP is currently
supported.

The `:wifi` key has the following common fields:

* `:key_mgmt` - WiFi security mode (`:wpa_psk` for WPA2, `:none` for no
  password)
* `:mode` -
  * `:client` (default) - Normal operation. Associate with an AP
  * `:adhoc` - peer to peer mode
  * `:host` - access point mode
* `:psk` - A WPA2 passphrase or the raw PSK. If a passphrase is passed in, it
  will be converted to a PSK and disgarded.
* `:ssid` - The SSID for the network
* `:bgscan` - Periodic background scanning. See the link below for more information.
  * `:simple`
  * `{:simple, args}` - args is a string to be passed to the `simple` wpa module
  * `:learn`
  * `{:learn, args}` args is a string to be passed to the `learn` wpa module

See the [official
docs](https://w1.fi/cgit/hostap/plain/wpa_supplicant/wpa_supplicant.conf) for
the complete list of options.

Here's an example:

```elixir
iex> VintageNet.configure("wlan0", %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        key_mgmt: :wpa_psk,
        mode: :client,
        psk: "a_passphrase_or_psk",
        ssid: "my_network_ssid"
      },
      ipv4: %{method: :dhcp}
    })
```

Example of WEP:

```elixir
iex> VintageNet.configure("wlan0", %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "my_network_ssid",
        wep_key0: "42FEEDDEAFBABEDEAFBEEFAA55",
        key_mgmt: :none,
        wep_tx_keyidx: 0
      },
      ipv4: %{method: :dhcp}
    })
```

Example of WPA-EAP:

```elixir
iex> VintageNet.configure("wlan0", %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "testing",
        key_mgmt: :wpa_eap,
        scan_ssid: 1,
        pairwise: "CCMP TKIP",
        group: "CCMP TKIP",
        eap: "PEAP",
        identity: "user1",
        password: "supersecret",
        phase1: "peapver=auto",
        phase2: "MSCHAPV2"
      },
      ipv4: %{method: :dhcp}
})
```

Example of access point mode:

```elixir
iex> VintageNet.configure("wlan0", %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        mode: :host,
        ssid: "test ssid",
        key_mgmt: :none
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

### LTE

```elixir
```

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

Property     | Values           | Description
 ----------- | ---------------- | -----------
`type`       | `VintageNet.Technology.Ethernet`, etc. | The type of the interface
`state`      | `:configured`, `:configuring`, etc. | The state of the interface from `VintageNet`'s point of view.
`connection` | `:disconnected`, `:lan`, `:internet` | This provides a determination of the Internet connection status
`lower_up`   | `true` or `false` | This indicates whether the physical layer is "up". E.g., a cable is connected or WiFi associated
`ipv4`       | IPv4 parameters  | This is a map of IPv4 parameters on the interface. This includes IP address, subnet, gateway, etc. NOT IMPLEMENTED YET

Specific types of interfaces provide more parameters.

### Wired Ethernet status

No additional parameters

### WiFi status

Property        | Values           | Description
--- ----------- | ---------------- | -----------
`access_points` | %{"11:22:33:44:55:66" => %AccessPoint{}} | A map of access points as found by the most recent scan

Access points are identified by their BSSID. Information about an access point
has the following form:

```elixir
%VintageNet.WiFi.AccessPoint{
  bssid: "78:8a:20:87:7a:50",
  flags: [:wpa2_psk_ccmp, :ess],
  frequency: 2437,
  signal: -67,
  ssid: "MyNetwork"
}
```

Applications can scan for access points in a couple ways. The first is to call
`VintageNet.scan("wlan0")`, wait for a second, and then call
`VintageNet.get(["interface", "wlan0", "access_points"])`. This works for
scanning networks once or twice. A better way, though, is to subscribe to the
`"access_points"` property and then call `VintageNet.scan("wlan0")` on a timer.
The `"access_points"` property updates as soon as the WiFi module notifies that
it is complete so applications don't need to guess how long to wait.

### LTE status

Property     | Values           | Description
 ----------- | ---------------- | -----------
`signal`     | 0 - 100          | This is a rough measure of signal strength from 0 (none) to 100 (all bars)

## System Requirements

### Kernel Requirements

* `CONFIG_IP_ADVANCED_ROUTER=y`
* `CONFIG_IP_MULTIPLE_TABLES=y`
* `CONFIG_IP_ROUTE_VERBOSE=y` - (optional)

### Busybox Requirements

* `CONFIG_UDHCPC=y` - `udhcpc` DHCP Client
* `CONFIG_UDHCPD=y` - `udhcpd` DHCP Server (optional)
* `CONFIG_IFUP=y` - `ifup`
* `CONFIG_IFDOWN=y` `ifdown`
* `CONFIG_RUN_PARTS=y`
* `CONFIG_MKTEMP=y`

### Buildroot Requirements

* `BR2_PACKAGE_WPA_SUPPLICANT`
* `BR2_PACKAGE_WPA_SUPPLICANT_CLI`

### Additional Requirements for Access Point Mode

* `BR2_PACKAGE_DNSMASQ` or `CONFIG_UDHCPD` (in busybox)
* `BR2_PACKAGE_HOSTAPD` or `BR2_PACKAGE_WPA_SUPPLICANT_HOTSPOT`

### Additional Requirements for LTE

#### Kernel modules (defconfig)

* `CONFIG_PPP=m`
* `CONFIG_PPP_BSDCOMP=m`
* `CONFIG_PPP_DEFLATE=m`
* `CONFIG_PPP_ASYNC=m`
* `CONFIG_PPP_SYNC_TTY=m`
* `CONFIG_USB_NET_CDC_NCM=m`
* `CONFIG_USB_NET_HUAWEI_CDC_NCM=m`
* `CONFIG_USB_SERIAL_OPTION=m`

#### System deps

* `pppd`
* `mknod`
