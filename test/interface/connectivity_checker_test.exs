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
    ifname = Application.get_env(:vintage_net, :test_interface)
    {:ok, checker} = ConnectivityChecker.start_link(ifname)
    :erlang.trace(checker, true, [:receive])

    :timer.sleep(1_000)

    assert_receive {:trace, ^checker, :receive, :ping}

    assert :internet == PropertyTable.get(VintageNet, ["interface", ifname, "connection"])
  end
end
