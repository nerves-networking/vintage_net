defmodule VintageNet.InterfacesMonitor.InfoTest do
  use ExUnit.Case
  doctest VintageNet.InterfacesMonitor.Info
  alias VintageNet.InterfacesMonitor.Info

  test "new interfaces don't have link information or addresses" do
    info = Info.new("eth0")
    assert info == %VintageNet.InterfacesMonitor.Info{addresses: [], ifname: "eth0", link: %{}}
  end

  test "newlink reports replace the link information" do
    info = Info.new("eth0")
    before_info = Info.newlink(info, example_link_report("before_mac", true))
    after_info = Info.newlink(before_info, example_link_report("after_mac", true))

    assert before_info.link == example_link_report("before_mac", true)
    assert after_info.link == example_link_report("after_mac", true)
  end

  test "newaddr and deladdr" do
    info = Info.new("eth0")

    info = Info.newaddr(info, example_ipv4_report(1))
    assert info.addresses == [example_ipv4_report(1)]

    info = Info.deladdr(info, example_ipv4_report(1))
    assert info.addresses == []
  end

  test "multiple addresses" do
    info =
      Info.new("eth0")
      |> Info.newaddr(example_ipv4_report(1))
      |> Info.newaddr(example_ipv4_report(2))
      |> Info.newaddr(example_ipv4_report(3))
      |> Info.newaddr(example_ipv6_report(4))
      |> Info.newaddr(example_ipv6_report(5))
      |> Info.deladdr(example_ipv4_report(2))

    assert info.addresses == [
             example_ipv6_report(5),
             example_ipv6_report(4),
             example_ipv4_report(3),
             example_ipv4_report(1)
           ]
  end

  test "removing all ipv4" do
    info =
      Info.new("eth0")
      |> Info.newaddr(example_ipv4_report(1))
      |> Info.newaddr(example_ipv4_report(2))
      |> Info.newaddr(example_ipv4_report(3))
      |> Info.newaddr(example_ipv6_report(4))
      |> Info.newaddr(example_ipv6_report(5))
      |> Info.delete_ipv4_addresses()

    assert info.addresses == [
             example_ipv6_report(5),
             example_ipv6_report(4)
           ]
  end

  defp example_link_report(mac_address, up) do
    %{
      broadcast: true,
      lower_up: true,
      mac_address: mac_address,
      mac_broadcast: "ff:ff:ff:ff:ff:ff",
      mtu: 1500,
      multicast: true,
      operstate: :down,
      running: false,
      stats: %{
        collisions: 0,
        multicast: 0,
        rx_bytes: 0,
        rx_dropped: 0,
        rx_errors: 0,
        rx_packets: 0,
        tx_bytes: 0,
        tx_dropped: 0,
        tx_errors: 0,
        tx_packets: 0
      },
      type: :ethernet,
      up: up
    }
  end

  defp example_ipv4_report(index) when index > 0 and index < 255 do
    %{
      address: {192, 168, 10, index},
      broadcast: {192, 168, 10, 255},
      family: :inet,
      label: "eth0",
      local: {192, 168, 10, 10},
      permanent: false,
      prefixlen: 24,
      scope: :universe
    }
  end

  defp example_ipv6_report(index) when index > 0 and index < 65535 do
    %{
      address: {65152, 0, 0, 0, 45461, 64234, 43649, index},
      family: :inet6,
      permanent: true,
      prefixlen: 64,
      scope: :link
    }
  end
end
