defmodule VintageNet.Connectivity.InternetCheckerTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias VintageNet.Connectivity.InternetChecker
  alias VintageNetTest.Utils

  test "rotate_list/1" do
    assert [1] == InternetChecker.rotate_list([1])
    assert [2, 1] == InternetChecker.rotate_list([1, 2])
    assert [2, 3, 1] == InternetChecker.rotate_list([1, 2, 3])
    assert [] == InternetChecker.rotate_list([])
  end

  describe "connected?/2" do
    test "when internet is available" do
      assert true == InternetChecker.connected?(:available, %{})
    end

    test "when DNS cannot be resolved for domain" do
      domain = "fake.domain.name.com.io.vintage.net"
      state = %{hosts: [{domain, 80}]}

      assert false == InternetChecker.connected?(:unknown, state)
    end

    test "when IP addresses are passed in" do
      state = %{hosts: [{{1, 1, 1, 1}, 80}], ifname: Utils.get_ifname_for_tests()}

      assert true == InternetChecker.connected?(:unknown, state)
    end

    test "when DNS can be resolved for a domain name" do
      state = %{hosts: [{"localhost", 80}], ifname: Utils.get_ifname_for_tests()}

      assert true == InternetChecker.connected?(:unknown, state)
    end
  end

  test "disconnected interface" do
    ifname = "disconnected_interface"
    property = ["interface", ifname, "connection"]
    lower_up = ["interface", ifname, "lower_up"]

    # Set up
    VintageNet.PropertyTable.clear(VintageNet, property)
    VintageNet.PropertyTable.clear(VintageNet, lower_up)
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
    VintageNet.PropertyTable.put(VintageNet, property, :disconnected)
    VintageNet.PropertyTable.put(VintageNet, lower_up, true)

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
    VintageNet.PropertyTable.put(VintageNet, property, :internet)
    VintageNet.PropertyTable.put(VintageNet, lower_up, true)

    VintageNet.subscribe(property)

    start_supervised!({InternetChecker, ifname})

    Process.sleep(250)
    VintageNet.PropertyTable.put(VintageNet, lower_up, false)
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
