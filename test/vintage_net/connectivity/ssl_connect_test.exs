defmodule VintageNet.Connectivity.SSLConnectTest do
  use ExUnit.Case, async: true

  alias VintageNet.Connectivity.SSLConnect
  alias VintageNetTest.Utils

  test "connect to known host" do
    ifname = Utils.get_ifname_for_tests()

    assert SSLConnect.connect(ifname, {"google.com", 443}) == :ok
    assert SSLConnect.connect(ifname, {"github.com", 443}) == :ok
    assert SSLConnect.connect(ifname, {"superfakedomain", 443}) == {:error, :nxdomain}
  end
end
