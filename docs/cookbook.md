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
VintageNet.configure("eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}})
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
  {:vintage_net_ethernet, "~> 0.8"}
```

### Wired Ethernet with DHCP

This is regular wired Ethernet - nothing fancy:

```elixir
%{type: VintageNetEthernet, ipv4: %{method: :dhcp}}
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
  {:vintage_net_wifi, "~> 0.8"}
```

### Normal password-protected WiFi (WPA2 PSK)

Most password-protected home networks use WPA2 authentication and pre-shared
keys.

```elixir
%{
  type: VintageNetWiFi,
  vintage_net_wifi: %{
    networks: [
      %{
        key_mgmt: :wpa_psk,
        ssid: "my_network_ssid",
        psk: "a_passphrase_or_psk"
      }
    ]
  },
  ipv4: %{method: :dhcp},
}
```

### Enterprise WiFi (PEAPv0/EAP-MSCHAPV2)

Protected EAP (PEAP) is a common authentication protocol for enterprise WiFi networks.

```elixir
%{
  type: VintageNetWiFi,
  vintage_net_wifi: %{
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

### Access point WiFi

Some WiFi modules can be run in access point mode. This makes it possible to
create configuration wizards and captive portals. Configuration of this is more
involved. Here is a basic configuration:

```elixir
%{
  type: VintageNetWiFi,
  vintage_net_wifi: %{
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
}
```

See the
[vintage_net_wizard](https://github.com/nerves-networking/vintage_net_wizard)
for an example of a project that uses AP mode and a web server for WiFi
configuration.

### Bridged Mesh WiFi

In addition to infrastructure and AP modes, some WiFi modules can form a mesh.
VintageNet supports the configuration of [802.11s](https://en.wikipedia.org/wiki/IEEE_802.11s) meshes.
While this is the standardize way of forming WiFi meshes, it is not the same as that implemented
by many access points that advertise WiFi meshing. It also uses the 802.11s routing protocol HWMP. (This is
not B.A.T.M.A.N.).

This section describes two configuration: the first is for the mesh gate and the second is for the mesh
devices. The mesh gate bridges the mesh network to the network that connects to the Internet. Mesh
nodes behave similar to normal clients: after connecting to the network, they request an IP address using
DHCP. The DHCP request gets routed through the mesh gate and to the DHCP server on the non-mesh
LAN. It's possible to have multiple mesh gates. Routing through the mesh and the mesh gate is
transparent.

The following configuration is for a mesh gate with one WiFi interface used for the mesh network and a wired network interface, `eth0`, that connects it to the LAN:

```elixir
mesh0_config = %{
  type: VintageNetWiFi,
  vintage_net_wifi: %{
    user_mpm: 1,
    # mesh creates a "virtual" interface based on
    # this interface name
    root_interface: "wlan0",
    networks: [
      %{
        key_mgmt: :none,
        ssid: "my-mesh",
        frequency: 2432,
        mode: :mesh
      }
    ]
  },
  # we don't need an ip address on the mesh interface
  ipv4: %{method: :disabled},
}

# Bridge configured to bridge eth0 and mesh0 together
br0_config = %{
  type: VintageNetBridge,
  ipv4: %{method: :dhcp},
  vintage_net_bridge: %{
    interfaces: ["eth0", "mesh0"]
  }
}

eth0_config = %{
  type: VintageNetEthernet,
  # the bridge handles ip addressing
  ipv4: %{method: :disabled},
}

VintageNet.configure("mesh0", mesh0_config)
VintageNet.configure("br0", br0_config)
VintageNet.configure("eth0", eth0_config)
```

This configuration is for devices on the mesh:

```elixir
mesh0_config = %{
  type: VintageNetWiFi,
  vintage_net_wifi: %{
    user_mpm: 1,
    # mesh creates a "virtual" interface based on
    # this interface name
    root_interface: "wlan0",
    networks: [
      %{
        key_mgmt: :none,
        ssid: "my-mesh",
        frequency: 2432,
        mode: :mesh
      }
    ]
  },
  # the mesh is bridged on the other
  # device, so we can use dhcp now
  ipv4: %{method: :dhcp},
}
VintageNet.configure("mesh0", mesh0_config)
```

## Network interaction

### Share WAN with other networks

For sharing your WAN connection (e.g. internet access) with other networks
`iptables` must be installed. Currently this means building a [custom nerves
system](https://hexdocs.pm/nerves/customizing-systems.html). Once this is done
the following commands need to be called on each boot:

```elixir
wan = "eth0"
cmd "sysctl -w net.ipv4.ip_forward=1"
cmd "iptables -t nat -A POSTROUTING -o #{wan} -j MASQUERADE"
# Only needed if the connection is blocked otherwise (like a default policy of DROP)
cmd "iptables -A INPUT -i #{wan} -m state --state RELATED,ESTABLISHED -j ACCEPT"
```

## Common tasks

### Temporarily disable WiFi

`VintageNet` persists configurations by default. Sometimes you just want to
disable a network temporarily and then if the device reboots, it reboots to the
old configuration. The `:persist` option let's you do this:

```elixir
VintageNet.deconfigure("wlan0", persist: false)
```

To get the old configuration back, you have to call `VintageNet.configure/3`
with it again (or restart `VintageNet` or reboot).
