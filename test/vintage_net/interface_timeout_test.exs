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

  defp iface_down_ok1() do
    {"down",
     %{
       files: [],
       up_cmds: [],
       down_cmds: [{:run, "sleep", ["4"]}]
     }}
  end

  defp iface_down_timeout() do
    {"down",
     %{
       files: [],
       up_cmds: [],
       down_cmds: [{:run, "sleep", ["20"]}]
     }}
  end

  @tag :interface_timeout
  test "when a command is longer than the timeout" do
    {:ok, pid} = Interface.start_link(iface_timeout1())
    :erlang.trace(pid, true, [:receive])

    # timeout + 250ms
    :timer.sleep(5_250)
    assert_receive {:trace, ^pid, :receive, :command_timeout}

    # retry back off + 250 ms
    :timer.sleep(5_250)

    assert_receive {:trace, ^pid, :receive, :retry_command}

    GenServer.stop(pid)
  end

  @tag :interface_timeout
  test "when a command later in the command queue timesout" do
    {:ok, pid} = Interface.start_link(iface_timeout2())
    :erlang.trace(pid, true, [:receive])

    :timer.sleep(2_100)
    assert_receive {:trace, ^pid, :receive, :command_finished}

    :timer.sleep(5_100)

    assert_receive {:trace, ^pid, :receive, :command_timeout}

    :timer.sleep(5_100)

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

  @tag :interface_timeout
  test "run down commands okay" do
    {:ok, pid} = Interface.start_link(iface_down_ok1())
    :timer.sleep(1000)

    :up = Interface.status(pid)

    Interface.down(pid)

    :timer.sleep(5_000)

    assert :down == Interface.status(pid)
  end

  @tag :interface_timeout
  test "run down commands handles timeout" do
    {:ok, pid} = Interface.start_link(iface_down_timeout())
    :timer.sleep(500)
    :up = Interface.status(pid)
    Interface.down(pid)

    :erlang.trace(pid, true, [:receive])

    # timeout + 250ms
    :timer.sleep(5_250)
    assert_receive {:trace, ^pid, :receive, :command_timeout}

    # retry back off + 250 ms
    :timer.sleep(5_250)

    assert_receive {:trace, ^pid, :receive, :retry_command}

    GenServer.stop(pid)
  end
end
