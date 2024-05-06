defmodule VintageNet.Connectivity.SSLPingTest do
  use ExUnit.Case, async: true

  alias VintageNet.Connectivity.SSLPing
  alias VintageNetTest.Utils

  test "connect to known host" do
    ifname = Utils.get_ifname_for_tests()

    assert SSLPing.connect(ifname, host: "google.com", port: 443) == :ok
    assert SSLPing.connect(ifname, host: "github.com", port: 443) == :ok
    assert SSLPing.connect(ifname, host: "superfakedomain", port: 443) == {:error, :nxdomain}
  end
end
