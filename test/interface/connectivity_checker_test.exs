defmodule VintageNet.Interface.ConnectivityChecker.Test do
  use ExUnit.Case, async: true

  alias VintageNet.Interface.ConnectivityChecker

  test "disabled interface" do
    start_supervised!({ConnectivityChecker, "disabled_interface"})

    property = ["interface", "disabled_interface", "connection"]
    VintageNet.PropertyTable.subscribe(VintageNet, property)

    assert_receive {VintageNet, property, _old_value, :disabled, _meta}, 1_000
  end

  test "internet connected interface" do
    ifname = get_ifname()
    start_supervised!({ConnectivityChecker, ifname})

    property = ["interface", ifname, "connection"]
    VintageNet.PropertyTable.subscribe(VintageNet, property)

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
