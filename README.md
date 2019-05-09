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
* Runtime updates to configurations are persisted and applied on next boot (can
  be disabled)
* Simple subscription to network status change events
* Connect to multiple networks at a time and prioritize which interfaces are
  used (Ethernet over WiFi over cellular)
* Internet connection monitoring and failure detection (currently slow and
  simplistic)

The following network configurations are supported:

* [x] Wired Ethernet, IPv4 DHCP
* [ ] Wired Ethernet, IPv4 static IP
* [x] WiFi password-less and WPA2, IPv4 DHCP
* [ ] USB gadget mode Ethernet, IPv4 DHCP server to supply host IP address
* [ ] Cellular networks
* [ ] WiFi AP mode

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

## Application configuration

`VintageNet` has many application configuration keys. Most defaults are fine. At
a minimum, you'll want to specify a default configuration and default regulatory domain if using WiFi. In your main `config.exs`,
add the following:

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
bin_wpa_cli        | Path to `wpa_cli`
bin_ip             | Path to `ip`
udhcpc_handler     | Module for handling notifications from `udhcpc`
resolvconf         | Path to `/etc/resolv.conf`
persistence        | Module for persisting network configurations
persistence_dir    | Path to a directory for storing persisted configurations
internet_host      | IP address for host to `ping` to check for Internet connectivity
regulatory_domain  | ISO 3166-1 alpha-2 country code

## System Requirements

TBD!!!

- `ifupdown`
- `udhcpc`
- `ifconfig`
- `run-parts`
- `mktemp`

### Additional Requirements for Access Point Mode

- `hostapd`
- `dnsmasq`

### Additional Requirements for LTE

#### Kernel modules (defconfig)

- `CONFIG_PPP=m`
- `CONFIG_PPP_BSDCOMP=m`
- `CONFIG_PPP_DEFLATE=m`
- `CONFIG_PPP_ASYNC=m`
- `CONFIG_PPP_SYNC_TTY=m`
- `CONFIG_USB_NET_CDC_NCM=m`
- `CONFIG_USB_NET_HUAWEI_CDC_NCM=m`
- `CONFIG_USB_SERIAL_OPTION=m`

#### System deps

- `pppd`
- `mknod`

## Configuration

`VintageNetwork` supports a variety of network technologies. Configurations are
specified using maps. The following sections so examples:

### Wired Ethernet

```elixir
```

### WiFi

```elixir
```

### LTE

```elixir
```

## Properties

`VintageNet` maintains a key/value store for retrieving information on networking information:

```elixir
iex> VintageNet.get(["interface", "eth0", "connection"])
:internet

iex> VintageNet.get_by_prefix([])
[
  {["interface", "eth0", "connection"], :internet},
  {["interface", "eth0", "state"], "configured"},
  {["interface", "eth0", "type"], VintageNet.Technology.Ethernet},
  {["interface", "wlan0", "connection"], :internet},
  {["interface", "wlan0", "state"], "configured"},
  {["interface", "wlan0", "type"], VintageNet.Technology.WiFi}
]
```

You can also subscribe to keys and receive a message every time it or one
its child keys changes:

```elixir
iex> VintageNet.subscribe(["interface", "eth0"])
:ok

iex> flush
{VintageNet, ["interface", "eth0", "state"], "configuring", "configured", %{}}
```

The message format is `{VintageNet, name, old_value, new_value,
metadata}`

### Global properties

Property               | Values           | Description
 --------------------- | ---------------- | -----------
`available_interfaces` | `[eth0, ...]`    | The currently available network
interfaces in priority order. E.g., the first one is used by default

### Common network interface properties

All network interface properties can be found under `["interface", ifname]` in
the `PropertyTable`.  The following table lists out properties common to all
interfaces:

Property     | Values           | Description
 ----------- | ---------------- | -----------
`type`       | `Ethernet`, etc. | The type of the interface
`state`      | `configured`, `configuring`, etc. | The state of the interface from `VintageNet`'s point of view.
`connection` | `disconnected`, `lan`, `internet` | This provides a determination of the Internet connection status
`ipv4`       | IPv4 parameters  | This is a map of IPv4 parameters on the interface. This includes IP address, subnet, gateway, etc.

Specific types of interfaces provide more parameters.

### Wired Ethernet status

No additional parameters

### WiFi status

Property     | Values           | Description
 ----------- | ---------------- | -----------

### LTE status

Property     | Values           | Description
 ----------- | ---------------- | -----------
`signal`     | 0 - 100          | This is a rough measure of signal strength from 0 (none) to 100 (all bars)
