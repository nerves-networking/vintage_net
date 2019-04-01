# Nerves.NetworkNG

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
by adding `nerves_network_ng` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nerves_network_ng, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/nerves_network_ng](https://hexdocs.pm/nerves_network_ng).

