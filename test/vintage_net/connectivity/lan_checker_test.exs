defmodule VintageNet.Connectivity.LANCheckerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  alias VintageNet.Connectivity.LANChecker

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

    ifname = get_ifname()
    property = ["interface", ifname, "connection"]
    VintageNet.subscribe(property)

    start_supervised!({LANChecker, ifname})

    assert_receive {VintageNet, ^property, _old_value, :lan, _meta}, 1_000
    refute_receive {VintageNet, ^property, _old_value, :internet, _meta}
  end

  test "deprecation warning when using old LANConnectivityChecker" do
    messages =
      capture_log(fn ->
        start_supervised!({VintageNet.Interface.LANConnectivityChecker, get_ifname()})
      end)

    assert messages =~
             "VintageNet.Interface.LANConnectivityChecker is now VintageNet.Connectivity.LANChecker"
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
