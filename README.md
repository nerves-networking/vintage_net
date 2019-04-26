# VintageNet

## System Requirements

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

## Examples

Wired Ethernet:

```elixir

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `vintage_net` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vintage_net, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/vintage_net](https://hexdocs.pm/vintage_net).

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

## Status updates

Network interface status can be retrieved from `VintageNet`'s `PropertyTable`. You can
also register with the `PropertyTable` to receive messages for status changes.

All network interface properties can be found under `["interface", ifname]` in the `PropertyTable`.
The following table lists out properties common to all interfaces:

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

