defmodule VintageNet.ConfigEthTest do
  use ExUnit.Case
  alias VintageNet.Config
  alias VintageNet.Interface.RawConfig
  import VintageNetTest.Utils

  test "create a wired ethernet configuration" do
    input = [
      {"eth0", %{type: :ethernet, ipv4: %{method: :dhcp}}}
    ]

    output = %RawConfig{
      ifname: "eth0",
      files: [
        {"/tmp/network_interfaces.eth0", dhcp_interface("eth0")}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [{:run, "/sbin/ifup", ["-i", "/tmp/network_interfaces.eth0", "eth0"]}],
      down_cmds: [{:run, "/sbin/ifdown", ["-i", "/tmp/network_interfaces.eth0", "eth0"]}]
    }

    assert [output] == Config.make(input, default_opts())
  end

  test "create a wired ethernet configuration with static IP" do
    input = [
      {"eth0",
       %{
         type: :ethernet,
         ipv4: %{
           method: :static,
           addresses: [
             %{address: "192.168.0.2", netmask: "255.255.255.0", gateway: "192.168.0.1"}
           ],
           dns_servers: ["1.1.1.1", "8.8.8.8"],
           search_domains: ["test.net"]
         }
       }}
    ]

    interfaces_content = """
    iface eth0 inet static
      address 192.168.0.2
      netmask 255.255.255.0
      gateway 192.168.0.1
      dns_nameservers 1.1.1.1 8.8.8.8
      dns-search test.net
    """

    output = %RawConfig{
      ifname: "eth0",
      files: [{"/tmp/network_interfaces.eth0", interfaces_content}],
      up_cmd_millis: 60_000,
      up_cmds: [{:run, "/sbin/ifup", ["-i", "/tmp/network_interfaces.eth0", "eth0"]}],
      down_cmds: [{:run, "/sbin/ifdown", ["-i", "/tmp/network_interfaces.eth0", "eth0"]}]
    }

    # TODO!!!!!
    # assert [{"eth0", output}] == Config.make(input, default_opts())
  end

  test "create a dual wired ethernet configuration" do
    input = [
      {"eth0", %{type: :ethernet, ipv4: %{method: :dhcp}}},
      {"eth1", %{type: :ethernet, ipv4: %{method: :dhcp}}}
    ]

    eth0_config = %RawConfig{
      ifname: "eth0",
      files: [
        {"/tmp/network_interfaces.eth0", dhcp_interface("eth0")}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [{:run, "/sbin/ifup", ["-i", "/tmp/network_interfaces.eth0", "eth0"]}],
      down_cmds: [{:run, "/sbin/ifdown", ["-i", "/tmp/network_interfaces.eth0", "eth0"]}]
    }

    eth1_config = %RawConfig{
      ifname: "eth1",
      files: [
        {"/tmp/network_interfaces.eth1", dhcp_interface("eth1")}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [{:run, "/sbin/ifup", ["-i", "/tmp/network_interfaces.eth1", "eth1"]}],
      down_cmds: [{:run, "/sbin/ifdown", ["-i", "/tmp/network_interfaces.eth1", "eth1"]}]
    }

    output = [eth0_config, eth1_config]

    assert output == Config.make(input, default_opts())
  end
end
