defmodule VintageNet.Connectivity.TCPPingTest do
  use ExUnit.Case, async: true

  alias VintageNet.Connectivity.TCPPing
  alias VintageNetTest.Utils

  test "ping known hosts" do
    ifname = Utils.get_ifname_for_tests()

    assert TCPPing.ping(ifname, {"127.0.0.1", 80}) == :ok
    assert TCPPing.ping(ifname, {"1.1.1.1", 80}) == :ok
    assert TCPPing.ping(ifname, {{1, 1, 1, 1}, 80}) == :ok
  end

  test "ping IP addresses that shouldn't work" do
    ifname = Utils.get_ifname_for_tests()

    # This IP address is in a reserved IP range and shouldn't work
    assert TCPPing.ping(ifname, {"192.0.2.254", 80}) == {:error, :timeout}
  end
end
