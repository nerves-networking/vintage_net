# SPDX-FileCopyrightText: 2019 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.IP.IPv4ConfigTest do
  use ExUnit.Case
  import VintageNetTest.Utils

  alias VintageNet.IP.IPv4Config

  test "raises if no method" do
    assert_raise ArgumentError, fn -> IPv4Config.normalize(%{ipv4: %{}}) end
  end

  test "ipv4 disabled default" do
    default_config = %{ipv4: %{method: :disabled}}

    assert default_config == IPv4Config.normalize(%{ipv4: %{method: :disabled}})
  end

  test "ipv4 dhcp default" do
    default_config = %{ipv4: %{method: :dhcp}}

    assert default_config == IPv4Config.normalize(%{ipv4: %{method: :dhcp}})
  end

  test "ipv4 static default" do
    default_config = %{
      ipv4: %{
        method: :static,
        address: {192, 168, 1, 1},
        prefix_length: 24
      }
    }

    assert default_config ==
             IPv4Config.normalize(%{
               ipv4: %{method: :static, address: "192.168.1.1", netmask: "255.255.255.0"}
             })
  end

  test "ipv4 normalizes static" do
    config = %{
      ipv4: %{
        method: :static,
        address: "192.168.1.2",
        prefix_length: 24,
        gateway: "192.168.1.1",
        name_servers: ["1.1.1.1", {8, 8, 8, 8}],
        domain: "example.com"
      }
    }

    normalized_config = %{
      ipv4: %{
        method: :static,
        address: {192, 168, 1, 2},
        prefix_length: 24,
        gateway: {192, 168, 1, 1},
        name_servers: [{1, 1, 1, 1}, {8, 8, 8, 8}],
        domain: "example.com"
      }
    }

    assert normalized_config == IPv4Config.normalize(config)
  end

  test "ipv4 dhcp configs" do
    input =
      %{
        hostname: "unit_test",
        ipv4: %{
          method: :dhcp
        }
      }
      |> IPv4Config.normalize()

    initial_raw_config = %VintageNet.Interface.RawConfig{
      ifname: "eth0",
      source_config: input,
      type: UnitTest,
      required_ifnames: ["eth0"]
    }

    expected = %VintageNet.Interface.RawConfig{
      type: UnitTest,
      ifname: "eth0",
      source_config: input,
      required_ifnames: ["eth0"],
      child_specs: [
        udhcpc_child_spec("eth0", "unit_test"),
        {VintageNet.Connectivity.InternetChecker, "eth0"}
      ],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "eth0", "label", "eth0"]},
        {:run, "ip", ["link", "set", "eth0", "down"]}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "eth0", "up"]}]
    }

    assert expected == IPv4Config.add_config(initial_raw_config, input, default_opts())
  end

  test "ipv4 dhcp default normalizes without :dhcp_request_options" do
    # Unspecified :dhcp_request_options should round-trip as a bare :dhcp config,
    # not gain an empty list — preserves the existing normalized shape.
    assert %{ipv4: %{method: :dhcp}} ==
             IPv4Config.normalize(%{ipv4: %{method: :dhcp}})
  end

  test "ipv4 dhcp preserves :dhcp_request_options through normalize" do
    assert %{ipv4: %{method: :dhcp, dhcp_request_options: ["wpad", "sipsrv"]}} ==
             IPv4Config.normalize(%{
               ipv4: %{method: :dhcp, dhcp_request_options: ["wpad", "sipsrv"]}
             })
  end

  test "ipv4 dhcp rejects non-string entries in :dhcp_request_options" do
    assert_raise ArgumentError, fn ->
      IPv4Config.normalize(%{ipv4: %{method: :dhcp, dhcp_request_options: [:wpad]}})
    end
  end

  test "ipv4 dhcp rejects non-list :dhcp_request_options" do
    assert_raise ArgumentError, fn ->
      IPv4Config.normalize(%{ipv4: %{method: :dhcp, dhcp_request_options: "wpad"}})
    end
  end

  test "ipv4 dhcp emits -O args when :dhcp_request_options is set" do
    input =
      %{
        hostname: "unit_test",
        ipv4: %{method: :dhcp, dhcp_request_options: ["wpad"]}
      }
      |> IPv4Config.normalize()

    initial_raw_config = %VintageNet.Interface.RawConfig{
      ifname: "eth0",
      source_config: input,
      type: UnitTest,
      required_ifnames: ["eth0"]
    }

    expected = %VintageNet.Interface.RawConfig{
      type: UnitTest,
      ifname: "eth0",
      source_config: input,
      required_ifnames: ["eth0"],
      child_specs: [
        udhcpc_child_spec("eth0", "unit_test", ["wpad"]),
        {VintageNet.Connectivity.InternetChecker, "eth0"}
      ],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "eth0", "label", "eth0"]},
        {:run, "ip", ["link", "set", "eth0", "down"]}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "eth0", "up"]}]
    }

    assert expected == IPv4Config.add_config(initial_raw_config, input, default_opts())
  end

  test "ipv4 static config with a default gateway" do
    input =
      %{
        hostname: "unit_test",
        ipv4: %{
          method: :static,
          address: {192, 168, 1, 2},
          prefix_length: 24,
          gateway: {192, 168, 1, 1},
          name_servers: [{1, 1, 1, 1}, {8, 8, 8, 8}],
          domain: "example.com"
        }
      }
      |> IPv4Config.normalize()

    initial_raw_config = %VintageNet.Interface.RawConfig{
      ifname: "eth0",
      source_config: input,
      required_ifnames: ["eth0"],
      type: UnitTest
    }

    expected = %VintageNet.Interface.RawConfig{
      type: UnitTest,
      ifname: "eth0",
      source_config: input,
      required_ifnames: ["eth0"],
      child_specs: [
        {VintageNet.Connectivity.InternetChecker, "eth0"}
      ],
      down_cmds: [
        {:fun, VintageNet.RouteManager, :clear_route, ["eth0"]},
        {:fun, VintageNet.NameResolver, :clear, ["eth0"]},
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "eth0", "label", "eth0"]},
        {:run, "ip", ["link", "set", "eth0", "down"]}
      ],
      up_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "eth0", "label", "eth0"]},
        {:run, "ip",
         [
           "addr",
           "add",
           "192.168.1.2/24",
           "dev",
           "eth0",
           "broadcast",
           "192.168.1.255",
           "label",
           "eth0"
         ]},
        {:run, "ip", ["link", "set", "eth0", "up"]},
        {:fun, VintageNet.RouteManager, :set_route,
         ["eth0", [{{192, 168, 1, 2}, 24}], {192, 168, 1, 1}]},
        {:fun, VintageNet.NameResolver, :setup,
         ["eth0", "example.com", [{1, 1, 1, 1}, {8, 8, 8, 8}]]}
      ]
    }

    assert expected == IPv4Config.add_config(initial_raw_config, input, default_opts())
  end

  test "ipv4 static config without a default gateway" do
    input =
      %{
        hostname: "unit_test",
        ipv4: %{
          method: :static,
          address: {192, 168, 1, 2},
          prefix_length: 24
        }
      }
      |> IPv4Config.normalize()

    initial_raw_config = %VintageNet.Interface.RawConfig{
      ifname: "eth0",
      source_config: input,
      required_ifnames: ["eth0"],
      type: UnitTest
    }

    expected = %VintageNet.Interface.RawConfig{
      type: UnitTest,
      ifname: "eth0",
      source_config: input,
      required_ifnames: ["eth0"],
      child_specs: [
        {VintageNet.Connectivity.LANChecker, "eth0"}
      ],
      down_cmds: [
        {:fun, VintageNet.RouteManager, :clear_route, ["eth0"]},
        {:fun, VintageNet.NameResolver, :clear, ["eth0"]},
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "eth0", "label", "eth0"]},
        {:run, "ip", ["link", "set", "eth0", "down"]}
      ],
      up_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "eth0", "label", "eth0"]},
        {:run, "ip",
         [
           "addr",
           "add",
           "192.168.1.2/24",
           "dev",
           "eth0",
           "broadcast",
           "192.168.1.255",
           "label",
           "eth0"
         ]},
        {:run, "ip", ["link", "set", "eth0", "up"]},
        {:fun, VintageNet.RouteManager, :clear_route, ["eth0"]},
        {:fun, VintageNet.NameResolver, :clear, ["eth0"]}
      ]
    }

    assert expected == IPv4Config.add_config(initial_raw_config, input, default_opts())
  end

  test "ipv4 static config with one name server" do
    input =
      %{
        hostname: "unit_test",
        ipv4: %{
          method: :static,
          address: {192, 168, 1, 2},
          prefix_length: 24,
          name_servers: "1.2.3.4"
        }
      }
      |> IPv4Config.normalize()

    initial_raw_config = %VintageNet.Interface.RawConfig{
      ifname: "eth0",
      source_config: input,
      required_ifnames: ["eth0"],
      type: UnitTest
    }

    expected = %VintageNet.Interface.RawConfig{
      type: UnitTest,
      ifname: "eth0",
      source_config: input,
      required_ifnames: ["eth0"],
      child_specs: [
        {VintageNet.Connectivity.LANChecker, "eth0"}
      ],
      down_cmds: [
        {:fun, VintageNet.RouteManager, :clear_route, ["eth0"]},
        {:fun, VintageNet.NameResolver, :clear, ["eth0"]},
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "eth0", "label", "eth0"]},
        {:run, "ip", ["link", "set", "eth0", "down"]}
      ],
      up_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "eth0", "label", "eth0"]},
        {:run, "ip",
         [
           "addr",
           "add",
           "192.168.1.2/24",
           "dev",
           "eth0",
           "broadcast",
           "192.168.1.255",
           "label",
           "eth0"
         ]},
        {:run, "ip", ["link", "set", "eth0", "up"]},
        {:fun, VintageNet.RouteManager, :clear_route, ["eth0"]},
        {:fun, VintageNet.NameResolver, :setup, ["eth0", nil, [{1, 2, 3, 4}]]}
      ]
    }

    assert expected == IPv4Config.add_config(initial_raw_config, input, default_opts())
  end

  test "raises on invalid mask" do
    config = %{
      ipv4: %{
        method: :static,
        address: {192, 168, 1, 1},
        netmask: :not_a_mask
      }
    }

    assert_raise ArgumentError, fn -> IPv4Config.normalize(config) end
  end
end
