# SPDX-FileCopyrightText: 2021 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.Connectivity.CheckLogicTest do
  use ExUnit.Case, async: true

  alias VintageNet.Connectivity.CheckLogic

  test "starting internet-connected" do
    base_state = CheckLogic.init(:internet)

    # Check worked -> good internet
    assert %{connectivity: :internet, strikes: 0} =
             CheckLogic.check_succeeded(base_state, :internet)

    # Check failed once -> add a strike
    assert %{connectivity: :internet, strikes: 1} = CheckLogic.check_failed(base_state)

    # 3 failures reverts to :lan
    state =
      base_state
      |> CheckLogic.check_failed()
      |> CheckLogic.check_failed()
      |> CheckLogic.check_failed()

    assert %{connectivity: :lan, strikes: 3} = state

    # A failure followed by a success fixes everything.
    state =
      base_state
      |> CheckLogic.check_failed()
      |> CheckLogic.check_succeeded(:internet)

    assert %{connectivity: :internet, strikes: 0} = state
  end

  test "starting lan-connected" do
    base_state = CheckLogic.init(:lan)

    # Check worked -> good internet
    assert %{connectivity: :internet, strikes: 0} =
             CheckLogic.check_succeeded(base_state, :internet)

    # Check failure -> still lan
    assert %{connectivity: :lan, strikes: 3} = CheckLogic.check_failed(base_state)
  end

  test "starting disconnected" do
    base_state = CheckLogic.init(:disconnected)

    # Ignore checks since disconnected
    assert %{connectivity: :disconnected} = CheckLogic.check_succeeded(base_state, :internet)
    assert %{connectivity: :disconnected} = CheckLogic.check_failed(base_state)
  end

  test "ifdown" do
    assert %{connectivity: :disconnected} = CheckLogic.init(:internet) |> CheckLogic.ifdown()
    assert %{connectivity: :disconnected} = CheckLogic.init(:lan) |> CheckLogic.ifdown()
    assert %{connectivity: :disconnected} = CheckLogic.init(:disconnected) |> CheckLogic.ifdown()
  end

  test "ifup" do
    assert %{connectivity: :lan} = CheckLogic.init(:disconnected) |> CheckLogic.ifup()

    # These shouldn't happen, but they should at least be reasonable
    assert %{connectivity: :internet} = CheckLogic.init(:internet) |> CheckLogic.ifup()
    assert %{connectivity: :lan} = CheckLogic.init(:lan) |> CheckLogic.ifup()
  end

  test "initial timeouts" do
    assert %{interval: 500} = CheckLogic.init(:internet)
    assert %{interval: 500} = CheckLogic.init(:lan)
    assert %{interval: :infinity} = CheckLogic.init(:disconnected)
  end

  test "success check interval" do
    state = CheckLogic.init(:internet) |> CheckLogic.check_succeeded(:internet)

    assert %{interval: 30_000} = state
  end

  test "quicker checks and then slower checks" do
    state = CheckLogic.init(:internet) |> CheckLogic.check_succeeded(:internet)
    assert %{connectivity: :internet, interval: 30_000} = state

    # Check faster on initial failures
    state = CheckLogic.check_failed(state)
    assert %{connectivity: :internet, interval: 15_000} = state

    state = CheckLogic.check_failed(state)
    assert %{connectivity: :internet, interval: 10_000} = state

    state = CheckLogic.check_failed(state)
    assert %{connectivity: :lan, interval: 10_000} = state

    # Check less frequently after the internet is lost
    state = CheckLogic.check_failed(state)
    assert %{connectivity: :lan, interval: 20_000} = state

    state = CheckLogic.check_failed(state)
    assert %{connectivity: :lan, interval: 30_000} = state
  end

  # test "next_interval/1" do
  #   max_interval = 30_000
  #   min_interval = 500

  #   # Check that internet-connected scenarios retry more aggressively, but never
  #   # more frequent than the minimum interval setting
  #   assert CheckLogic.next_interval(:internet, 1, 0) == max_interval
  #   assert CheckLogic.next_interval(:internet, 1, 1) == div(max_interval, 2)
  #   assert CheckLogic.next_interval(:internet, 1, 2) == div(max_interval, 3)
  #   assert CheckLogic.next_interval(:internet, 1, 1000) == min_interval

  #   # Check LAN scenarios back off when not working
  #   assert CheckLogic.next_interval(:lan, 100, 1) == 200
  #   assert CheckLogic.next_interval(:lan, max_interval, 1) == max_interval

  #   # Disabled anything has an infinite timeout to avoid needless polls
  #   assert CheckLogic.next_interval(:disconnected, 100, 1) == :infinity
  # end
end
