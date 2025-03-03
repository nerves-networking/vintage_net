# SPDX-FileCopyrightText: 2021 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.Interface.IfupDaemonTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias VintageNet.Interface.IfupDaemon

  doctest IfupDaemon

  test "reactions to the interface coming up and going down" do
    # capture_log to suppress log messages
    capture_log(fn ->
      pid =
        start_supervised!(
          {IfupDaemon, ifname: "test0", command: "sleep", args: ["10000"], opts: []}
        )

      refute IfupDaemon.running?(pid)

      # Simulate interface starting
      send(pid, {VintageNet, ["interface", "test0", "lower_up"], false, true, %{}})
      Process.sleep(10)

      assert IfupDaemon.running?(pid)

      # Simulate interface stopping
      send(pid, {VintageNet, ["interface", "test0", "lower_up"], true, false, %{}})
      Process.sleep(10)

      refute IfupDaemon.running?(pid)
    end)
  end

  test "short running programs stop ok" do
    # capture_log to suppress log messages
    capture_log(fn ->
      pid =
        start_supervised!(
          {IfupDaemon, ifname: "test0", command: "echo", args: ["hello"], opts: []}
        )

      refute IfupDaemon.running?(pid)

      # Simulate interface starting
      send(pid, {VintageNet, ["interface", "test0", "lower_up"], false, true, %{}})
      Process.sleep(50)

      # Check that a successful daemon exit doesn't take down the IfupDaemon
      assert Process.alive?(pid)
      refute IfupDaemon.running?(pid)

      # Simulate interface stopping - mostly to check that it doesn't crash
      send(pid, {VintageNet, ["interface", "test0", "lower_up"], true, false, %{}})
      Process.sleep(10)
      refute IfupDaemon.running?(pid)
    end)
  end

  test "invalid commands crash" do
    capture_log(fn ->
      pid =
        start_supervised!(
          {IfupDaemon, ifname: "test0", command: "missing_program", args: [], opts: []}
        )

      refute IfupDaemon.running?(pid)

      # Simulate interface starting
      send(pid, {VintageNet, ["interface", "test0", "lower_up"], false, true, %{}})
      Process.sleep(50)

      # Should have crashed by now
      refute Process.alive?(pid)
    end)
  end
end
