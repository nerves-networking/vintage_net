defmodule VintageNet.Connectivity.TCPPingTest do
  use ExUnit.Case, async: true

  alias VintageNet.Connectivity.TCPPing
  alias VintageNetTest.Utils

  test "ping IPv4 known hosts" do
    ifname = Utils.get_ifname_for_tests()

    assert TCPPing.ping(ifname, host: "127.0.0.1", port: 80) == :ok
    assert TCPPing.ping(ifname, host: "1.1.1.1", port: 53) == :ok
  end

  # If this fails and your LAN doesn't support IPv6, run "mix test --exclude requires_ipv6"
  @tag :requires_ipv6
  test "ping IPv6 known hosts" do
    ifname = Utils.get_ifname_for_tests()

    assert TCPPing.ping(ifname, host: "::1", port: 80) == :ok
    assert TCPPing.ping(ifname, host: "2606:4700:4700::1111", port: 53) == :ok
  end

  test "ping internet_host_list" do
    ifname = Utils.get_ifname_for_tests()

    # While these won't work for everyone, they should work on CI
    for {:tcp_ping, opts} <- Application.fetch_env!(:vintage_net, :internet_host_list) do
      assert TCPPing.ping(ifname, opts) == :ok
    end
  end

  test "ping IP addresses that shouldn't work" do
    ifname = Utils.get_ifname_for_tests()

    # This IP address is in a reserved IP range and shouldn't work
    assert TCPPing.ping(ifname, host: "192.0.2.254", port: 80) == {:error, :timeout}
  end
end
