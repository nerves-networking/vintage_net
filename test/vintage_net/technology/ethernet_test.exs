defmodule VintageNet.Technology.EthernetTest do
  use ExUnit.Case
  alias VintageNet.Interface.RawConfig
  alias VintageNet.Technology.Ethernet
  import VintageNetTest.Utils

  test "create a wired ethernet configuration" do
    input = %{type: VintageNet.Technology.Ethernet, ipv4: %{method: :dhcp}, hostname: "unit_test"}

    output = %RawConfig{
      ifname: "eth0",
      type: VintageNet.Technology.Ethernet,
      source_config: input,
      child_specs: [
        udhcpc_child_spec("eth0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "eth0"}
      ],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "eth0", "label", "eth0"]},
        {:run, "ip", ["link", "set", "eth0", "down"]}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "eth0", "up"]}]
    }

    assert output == Ethernet.to_raw_config("eth0", input, default_opts())
  end

  test "create a wired ethernet configuration with static IP" do
    input = %{
      type: VintageNet.Technology.Ethernet,
      ipv4: %{
        method: :static,
        address: "192.168.0.2",
        netmask: "255.255.255.0"
      },
      hostname: "unit_test"
    }

    output = %RawConfig{
      type: VintageNet.Technology.Ethernet,
      ifname: "eth0",
      source_config: %{
        hostname: "unit_test",
        type: VintageNet.Technology.Ethernet,
        ipv4: %{
          method: :static,
          address: {192, 168, 0, 2},
          prefix_length: 24
        }
      },
      child_specs: [{VintageNet.Interface.LANConnectivityChecker, "eth0"}],
      down_cmds: [
        {:fun, VintageNet.RouteManager, :clear_route, ["eth0"]},
        {:fun, VintageNet.NameResolver, :clear, ["eth0"]},
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "eth0", "label", "eth0"]},
        {:run, "ip", ["link", "set", "eth0", "down"]}
      ],
      up_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "eth0", "label", "eth0"]},
        {:run, "ip", ["addr", "add", "192.168.0.2/24", "dev", "eth0", "label", "eth0"]},
        {:run, "ip", ["link", "set", "eth0", "up"]},
        {:fun, VintageNet.RouteManager, :clear_route, ["eth0"]},
        {:fun, VintageNet.NameResolver, :clear, ["eth0"]}
      ]
    }

    assert output == Ethernet.to_raw_config("eth0", input, default_opts())
  end

  test "create a dhcpd config" do
    input = %{
      type: VintageNet.Technology.Ethernet,
      ipv4: %{
        method: :static,
        address: "192.168.24.1",
        netmask: "255.255.255.0"
      },
      dhcpd: %{
        start: "192.168.24.2",
        end: "192.168.24.100"
      },
      hostname: "unit_test"
    }

    output = %RawConfig{
      type: VintageNet.Technology.Ethernet,
      ifname: "eth0",
      source_config: %{
        hostname: "unit_test",
        type: VintageNet.Technology.Ethernet,
        ipv4: %{
          method: :static,
          address: {192, 168, 24, 1},
          prefix_length: 24
        },
        dhcpd: %{start: {192, 168, 24, 2}, end: {192, 168, 24, 100}}
      },
      child_specs: [
        {VintageNet.Interface.LANConnectivityChecker, "eth0"},
        %{
          id: :udhcpd,
          restart: :permanent,
          shutdown: 500,
          start:
            {MuonTrap.Daemon, :start_link,
             [
               "udhcpd",
               ["-f", "/tmp/vintage_net/udhcpd.conf.eth0"],
               [stderr_to_stdout: true, log_output: :debug]
             ]},
          type: :worker
        }
      ],
      files: [
        {"/tmp/vintage_net/udhcpd.conf.eth0",
         """
         interface eth0
         pidfile /tmp/vintage_net/udhcpd.eth0.pid
         lease_file /tmp/vintage_net/udhcpd.eth0.leases
         notify_file #{Application.app_dir(:vintage_net, ["priv", "udhcpd_handler"])}

         end 192.168.24.100
         start 192.168.24.2

         """}
      ],
      down_cmds: [
        {:fun, VintageNet.RouteManager, :clear_route, ["eth0"]},
        {:fun, VintageNet.NameResolver, :clear, ["eth0"]},
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "eth0", "label", "eth0"]},
        {:run, "ip", ["link", "set", "eth0", "down"]}
      ],
      up_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "eth0", "label", "eth0"]},
        {:run, "ip", ["addr", "add", "192.168.24.1/24", "dev", "eth0", "label", "eth0"]},
        {:run, "ip", ["link", "set", "eth0", "up"]},
        {:fun, VintageNet.RouteManager, :clear_route, ["eth0"]},
        {:fun, VintageNet.NameResolver, :clear, ["eth0"]}
      ]
    }

    assert output == Ethernet.to_raw_config("eth0", input, default_opts())
  end
end
