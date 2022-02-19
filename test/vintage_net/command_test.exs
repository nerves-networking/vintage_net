defmodule VintageNet.CommandTest do
  use ExUnit.Case
  doctest VintageNet.Command
  alias VintageNet.Command

  # See test/fixtures/root for what commands are available

  test "cmd" do
    assert {"hello\n", 0} = Command.cmd("echo", ["hello"])
    assert {"", 1} = Command.cmd("false", [])
    assert {_reason, 256} = Command.cmd("missing_command", [])
  end

  test "muon_cmd" do
    assert {"hello\n", 0} = Command.muon_cmd("echo", ["hello"])
    assert {"", 1} = Command.muon_cmd("false", [])
    assert {_reason, 256} = Command.cmd("missing_command", [])
  end

  test "PATH overridden with VintageNet's version" do
    expected_path = Application.get_env(:vintage_net, :path)
    assert {expected_path <> "\n", 0} == Command.cmd("sh", ["-c", "echo $PATH"])
    assert {expected_path <> "\n", 0} == Command.muon_cmd("sh", ["-c", "echo $PATH"])
  end

  test "full path executable" do
    assert {"hello\n", 0} = Command.muon_cmd("/bin/sh", ["-c", "echo hello"])
    assert {_reason, 256} = Command.muon_cmd("/bin/does-not-exist", ["-c", "echo hello"])
  end
end
