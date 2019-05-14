defmodule VintageNet.Interface.ConnectivityChecker.Test do
  use ExUnit.Case, async: true

  alias VintageNet.Interface.ConnectivityChecker

  test "disconnected interface" do
    start_supervised!({ConnectivityChecker, "disconnected_interface"})

    property = ["interface", "disconnected_interface", "connection"]
    VintageNet.subscribe(property)

    assert_receive {VintageNet, property, _old_value, :disconnected, _meta}, 1_000
  end

  test "internet connected interface" do
    ifname = get_ifname()
    start_supervised!({ConnectivityChecker, ifname})

    property = ["interface", ifname, "connection"]
    VintageNet.subscribe(property)

    assert_receive {VintageNet, property, _old_value, :internet, _meta}, 1_000
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
