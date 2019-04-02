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
      ifup: "/sbin/ifup",
      ifdown: "/sbin/ifdown",
      killall: "/usr/bin/killall",
      ifup: "/sbin/ifup",
      ifdown: "/sbin/ifdown"
    ]
  end

  test "create a wired ethernet configuration" do
    input = [
      {"eth0", %{type: :ethernet, ipv4: %{method: :dhcp}}}
    ]

    output = %{
      network_interfaces: "iface eth0 inet dhcp",
      up_cmds: ["/sbin/ifup -i /tmp/network_interfaces eth0"],
      down_cmds: ["/sbin/ifdown -i /tmp/network_interfaces eth0"]
    }

    assert output == Config.make(input, default_opts())
  end

  test "create a wired ethernet configuration with static IP" do
    input = [
      {"eth0",
       %{
         type: :ethernet,
         ipv4: %{
           method: :manual,
           addresses: [
             %{address: "192.168.0.2", netmask: "255.255.255.0", gateway: "192.168.0.1"}
           ],
           dns_servers: ["1.1.1.1", "8.8.8.8"],
           search_domains: ["test.net"]
         }
       }}
    ]

    output = %{
      network_interfaces: "iface eth0 inet dhcp",
      up_cmds: ["/sbin/ifup -i /tmp/network_interfaces eth0"],
      down_cmds: ["/sbin/ifdown -i /tmp/network_interfaces eth0"]
    }

    assert output == Config.make(input, default_opts())
  end

  test "create a dual wired ethernet configuration" do
    input = [
      {"eth0", %{type: :ethernet, ipv4: %{method: :dhcp}}},
      {"eth1", %{type: :ethernet, ipv4: %{method: :dhcp}}}
    ]

    output = %{
      network_interfaces: """
      iface eth0 inet dhcp
      iface eth1 inet dhcp
      """,
      up_cmds: ["/sbin/ifup -i /tmp/network_interfaces eth0 eth1"],
      down_cmds: ["/sbin/ifdown -i /tmp/network_interfaces eth0 eth1"]
    }

    assert output == Config.make(input, default_opts())
  end
end
