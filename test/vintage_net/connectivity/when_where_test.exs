defmodule VintageNet.Connectivity.WhenWhereTest do
  use ExUnit.Case, async: true

  alias VintageNet.Connectivity.WhenWhere
  alias VintageNetTest.Utils

  @properties [
    ["address"],
    ["city"],
    ["country"],
    ["country_region"],
    ["latitude"],
    ["longitude"],
    ["now"],
    ["time_zone"]
  ]

  # If this fails it may be because whenwhere is down or doesn't support your network.
  # run "mix test --exclude whenwhere"
  @tag :whenwhere
  test "when/where" do
    ifname = Utils.get_ifname_for_tests()

    {:ok, normalized_whenwhere} =
      WhenWhere.normalize({WhenWhere, url: "http://whenwhere.nerves-project.org"})

    assert {:ok, {:internet, properties}} = WhenWhere.check(ifname, normalized_whenwhere)

    for property <- @properties do
      assert Enum.find(properties, fn
               {^property, _} -> true
               _ -> false
             end)
    end
  end
end
