# SPDX-FileCopyrightText: 2020 Connor Rigby
# SPDX-FileCopyrightText: 2020 Frank Hunleth
# SPDX-FileCopyrightText: 2026 Cocoa Xu
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.PredictableInterfaceNameTest do
  use ExUnit.Case, async: false

  alias VintageNet.PredictableInterfaceName
  alias VintageNetTest.CapturingInterfaceRenamer

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
    Process.sleep(5)

    assert Enum.find(CapturingInterfaceRenamer.get(), fn
             {:rename, ^unpredictable_ifname, ^predictable_ifname} -> true
             _ -> false
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

    Process.sleep(5)

    assert Enum.find(CapturingInterfaceRenamer.get(), fn
             {:rename, "unpredictable_duplicate0", "duplicate0"} -> true
             _ -> false
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
    Process.sleep(5)

    refute Enum.find(CapturingInterfaceRenamer.get(), fn
             {:rename, ^unpredictable_ifname, ^predictable_ifname} -> true
             _ -> false
           end)
  end

  test "precheck allows a built-in name only when its rule opts in" do
    Application.put_env(:vintage_net, :ifnames, [
      %{ifname: "ethpc0", hw_path: "/devices/pci0000:00/0000:25:00.0", allow_built_in: true},
      %{ifname: "ethdev0", hw_path: "/devices/pci0000:00/0000:23:00.0"}
    ])

    on_exit(fn -> Application.delete_env(:vintage_net, :ifnames) end)

    assert PredictableInterfaceName.precheck("ethpc0") == :ok
    assert PredictableInterfaceName.precheck("lan0") == :ok

    assert PredictableInterfaceName.precheck("ethdev0") ==
             {:error, :not_predictable_interface_name}

    assert PredictableInterfaceName.precheck("eth0") == {:error, :not_predictable_interface_name}
  end
end
