defmodule VintageNet.Connectivity.HostListTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias VintageNet.Connectivity.HostList

  describe "load/1" do
    test "returns default if unconfigured" do
      capture_log(fn ->
        assert HostList.load([]) == [{{1, 1, 1, 1}, 80}]
      end)
    end

    test "old way gets updated with warning" do
      log =
        capture_log(fn ->
          assert HostList.load(internet_host: {2, 2, 2, 2}) == [{{2, 2, 2, 2}, 80}]
        end)

      assert log =~ "Replace with `internet_host_list: [{{2, 2, 2, 2}, 80}]`"
    end

    test "converts string IP address to tuples" do
      assert HostList.load(internet_host_list: [{"1.2.3.4", 443}]) == [{{1, 2, 3, 4}, 443}]
    end

    test "drops bad entries" do
      assert HostList.load(
               internet_host_list: [
                 {"1.2.3.4", 443},
                 # atom
                 :oops,
                 # 5-tuple IP address
                 {{1, 2, 3, 4, 5}, 10},
                 # bad port
                 {"5.6.7.8", 100_000}
               ]
             ) == [{{1, 2, 3, 4}, 443}]
    end

    test "leaves domain names alone" do
      result =
        HostList.load(
          internet_host_list: [
            {"1.2.3.4", 443},
            {"example.com", 80}
          ]
        )

      assert {{1, 2, 3, 4}, 443} in result
      assert {"example.com", 80} in result
    end
  end

  describe "create_ping_list/1" do
    test "max 3 hosts returned" do
      list =
        HostList.create_ping_list([
          {{1, 1, 1, 1}, 1},
          {{2, 2, 2, 2}, 2},
          {{3, 3, 3, 3}, 3},
          {{4, 4, 4, 4}, 4}
        ])

      assert length(list) == 3
    end

    test "no duplicates" do
      list = HostList.create_ping_list([{{1, 1, 1, 1}, 1}, {{1, 1, 1, 1}, 1}, {{1, 1, 1, 1}, 1}])

      assert list == [{{1, 1, 1, 1}, 1}]
    end

    test "resolves names" do
      result = HostList.create_ping_list([{"localhost", 5}])

      assert {{127, 0, 0, 1}, 5} in result
    end

    test "removes bad hostnames" do
      assert [] ==
               HostList.create_ping_list([{"fake.domain.name.com.io.vintage.net.invalid", 80}])
    end

    test "resolves names that return more than one result" do
      # This was found accidentally by digging random hostnames.
      result = HostList.create_ping_list([{"cloudflare.com", 5}])

      assert length(result) > 1
    end
  end
end
