# SPDX-FileCopyrightText: 2019 Frank Hunleth
# SPDX-FileCopyrightText: 2019 Matt Ludwigs
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.Connectivity.LANCheckerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  alias VintageNet.Connectivity.LANChecker
  alias VintageNetTest.Utils

  test "disconnected interface" do
    property = ["interface", "disconnected_interface2", "connection"]
    VintageNet.subscribe(property)

    start_supervised!({LANChecker, "disconnected_interface2"})

    assert_receive {VintageNet, ^property, _old_value, :disconnected, _meta}, 1_000
  end

  @tag :requires_interfaces_monitor
  test "lan connected interface" do
    # Start clean slate since this test uses a real network interface
    capture_log(fn ->
      Application.stop(:vintage_net)
      Application.start(:vintage_net)
    end)

    ifname = Utils.get_ifname_for_tests()
    property = ["interface", ifname, "connection"]
    VintageNet.subscribe(property)

    start_supervised!({LANChecker, ifname})

    assert_receive {VintageNet, ^property, _old_value, :lan, _meta}, 1_000
    refute_receive {VintageNet, ^property, _old_value, :internet, _meta}
  end

  test "deprecation warning when using old LANConnectivityChecker" do
    messages =
      capture_log(fn ->
        start_supervised!(
          {VintageNet.Interface.LANConnectivityChecker, Utils.get_ifname_for_tests()}
        )
      end)

    assert messages =~
             "VintageNet.Interface.LANConnectivityChecker is now VintageNet.Connectivity.LANChecker"
  end
end
