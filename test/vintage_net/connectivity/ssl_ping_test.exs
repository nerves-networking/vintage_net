defmodule VintageNet.Connectivity.SSLPingTest do
  use ExUnit.Case, async: true

  alias VintageNet.Connectivity.SSLPing
  alias VintageNetTest.Utils

  test "connect to known host" do
    ifname = Utils.get_ifname_for_tests()

    assert SSLPing.ping(ifname, host: "google.com", port: 443) == :ok
    assert SSLPing.ping(ifname, host: "github.com", port: 443) == :ok
    assert SSLPing.ping(ifname, host: "superfakedomain", port: 443) == {:error, :nxdomain}
  end
end
