defmodule VintageNet.Interface.OutputLoggerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias VintageNet.Interface.OutputLogger

  test "logs each item" do
    log =
      capture_log(fn ->
        Enum.into(["one", "two", "three"], OutputLogger.new(""))
      end)

    assert log =~ "[debug] one"
    assert log =~ "[debug] two"
    assert log =~ "[debug] three"
  end

  test "adds a prefix" do
    log =
      capture_log(fn ->
        Enum.into(["one", "two", "three"], OutputLogger.new("prefix:"))
      end)

    assert log =~ "[debug] prefix:one"
    assert log =~ "[debug] prefix:two"
    assert log =~ "[debug] prefix:three"
  end

  test "handles multiple lines passed at the same time" do
    log =
      capture_log(fn ->
        Enum.into(["one\ntwo\nthree"], OutputLogger.new("prefix:"))
      end)

    assert log =~ "[debug] prefix:one"
    assert log =~ "[debug] prefix:two"
    assert log =~ "[debug] prefix:three"
  end
end
