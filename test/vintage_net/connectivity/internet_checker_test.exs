# SPDX-FileCopyrightText: 2019 Frank Hunleth
# SPDX-FileCopyrightText: 2019 Matt Ludwigs
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.Connectivity.InternetCheckerTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias VintageNet.Connectivity.InternetChecker
  alias VintageNetTest.Utils

  test "disconnected interface" do
    ifname = "disconnected_interface"
    property = ["interface", ifname, "connection"]
    lower_up = ["interface", ifname, "lower_up"]

    # Set up
    PropertyTable.delete(VintageNet, property)
    PropertyTable.delete(VintageNet, lower_up)
    VintageNet.subscribe(property)

    start_supervised!({InternetChecker, ifname})

    assert_receive {VintageNet, ^property, _old_value, :disconnected, _meta}, 1_000
  end

  @tag :requires_interfaces_monitor
  test "internet connected interface" do
    # Start clean slate since this test uses a real network interface
    capture_log(fn ->
      Application.stop(:vintage_net)
      Application.start(:vintage_net)
    end)

    ifname = Utils.get_ifname_for_tests()
    property = ["interface", ifname, "connection"]
    lower_up = ["interface", ifname, "lower_up"]

    # Set up a situation where the InternetChecker will see take a guess that
    # the connection is disconnected and then fix it self when it sees the
    # lower_up being true and then detect the internet.
    PropertyTable.put(VintageNet, property, :disconnected)
    PropertyTable.put(VintageNet, lower_up, true)

    VintageNet.subscribe(property)

    start_supervised!({InternetChecker, ifname})

    assert_receive {VintageNet, ^property, _old_value, :lan, _meta}, 1_000
    assert_receive {VintageNet, ^property, _old_value, :internet, _meta}, 1_000
  end

  @tag :requires_interfaces_monitor
  test "internet goes away" do
    ifname = "disconnected"
    property = ["interface", ifname, "connection"]
    lower_up = ["interface", ifname, "lower_up"]

    # Set up a situation where the InternetChecker will start with thinking the
    # internet is connected, but then change its mind when the interface goes away.
    PropertyTable.put(VintageNet, property, :internet)
    PropertyTable.put(VintageNet, lower_up, true)

    VintageNet.subscribe(property)

    start_supervised!({InternetChecker, ifname})

    Process.sleep(250)
    PropertyTable.put(VintageNet, lower_up, false)
    assert_receive {VintageNet, ^property, _old_value, :disconnected, _meta}, 1_000
  end

  test "deprecation warning when using old InternetConnectivityChecker" do
    messages =
      capture_log(fn ->
        start_supervised!(
          {VintageNet.Interface.InternetConnectivityChecker, Utils.get_ifname_for_tests()}
        )
      end)

    assert messages =~
             "VintageNet.Interface.InternetConnectivityChecker is now VintageNet.Connectivity.InternetChecker"
  end
end
