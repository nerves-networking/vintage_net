defmodule VintageNet.Connectivity.HTTPTest do
  use ExUnit.Case, async: true

  alias VintageNet.Connectivity.HTTP
  alias VintageNetTest.Utils

  test "ping known hosts" do
    ifname = Utils.get_ifname_for_tests()

    normalized_nerves_project_org =
      HTTP.normalize(
        {HTTP, host: "ping.nerves-project.org", port: 80, path: "/", nonce: "abcd1234"}
      )

    assert HTTP.check(ifname, normalized_nerves_project_org) == {:ok, :internet}

    normalized_msftconnecttest_com =
      HTTP.normalize(
        {HTTP,
         host: "www.msftconnecttest.com",
         port: 80,
         path: "/connecttest.txt",
         match: "Microsoft Connect Test"}
      )

    assert HTTP.check(ifname, normalized_msftconnecttest_com) == {:ok, :internet}
  end
end
