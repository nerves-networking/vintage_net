defmodule VintageNet.Interface.InternetConnectivityCheckerTest do
  use ExUnit.Case, async: true

  alias VintageNet.Interface.InternetConnectivityChecker

  describe "update_state_from_ping/2" do
    test "internet scenarios" do
      base_state = %{ifname: "bogus0", connectivity: :internet, strikes: 0, hosts: [1, 2]}

      # Ping worked -> good internet
      assert InternetConnectivityChecker.update_state_from_ping(base_state, :ok) ==
               %{ifname: "bogus0", connectivity: :internet, hosts: [1, 2], strikes: 0}

      # Ping failed once -> rotate hosts and add a strike
      assert InternetConnectivityChecker.update_state_from_ping(
               base_state,
               {:error, :ehostdown}
             ) ==
               %{ifname: "bogus0", connectivity: :internet, hosts: [2, 1], strikes: 1}

      # No IP address reverts to LAN
      assert InternetConnectivityChecker.update_state_from_ping(
               base_state,
               {:error, :no_ipv4_address}
             ) ==
               %{ifname: "bogus0", connectivity: :lan, hosts: [1, 2], strikes: 3}

      # No interfaces goes to disconnected
      assert InternetConnectivityChecker.update_state_from_ping(
               base_state,
               {:error, :if_not_found}
             ) ==
               %{ifname: "bogus0", connectivity: :disconnected, hosts: [1, 2], strikes: 3}

      # Check 3 strikes reverts to :lan
      base_state = %{ifname: "bogus0", connectivity: :internet, strikes: 2, hosts: [1, 2]}

      assert InternetConnectivityChecker.update_state_from_ping(
               base_state,
               {:error, :ehostdown}
             ) ==
               %{ifname: "bogus0", connectivity: :lan, hosts: [2, 1], strikes: 3}
    end

    test "lan scenarios" do
      base_state = %{ifname: "bogus0", connectivity: :lan, strikes: 3, hosts: [1, 2]}

      # No response. Host order should rotate
      assert InternetConnectivityChecker.update_state_from_ping(
               base_state,
               {:error, :ehostdown}
             ) ==
               %{ifname: "bogus0", connectivity: :lan, hosts: [2, 1], strikes: 3}

      # Response. Should be internet connected now.
      assert InternetConnectivityChecker.update_state_from_ping(base_state, :ok) ==
               %{ifname: "bogus0", connectivity: :internet, hosts: [1, 2], strikes: 0}

      # No interfaces goes to disconnected
      assert InternetConnectivityChecker.update_state_from_ping(
               base_state,
               {:error, :if_not_found}
             ) ==
               %{ifname: "bogus0", connectivity: :disconnected, hosts: [1, 2], strikes: 3}
    end

    test "disconnected scenarios" do
      # This isn't supposed to be called when disconnected, but check that it doesn't
      # crash.
      base_state = %{ifname: "bogus0", connectivity: :disconnected, strikes: 3, hosts: [1, 2]}

      # No response -> rotate hosts like when lan connected
      assert InternetConnectivityChecker.update_state_from_ping(
               base_state,
               {:error, :ehostdown}
             ) ==
               %{ifname: "bogus0", connectivity: :disconnected, hosts: [2, 1], strikes: 3}

      # Magic internet availability
      assert InternetConnectivityChecker.update_state_from_ping(base_state, :ok) ==
               %{ifname: "bogus0", connectivity: :internet, hosts: [1, 2], strikes: 0}
    end
  end

  test "next_interval/1" do
    max_interval = 30_000
    min_interval = 500

    # Check that internet-connected scenarios retry more aggressively, but never
    # more frequent than the minimum interval setting
    assert InternetConnectivityChecker.next_interval(:internet, 1, 0) == max_interval
    assert InternetConnectivityChecker.next_interval(:internet, 1, 1) == div(max_interval, 2)
    assert InternetConnectivityChecker.next_interval(:internet, 1, 2) == div(max_interval, 3)
    assert InternetConnectivityChecker.next_interval(:internet, 1, 1000) == min_interval

    # Check LAN scenarios back off when not working
    assert InternetConnectivityChecker.next_interval(:lan, 100, 1) == 200
    assert InternetConnectivityChecker.next_interval(:lan, max_interval, 1) == max_interval

    # Disabled anything has an infinite timeout to avoid needless polls
    assert InternetConnectivityChecker.next_interval(:disconnected, 100, 1) == :infinity
  end

  test "rotate_list/1" do
    assert [1] == InternetConnectivityChecker.rotate_list([1])
    assert [2, 1] == InternetConnectivityChecker.rotate_list([1, 2])
    assert [2, 3, 1] == InternetConnectivityChecker.rotate_list([1, 2, 3])
    assert [] == InternetConnectivityChecker.rotate_list([])
  end

  test "disconnected interface" do
    property = ["interface", "disconnected_interface", "connection"]
    VintageNet.subscribe(property)

    start_supervised!({InternetConnectivityChecker, "disconnected_interface"})

    assert_receive {VintageNet, ^property, _old_value, :disconnected, _meta}, 1_000
  end

  @tag :requires_interfaces_monitor
  test "internet connected interface" do
    ifname = get_ifname()
    property = ["interface", ifname, "connection"]
    VintageNet.subscribe(property)

    start_supervised!({InternetConnectivityChecker, ifname})

    assert_receive {VintageNet, ^property, _old_value, :internet, _meta}, 1_000
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
