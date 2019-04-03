defmodule VintageNet.ConfigEthTest do
  use ExUnit.Case
  alias VintageNet.Config

  defp default_opts() do
    [
      network_interfaces: "/tmp/network_interfaces",
      tmpdir: "/tmp",
      wpa_supplicant_conf: "/tmp/wpa_supplicant.conf",
      wpa_supplicant_control: "/tmp/foo",
      ifup: "/sbin/ifup",
      ifdown: "/sbin/ifdown",
      chat_bin: "/usr/sbin/chat",
      pppd: "/usr/sbin/pppd",
      mknod: "/bin/mknod",
      killall: "/usr/bin/killall"
    ]
  end

  test "create a wired ethernet configuration" do
    input = [
      {"eth0", %{type: :ethernet, ipv4: %{method: :dhcp}}}
    ]

    output = %{
      files: [{"/tmp/network_interfaces.eth0", "iface eth0 inet dhcp"}],
      up_cmds: [{:run, "/sbin/ifup", ["-i", "/tmp/network_interfaces.eth0", "eth0"]}],
      down_cmds: [{:run, "/sbin/ifdown", ["-i", "/tmp/network_interfaces.eth0", "eth0"]}]
    }

    assert [{"eth0", output}] == Config.make(input, default_opts())
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

    output = %{
      files: [{"/tmp/network_interfaces.eth0", interfaces_content}],
      up_cmds: [{:run, "/sbin/ifup", ["-i", "/tmp/network_interfaces.eth0", "eth0"]}],
      down_cmds: [{:run, "/sbin/ifdown", ["-i", "/tmp/network_interfaces.eth0", "eth0"]}]
    }

    assert [{"eth0", output}] == Config.make(input, default_opts())
  end

  test "create a dual wired ethernet configuration" do
    input = [
      {"eth0", %{type: :ethernet, ipv4: %{method: :dhcp}}},
      {"eth1", %{type: :ethernet, ipv4: %{method: :dhcp}}}
    ]

    eth0_config = %{
      files: [{"/tmp/network_interfaces.eth0", "iface eth0 inet dhcp"}],
      up_cmds: [{:run, "/sbin/ifup", ["-i", "/tmp/network_interfaces.eth0", "eth0"]}],
      down_cmds: [{:run, "/sbin/ifdown", ["-i", "/tmp/network_interfaces.eth0", "eth0"]}]
    }

    eth1_config = %{
      files: [{"/tmp/network_interfaces.eth1", "iface eth1 inet dhcp"}],
      up_cmds: [{:run, "/sbin/ifup", ["-i", "/tmp/network_interfaces.eth1", "eth1"]}],
      down_cmds: [{:run, "/sbin/ifdown", ["-i", "/tmp/network_interfaces.eth1", "eth1"]}]
    }

    output = [
      {"eth0", eth0_config},
      {"eth1", eth1_config}
    ]

    assert output == Config.make(input, default_opts())
  end
end
