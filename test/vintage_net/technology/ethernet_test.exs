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
        netmask: "255.255.255.0",
        gateway: "192.168.0.1"
      },
      hostname: "unit_test"
    }

    # Static IP support is not implemented. This is what is currently produced,
    # but it is incomplete.
    output = %RawConfig{
      type: VintageNet.Technology.Ethernet,
      ifname: "eth0",
      source_config: %{
        hostname: "unit_test",
        type: VintageNet.Technology.Ethernet,
        ipv4: %{method: :static, address: {192, 168, 0, 2}, prefix_length: 24}
      },
      child_specs: [{VintageNet.Interface.LANConnectivityChecker, "eth0"}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "eth0", "label", "eth0"]},
        {:run, "ip", ["link", "set", "eth0", "down"]}
      ],
      up_cmds: [
        {:run, "ip", ["addr", "add", "192.168.0.2/24", "dev", "eth0", "label", "eth0"]},
        {:run, "ip", ["link", "set", "eth0", "up"]}
      ]
    }

    assert output == Ethernet.to_raw_config("eth0", input, default_opts())
  end
end
