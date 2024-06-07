defmodule VintageNet.Connectivity.WhenWhereTest do
  use ExUnit.Case, async: true

  alias VintageNet.Connectivity.WhenWhere
  alias VintageNetTest.Utils

  test "when/where" do
    ifname = Utils.get_ifname_for_tests()

    {:ok, normalized_whenwhere} =
      WhenWhere.normalize({WhenWhere, url: "http://whenwhere.nerves-project.org"})

    assert {:ok, {:internet, properties}} = WhenWhere.check(ifname, normalized_whenwhere)

    assert Enum.find(properties, fn
             {["timestamp"], _} -> true
             _ -> false
           end)
  end
end