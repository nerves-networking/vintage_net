defmodule VintageNet.Interface.ConnectivityChecker.Test do
  use ExUnit.Case, async: true

  alias VintageNet.Interface.ConnectivityChecker

  test "disabled interface" do
    {:ok, checker} = ConnectivityChecker.start_link("disabledinterface")
    :erlang.trace(checker, true, [:receive])

    :timer.sleep(1_000)

    assert_receive {:trace, ^checker, :receive, :ping}

    assert :disabled ==
             PropertyTable.get(VintageNet, ["interface", "disabledinterface", "connection"])
  end

  test "internet connected interface" do
    ifname = get_ifname()
    {:ok, checker} = ConnectivityChecker.start_link(ifname)
    :erlang.trace(checker, true, [:receive])

    :timer.sleep(1_000)

    assert_receive {:trace, ^checker, :receive, :ping}

    assert :lan == PropertyTable.get(VintageNet, ["interface", ifname, "connection"])
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

  defp filter_interfaces({'lo', _}), do: false
  defp filter_interfaces(_), do: true
end
