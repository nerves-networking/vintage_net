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
         {:run, "sleep", ["4"]},
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

  test "when a command is longer than the timeout" do
    Process.flag(:trap_exit, true)
    {:ok, pid} = Interface.start_link(iface_timeout1())
    assert_receive {:EXIT, ^pid, :killed}, 6_000
  end

  test "when a command later in the command queue timesout" do
    Process.flag(:trap_exit, true)
    {:ok, pid} = Interface.start_link(iface_timeout2())
    assert_receive {:EXIT, ^pid, :killed}, 10_000
  end

  test "when a command runs within the timeout" do
    {:ok, pid} = Interface.start_link(iface_ok1())

    :timer.sleep(5_000)

    assert :up == Interface.status(pid)
  end

  test "when a many commands run within the timeout" do
    {:ok, pid} = Interface.start_link(iface_ok2())

    :timer.sleep(9_000)

    assert :up == Interface.status(pid)
  end
end
