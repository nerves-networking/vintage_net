defmodule VintageNet.PredictableInterfaceNameTest do
  use ExUnit.Case
  alias VintageNet.PropertyTable
  alias VintageNet.PredictableInterfaceName
  alias VintageNetTest.CapturingInterfaceRenamer

  test "interface gets renamed" do
    CapturingInterfaceRenamer.clear()
    unpredictable_ifname = "unpredictable0"
    predictable_ifname = "predictable0"
    hw_path = "/not/real"

    config = %{
      hw_path: hw_path,
      ifname: predictable_ifname
    }

    start_supervised!({PredictableInterfaceName, [config]})

    # simulates the interface coming up with the correct hw_path
    PropertyTable.put(VintageNet, ["interface", unpredictable_ifname, "hw_path"], hw_path)
    Process.sleep(5)

    assert Enum.find(CapturingInterfaceRenamer.get(), fn
             {:rename, ^unpredictable_ifname, ^predictable_ifname} -> true
             _ -> false
           end)
  end
end
