defmodule VintageNet.Interface.InternetConnectivityCheckerTest do
  use ExUnit.Case, async: true

  alias VintageNet.Interface.InternetConnectivityChecker

  test "disconnected interface" do
    property = ["interface", "disconnected_interface", "connection"]
    VintageNet.subscribe(property)

    start_supervised!({InternetConnectivityChecker, "disconnected_interface"})

    assert_receive {VintageNet, ^property, _old_value, :disconnected, _meta}, 1_000
  end

  @tag :requires_interfaces_monitor
  test "internet connected interface" do
    ifname = get_ifname()
    property = ["interface", ifname, "connection"]
    VintageNet.subscribe(property)

    start_supervised!({InternetConnectivityChecker, ifname})

    assert_receive {VintageNet, ^property, _old_value, :internet, _meta}, 1_000
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
