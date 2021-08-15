defmodule VintageNet.Connectivity.InternetCheckerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias VintageNet.Connectivity.InternetChecker

  test "rotate_list/1" do
    assert [1] == InternetChecker.rotate_list([1])
    assert [2, 1] == InternetChecker.rotate_list([1, 2])
    assert [2, 3, 1] == InternetChecker.rotate_list([1, 2, 3])
    assert [] == InternetChecker.rotate_list([])
  end

  test "disconnected interface" do
    property = ["interface", "disconnected_interface", "connection"]
    VintageNet.subscribe(property)

    start_supervised!({InternetChecker, "disconnected_interface"})

    assert_receive {VintageNet, ^property, _old_value, :disconnected, _meta}, 1_000
  end

  @tag :requires_interfaces_monitor
  test "internet connected interface" do
    ifname = get_ifname()
    property = ["interface", ifname, "connection"]
    VintageNet.subscribe(property)

    start_supervised!({InternetChecker, ifname})

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
        start_supervised!({VintageNet.Interface.InternetConnectivityChecker, get_ifname()})
      end)

    assert messages =~
             "VintageNet.Interface.InternetConnectivityChecker is now VintageNet.Connectivity.InternetChecker"
  end

  defp get_ifname() do
    case :inet.getifaddrs() do
      {:ok, addrs} ->
        addrs
        |> Enum.filter(&filter_interfaces/1)
        |> List.first()
        |> elem(0)
        |> to_string()
    end
  end

  defp filter_interfaces({[?l, ?o | _anything], _}), do: false

  defp filter_interfaces({_ifname, fields}) do
    Enum.member?(fields[:flags], :up) and fields[:addr] != nil
  end
end
