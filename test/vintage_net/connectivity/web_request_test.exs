defmodule VintageNet.Connectivity.WebRequestTest do
  use ExUnit.Case, async: true

  alias VintageNet.Connectivity.WebRequest
  alias VintageNetTest.Utils

  test "check Microsoft's internet connectivity server" do
    ifname = Utils.get_ifname_for_tests()

    {:ok, normalized_msft_com} =
      WebRequest.normalize(
        {WebRequest,
         url: "http://www.msftconnecttest.com/connecttest.txt", match: "Microsoft Connect Test"}
      )

    assert WebRequest.check(ifname, normalized_msft_com) == {:ok, {:internet, []}}
  end

  test "check whenwhere.nerves-project.org" do
    ifname = Utils.get_ifname_for_tests()

    {:ok, normalized_nerves_project_org} =
      WebRequest.normalize(
        {WebRequest, url: "http://whenwhere.nerves-project.org?nonce=abcd1234"}
      )

    assert WebRequest.check(ifname, normalized_nerves_project_org) == {:ok, {:internet, []}}
  end

  test "check Apple's internet connectivity server" do
    ifname = Utils.get_ifname_for_tests()

    {:ok, normalized_msft_com} =
      WebRequest.normalize(
        {WebRequest,
         url: "http://www.msftconnecttest.com/connecttest.txt", match: "Microsoft Connect Test"}
      )

    assert WebRequest.check(ifname, normalized_msft_com) == {:ok, {:internet, []}}
  end
end
