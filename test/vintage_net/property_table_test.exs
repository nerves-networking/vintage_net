defmodule VintageNet.PropertyTableTest do
  use ExUnit.Case, async: true

  alias VintageNet.PropertyTable

  doctest PropertyTable

  setup config do
    {:ok, _pid} = start_supervised({PropertyTable, name: config.test})
    {:ok, %{table: config.test}}
  end

  test "wildcard subscription", %{table: table} do
    PropertyTable.subscribe(table, ["a", :_, "c"])

    # Exact match
    PropertyTable.put(table, ["a", "b", "c"], 88)
    assert_receive {^table, ["a", "b", "c"], nil, 88, _}

    # Prefix match
    PropertyTable.put(table, ["a", "b", "c", "d"], 88)
    assert_receive {^table, ["a", "b", "c", "d"], nil, 88, _}

    # No match
    PropertyTable.put(table, ["x", "b", "c"], 88)
    refute_receive {^table, ["x", "b", "c"], _, _, _}

    PropertyTable.put(table, ["a", "b", "d"], 88)
    refute_receive {^table, ["a", "b", "d"], _, _, _}
  end

  test "getting invalid properties raises", %{table: table} do
    # Wildcards aren't allowed
    assert_raise ArgumentError, fn -> PropertyTable.get(table, [:_, "a"]) end
    assert_raise ArgumentError, fn -> PropertyTable.get(table, [:_]) end

    # Non-string lists aren't allowed
    assert_raise ArgumentError, fn -> PropertyTable.get(table, ['nope']) end
    assert_raise ArgumentError, fn -> PropertyTable.get(table, ["a", 5]) end
  end

  test "sending events", %{table: table} do
    name = ["test"]
    PropertyTable.subscribe(table, name)

    PropertyTable.put(table, name, 99)
    assert_receive {table, ^name, nil, 99, _}

    PropertyTable.put(table, name, 100)
    assert_receive {table, ^name, 99, 100, _}

    PropertyTable.clear(table, name)
    assert_receive {table, ^name, 100, nil, _}

    PropertyTable.unsubscribe(table, name)
  end

  test "setting properties to nil clears them", %{table: table} do
    name = ["test"]

    PropertyTable.put(table, name, 124)
    assert PropertyTable.get_by_prefix(table, []) == [{name, 124}]

    PropertyTable.put(table, name, nil)
    assert PropertyTable.get_by_prefix(table, []) == []
  end

  test "generic subscribers receive events", %{table: table} do
    name = ["test", "a", "b"]

    PropertyTable.subscribe(table, [])
    PropertyTable.put(table, name, 101)
    assert_receive {table, ^name, nil, 101, _}
    PropertyTable.unsubscribe(table, [])
  end

  test "duplicate events are dropped", %{table: table} do
    name = ["test", "a", "b"]

    PropertyTable.subscribe(table, name)
    PropertyTable.put(table, name, 102)
    PropertyTable.put(table, name, 102)
    assert_receive {^table, ^name, nil, 102, _}
    refute_receive {^table, ^name, _, 102, _}

    PropertyTable.unsubscribe(table, name)
  end

  test "getting the latest", %{table: table} do
    name = ["test", "a", "b"]
    assert PropertyTable.get(table, name) == nil

    PropertyTable.put(table, name, 105)
    assert PropertyTable.get(table, name) == 105

    PropertyTable.put(table, name, 106)
    assert PropertyTable.get(table, name) == 106
  end

  test "fetching data with timestamps", %{table: table} do
    name = ["test", "a", "b"]
    assert :error == PropertyTable.fetch_with_timestamp(table, name)

    PropertyTable.put(table, name, 105)
    now = :erlang.monotonic_time()
    assert {:ok, value, timestamp} = PropertyTable.fetch_with_timestamp(table, name)
    assert value == 105

    # Check that PropertyTable takes the timestamp synchronously.
    # If it doesn't, then this will fail randomly.
    assert now > timestamp

    # Check that it didn't take too long to capture the time
    assert now - timestamp < 1_000_000
  end

  test "getting a subtree", %{table: table} do
    name = ["test", "a", "b"]
    name2 = ["test", "a", "c"]

    assert PropertyTable.get_by_prefix(table, []) == []

    PropertyTable.put(table, name, 105)
    assert PropertyTable.get_by_prefix(table, []) == [{name, 105}]

    PropertyTable.put(table, name2, 106)
    assert PropertyTable.get_by_prefix(table, []) == [{name, 105}, {name2, 106}]
    assert PropertyTable.get_by_prefix(table, ["test"]) == [{name, 105}, {name2, 106}]
    assert PropertyTable.get_by_prefix(table, ["test", "a"]) == [{name, 105}, {name2, 106}]
    assert PropertyTable.get_by_prefix(table, name) == [{name, 105}]
    assert PropertyTable.get_by_prefix(table, name2) == [{name2, 106}]
  end

  test "clearing a subtree", %{table: table} do
    PropertyTable.put(table, ["a", "b", "c"], 1)
    PropertyTable.put(table, ["a", "b", "d"], 2)
    PropertyTable.put(table, ["a", "b", "e"], 3)
    PropertyTable.put(table, ["f", "g"], 4)

    PropertyTable.clear_prefix(table, ["a"])
    assert PropertyTable.get_by_prefix(table, []) == [{["f", "g"], 4}]
  end

  test "match using wildcards", %{table: table} do
    PropertyTable.put(table, ["a", "b", "c"], 1)
    PropertyTable.put(table, ["A", "b", "c"], 2)
    PropertyTable.put(table, ["a", "B", "c"], 3)
    PropertyTable.put(table, ["a", "b", "C"], 4)

    # These next properties should never match since we only match on 3 elements below
    PropertyTable.put(table, ["a", "b"], 5)
    PropertyTable.put(table, ["a", "b", "c", "d"], 6)

    # Exact match
    assert PropertyTable.match(table, ["a", "b", "c"]) == [{["a", "b", "c"], 1}]

    # Wildcard one place
    assert PropertyTable.match(table, [:_, "b", "c"]) == [
             {["A", "b", "c"], 2},
             {["a", "b", "c"], 1}
           ]

    assert PropertyTable.match(table, ["a", :_, "c"]) == [
             {["a", "B", "c"], 3},
             {["a", "b", "c"], 1}
           ]

    assert PropertyTable.match(table, ["a", "b", :_]) == [
             {["a", "b", "C"], 4},
             {["a", "b", "c"], 1}
           ]

    # Wildcard two places
    assert PropertyTable.match(table, [:_, :_, "c"]) == [
             {["A", "b", "c"], 2},
             {["a", "B", "c"], 3},
             {["a", "b", "c"], 1}
           ]

    assert PropertyTable.match(table, ["a", :_, :_]) == [
             {["a", "B", "c"], 3},
             {["a", "b", "C"], 4},
             {["a", "b", "c"], 1}
           ]

    # Wildcard three places
    assert PropertyTable.match(table, [:_, :_, :_]) == [
             {["A", "b", "c"], 2},
             {["a", "B", "c"], 3},
             {["a", "b", "C"], 4},
             {["a", "b", "c"], 1}
           ]
  end
end
