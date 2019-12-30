# VintageNet Cookbook

Not sure what to pass to `vintage_net`? Take a look below for example
configurations.

## Compile-time vs. run-time

The examples below all show the options to pass. Where you copy those depends on
whether you want the configuration to be a built-in default (i.e., compile-time)
or whether you want to change it at run-time.

For compile-time, add something like the following to your `config.exs`:

```elixir
config :vintage_net,
  config: [
    {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}},
  ]
```

But replace `"eth0"` with the interface and the map with the desired
configuration from below.

For run-time, call
[`VintageNet.configure`](https://hexdocs.pm/vintage_net/VintageNet.html#configure/3)
like this:

```elixir
VintageNet.configure("eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}})
```

To see the current configuration at an IEx prompt, type:

```elixir
iex> VintageNet.info
```

## Network interface names

In order to configure a network interface, you will need to know its name.
`vintage_net` passes names through from Nerves or embedded Linux depending on
where it's being run. The following names are common:

* `"eth0"` - The first wired Ethernet interface
* `"wlan0"` - The first WiFi interface
* `"usb0"` - The first virtual Ethernet interface over a USB cable

The operating system assigns network interface names as it discovers them. If
you're running on a device with multiple of the same type of interface, the
device names may be renamed to make them deterministic. An example is `"enp6s0"`
where the `p6` and `s0` indicate where the adapter and Ethernet connector
location. Running `ifconfig` on Linux and Nerves can help find these if you are
unsure.

## Wired Ethernet

To use, make sure that you're either using
[`nerves_pack`](https://hex.pm/packages/nerves_pack) or have
`:vintage_net_ethernet` in your deps:

```elixir
  {:vintage_net_ethernet, "~> 0.7"}
```

### Wired Ethernet with DHCP

This is regular wired Ethernet - nothing fancy:

```elixir
%{type: VintageNetEthernet, ipv4: %{method: :dhcp}}}
```

### Wired Ethernet with a static IP

Update the parameters below as appropriate:

```elixir
%{
  type: VintageNetEthernet,
  ipv4: %{
    method: :static,
    address: "192.168.9.232",
    prefix_length: 24,
    gateway: "192.168.9.1",
    name_servers: ["1.1.1.1"]
  }
}
```

See
[`VintageNet.IP.IPv4Config`](https://hexdocs.pm/vintage_net/VintageNet.IP.IPv4Config.html)
for other options. If you're interfacing with other Erlang and Elixir libraries,
you may find passing IP tuples more convenient than passing strings. That works
too.

## WiFi

To use, make sure that you're either using
[`nerves_pack`](https://hex.pm/packages/nerves_pack) or have
`:vintage_net_wifi` in your deps:

```elixir
  {:vintage_net_wifi, "~> 0.7"}
```


### Normal password-protected WiFi (WPA2 PSK)

Most password-protected home networks use WPA2 authentication and pre-shared
keys.

```elixir
%{
  type: VintageNetWiFi,
  wifi: %{
    key_mgmt: :wpa_psk,
    ssid: "my_network_ssid",
    psk: "secret_password",
  },
  ipv4: %{
    method: :dhcp
  }
}
```

### Enterprise WiFi (PEAPv0/EAP-MSCHAPV2)

Protected EAP (PEAP) is a common authentication protocol for enterprise WiFi networks.

```elixir
%{
  type: VintageNetWiFi,
  wifi: %{
    networks: [
      %{
        key_mgmt: :wpa_eap,
        ssid: "my_network_ssid",
        identity: "username",
        password: "password",
        eap: "PEAP",
        phase2: "auth=MSCHAPV2"
      }
    ]
  },
  ipv4: %{method: :dhcp}
}
```

### Enterprise WiFi (EAP-TLS)

TBD
