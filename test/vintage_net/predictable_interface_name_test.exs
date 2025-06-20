# SPDX-FileCopyrightText: 2020 Connor Rigby
# SPDX-FileCopyrightText: 2020 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.PredictableInterfaceNameTest do
  use ExUnit.Case, async: false

  alias VintageNet.PredictableInterfaceName
  alias VintageNetTest.CapturingInterfaceRenamer

  defp wait_for(predicate, attempts \\ 100)
  defp wait_for(predicate, 0), do: predicate.()
  defp wait_for(predicate, attempts) do
    case predicate.() do
      true ->
        true
      _ ->
        Process.sleep(5)
        wait_for(predicate, attempts - 1)
    end
  end

  doctest PredictableInterfaceName

  test "interface gets renamed" do
    CapturingInterfaceRenamer.clear()
    unpredictable_ifname = "unpredictable0"
    predictable_ifname = "predictable0"
    hw_path = "/not/real/a"

    config = %{
      hw_path: hw_path,
      ifname: predictable_ifname
    }

    start_supervised!({PredictableInterfaceName, [config]})

    # Simulate the interface coming up with the correct hw_path
    PropertyTable.put(VintageNet, ["interface", unpredictable_ifname, "hw_path"], hw_path)

    assert wait_for(fn ->
             Enum.find(CapturingInterfaceRenamer.get(), fn
               {:rename, ^unpredictable_ifname, ^predictable_ifname} -> true
               _ -> false
             end)
           end)
  end

  test "duplicate interfaces don't get renamed" do
    common_path = "/not/real/b"

    config1 = %{
      hw_path: common_path,
      ifname: "duplicate0"
    }

    config2 = %{
      hw_path: common_path,
      ifname: "duplicate1"
    }

    start_supervised!({PredictableInterfaceName, [config1, config2]})

    PropertyTable.put(
      VintageNet,
      ["interface", "unpredictable_duplicate0", "hw_path"],
      config1.hw_path
    )

    PropertyTable.put(
      VintageNet,
      ["interface", "unpredictable_duplicate1", "hw_path"],
      config2.hw_path
    )

    assert wait_for(fn ->
             Enum.find(CapturingInterfaceRenamer.get(), fn
               {:rename, "unpredictable_duplicate0", "duplicate0"} -> true
               _ -> false
             end)
           end)

    # A second interface matching the same hw path as another interface should
    # not be renamed.
    refute Enum.find(CapturingInterfaceRenamer.get(), fn
             {:rename, "unpredictable_duplicate1", "duplicate1"} -> true
             _ -> false
           end)
  end

  test "won't rename virtual interfaces" do
    CapturingInterfaceRenamer.clear()
    unpredictable_ifname = "unpredictableVirtual0"
    predictable_ifname = "predictableVirtual0"
    hw_path = "/devices/virtual"

    config = %{
      hw_path: hw_path,
      ifname: predictable_ifname
    }

    start_supervised!({PredictableInterfaceName, [config]})

    # Simulate the interface coming up with the correct hw_path
    PropertyTable.put(VintageNet, ["interface", unpredictable_ifname, "hw_path"], hw_path)

    refute wait_for(fn ->
             Enum.find(CapturingInterfaceRenamer.get(), fn
               {:rename, ^unpredictable_ifname, ^predictable_ifname} -> true
               _ -> false
             end)
           end)
  end
end
