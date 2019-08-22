defmodule VintageNet.Interface.LANConnectivityCheckerTest do
  use ExUnit.Case, async: true

  alias VintageNet.Interface.LANConnectivityChecker

  test "disconnected interface" do
    property = ["interface", "disconnected_interface2", "connection"]
    VintageNet.subscribe(property)

    start_supervised!({LANConnectivityChecker, "disconnected_interface2"})

    assert_receive {VintageNet, ^property, _old_value, :disconnected, _meta}, 1_000
  end

  @tag :requires_interfaces_monitor
  test "lan connected interface" do
    ifname = get_ifname()
    property = ["interface", ifname, "connection"]
    VintageNet.subscribe(property)

    start_supervised!({LANConnectivityChecker, ifname})

    assert_receive {VintageNet, ^property, _old_value, :lan, _meta}, 1_000
    refute_receive {VintageNet, ^property, _old_value, :internet, _meta}
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
