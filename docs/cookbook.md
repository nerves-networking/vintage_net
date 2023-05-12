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

Here are example parameters for an static IP address.

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
  ipv4: %{
    method: :static,
    address: "192.168.9.232",
    prefix_length: 24,
    gateway: "192.168.9.1",
    name_servers: ["1.1.1.1"]
  }
}
```

If you're regularly switching between multiple networks, you can list them all
under the `:networks` key. Note that it's currently not possible to mix networks
that require static IP addresses with those that use DHCP.

```elixir
%{
  type: VintageNetWiFi,
  vintage_net_wifi: %{
    networks: [
      %{
        key_mgmt: :wpa_psk,
        ssid: "my_network_ssid",
        psk: "a_passphrase_or_psk"
      },
      %{
        key_mgmt: :wpa_psk,
        ssid: "another_ssid",
        psk: "a_passphrase_or_psk"
      },
      ...
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

### Hidden WiFi networks

If the access point has been configured to not advertise a network, VintageNetWiFi won't find it. It has to explicitly be told to search for
it. Add `scan_ssid: 1` to the configuration to do this. For example,

```elixir
%{
  type: VintageNetWiFi,
  vintage_net_wifi: %{
    networks: [
      %{
        key_mgmt: :wpa_psk,
        ssid: "my_network_ssid",
        psk: "a_passphrase_or_psk",
        scan_ssid: 1
      }
    ]
  },
  ipv4: %{method: :dhcp},
}
```

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
    end: "192.168.24.10",
    options: %{
      dns: ["1.1.1.1", "1.0.0.1"],
      subnet: "255.255.255.0",
      router: ["192.168.24.1"]
    }
  }
}
```

If you want to use WPA2 on your access point, make the networks map look like
this:

```elixir
  %{
    mode: :ap,
    key_mgmt: :wpa_psk,
    proto: "RSN",
    pairwise: "CCMP",
    group: "CCMP",
    ssid: "test ssid",
    psk: "secret123"
  }
```

The `proto: "RSN"` entry is important since the `wpa_supplicant` default is
`WPA` and not `WPA2`.

See the
[vintage_net_wizard](https://github.com/nerves-networking/vintage_net_wizard)
for an example of a project that uses AP mode and a web server for WiFi
configuration.

### Advanced Use of WPA Supplicant

VintageNetWifi supports an "escape hatch" of sorts if you need precise control over the contents of the supplicant configuration.
The contents of the `wpa_supplicant_conf` will be coppied without validation to the wpa_supplicant.conf file that
VintageNet manages. Example:

```elixir
%{
  type: VintageNetWiFi,
  vintage_net_wifi: %{
    wpa_supplicant_conf: """
    network={
      ssid="home"
      key_mgmt=WPA-PSK
      psk="very secret passphrase"
    }
    """
  },
  ipv4: %{method: :dhcp}
}
```

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
cmd "iptables --append FORWARD --in-interface wlan0 -j ACCEPT"
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

### Perform some initialization to turn on a network interface

`VintageNet` waits for network interfaces to appear before doing any work.  If
you need to perform some work to make the network interface show up, that has to
be done elsewhere. If you let `VintageNet` know about this work and allow it to
turn the network interface off too, it can "cycle power" to the interface to get
it back to a clean state when needed. Here's how:

```elixir
defmodule MyPowerManager do
  @behaviour VintageNet.PowerManager

  @reset_n_gpio 4
  @power_on_hold_time 5 * 60000
  @min_powered_off_time 5000

  defstruct reset_n: nil

  @impl VintageNet.PowerManager
  def init(_args) do
    {:ok, reset_n} = Circuits.GPIO.open(@reset_n_gpio, :output)
    {:ok, %__MODULE__{reset_n: reset_n}}
  end

  @impl VintageNet.PowerManager
  def power_on(state) do
    # Do whatever is necessary to turn the network interface on
    Circuits.GPIO.write(state.reset_n, 1)
    {:ok, state, @power_on_hold_time}
  end

  @impl VintageNet.PowerManager
  def start_powering_off(state) do
    # If there's a graceful power off, start it here and return
    # the max time it takes.
    {:ok, state, 0}
  end

  @impl VintageNet.PowerManager
  def power_off(state) do
    # Disable the network interface
    Circuits.GPIO.write(state.reset_n, 0)
    {:ok, state, @min_powered_off_time}
  end
```

Then add the following to your `config.exs`:

```elixir
config :vintage_net, power_managers: [{MyPowerManager, ifname: "wlan0"}]
```

VintageNet determines whether devices are ok by use of a watchdog. VintageNet
and its technology implementations pet the watchdog by calling
`VintageNet.PowerManager.PMControl.pet_watchdog/1`. This may be insufficient for
your application. Options include calling that function in your code regularly
or modifying the `:watchdog_timeout` in the power manager spec in your
`config.exs`.

See `VintageNet.PowerManager` for details.
