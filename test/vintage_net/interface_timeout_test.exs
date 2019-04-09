defmodule VintageNet.Interface.Timeout.Test do
  use ExUnit.Case, async: true

  alias VintageNet.Interface

  defp iface_timeout1() do
    {"fake",
     %{
       files: [],
       up_cmds: [
         {:run, "sleep", ["20"]}
       ]
     }}
  end

  defp iface_timeout2() do
    {"fake",
     %{
       files: [],
       up_cmds: [
         {:run, "sleep", ["2"]},
         {:run, "sleep", ["20"]}
       ]
     }}
  end

  defp iface_ok1() do
    {"fake",
     %{
       files: [],
       up_cmds: [
         {:run, "sleep", ["4"]}
       ]
     }}
  end

  defp iface_ok2() do
    {"fake",
     %{
       files: [],
       up_cmds: [
         {:run, "sleep", ["4"]},
         {:run, "sleep", ["4"]}
       ]
     }}
  end

  @tag :interface_timeout
  test "when a command is longer than the timeout" do
    {:ok, pid} = Interface.start_link(iface_timeout1())
    :erlang.trace(pid, true, [:receive])

    # timeout + retry back off + 500 ms
    :timer.sleep(10_500)

    assert_receive {:trace, ^pid, :receive, :retry_command}

    GenServer.stop(pid)
  end

  @tag :interface_timeout
  test "when a command later in the command queue timesout" do
    {:ok, pid} = Interface.start_link(iface_timeout2())
    :erlang.trace(pid, true, [:receive])

    # successful cmd + timeout + retry back off + 1000 ms
    :timer.sleep(13_000)

    assert_receive {:trace, ^pid, :receive, :retry_command}

    GenServer.stop(pid)
  end

  @tag :interface_timeout
  test "when a command runs within the timeout" do
    {:ok, pid} = Interface.start_link(iface_ok1())

    :timer.sleep(5_000)

    assert :up == Interface.status(pid)
  end

  @tag :interface_timeout
  test "when a many commands run within the timeout" do
    {:ok, pid} = Interface.start_link(iface_ok2())

    :timer.sleep(9_000)

    assert :up == Interface.status(pid)
  end
end
