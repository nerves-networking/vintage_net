defmodule VintageNet.Connectivity.HostListTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias VintageNet.Connectivity.HostList

  describe "load/1" do
    test "returns default if unconfigured" do
      capture_log(fn ->
        assert HostList.load([]) == [{:tcp_ping, [host: {1, 1, 1, 1}, port: 53]}]
      end)
    end

    test "old way gets updated with warning" do
      log =
        capture_log(fn ->
          assert HostList.load(internet_host: {2, 2, 2, 2}) == [
                   {:tcp_ping, [host: {2, 2, 2, 2}, port: 80]}
                 ]
        end)

      assert log =~
               "Replace with `internet_host_list: [{:tcp_ping, host: {2, 2, 2, 2}, port: 80}]`"
    end

    test "converts string IP address to tuples" do
      assert HostList.load(internet_host_list: [{:tcp_ping, host: "1.2.3.4", port: 443}]) == [
               {:tcp_ping, host: {1, 2, 3, 4}, port: 443}
             ]
    end

    test "drops bad entries" do
      assert HostList.load(
               internet_host_list: [
                 {:tcp_ping, host: "1.2.3.4", port: 443},
                 # atom
                 :oops,
                 # 5-tuple IP address
                 {:tcp_ping, host: {1, 2, 3, 4, 5}, port: 10},
                 # bad port
                 {:tcp_ping, host: "5.6.7.8", port: 100_000},
                 # old-style host/port combo
                 {"5.6.7.8", 123}
               ]
             ) == [
               {:tcp_ping, host: {1, 2, 3, 4}, port: 443},
               {:tcp_ping, host: {5, 6, 7, 8}, port: 123}
             ]
    end

    test "leaves domain names alone" do
      result =
        HostList.load(
          internet_host_list: [
            {:tcp_ping, host: "1.2.3.4", port: 443},
            {:tcp_ping, host: "example.com", port: 80}
          ]
        )

      assert {:tcp_ping, host: {1, 2, 3, 4}, port: 443} in result
      assert {:tcp_ping, host: "example.com", port: 80} in result
    end
  end

  describe "create_ping_list/1" do
    test "max 3 hosts returned" do
      list =
        HostList.create_ping_list([
          {:tcp_ping, host: {1, 1, 1, 1}, port: 1},
          {:tcp_ping, host: {2, 2, 2, 2}, port: 2},
          {:tcp_ping, host: {3, 3, 3, 3}, port: 3},
          {:tcp_ping, host: {4, 4, 4, 4}, port: 4}
        ])

      assert length(list) == 3
    end

    test "no duplicates" do
      list =
        HostList.create_ping_list([
          {:tcp_ping, host: {1, 1, 1, 1}, port: 1},
          {:tcp_ping, host: {1, 1, 1, 1}, port: 1},
          {:tcp_ping, host: {1, 1, 1, 1}, port: 1}
        ])

      assert list == [{:tcp_ping, host: {1, 1, 1, 1}, port: 1}]
    end

    test "resolves names" do
      result = HostList.create_ping_list([{:tcp_ping, host: "localhost", port: 5}])

      assert {:tcp_ping, host: {127, 0, 0, 1}, port: 5} in result
    end

    test "removes bad hostnames" do
      assert [] ==
               HostList.create_ping_list([
                 {:tcp_ping, host: "fake.domain.name.com.io.vintage.net.invalid", port: 80}
               ])
    end

    test "resolves names that return more than one result" do
      # This was found accidentally by digging random hostnames.
      result = HostList.create_ping_list([{:tcp_ping, host: "cloudflare.com", port: 5}])

      assert length(result) > 1
    end
  end
end
