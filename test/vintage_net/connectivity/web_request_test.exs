defmodule VintageNet.Connectivity.WebRequestTest do
  use ExUnit.Case, async: true

  alias VintageNet.Connectivity.WebRequest
  alias VintageNetTest.Utils

  test "ping known hosts" do
    ifname = Utils.get_ifname_for_tests()

    normalized_nerves_project_org =
      WebRequest.normalize(
        {WebRequest, host: "ping.nerves-project.org", port: 80, path: "/", nonce: "abcd1234"}
      )

    assert WebRequest.check(ifname, normalized_nerves_project_org) == {:ok, :internet}

    normalized_msftconnecttest_com =
      WebRequest.normalize(
        {WebRequest,
         host: "www.msftconnecttest.com",
         port: 80,
         path: "/connecttest.txt",
         match: "Microsoft Connect Test"}
      )

    assert WebRequest.check(ifname, normalized_msftconnecttest_com) == {:ok, :internet}
  end
end
