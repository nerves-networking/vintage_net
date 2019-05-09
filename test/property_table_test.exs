defmodule PropertyTableTest do
  use ExUnit.Case, async: true

  alias VintageNet.PropertyTable

  doctest PropertyTable

  setup config do
    {:ok, _pid} = start_supervised({PropertyTable, name: config.test})
    {:ok, %{table: config.test}}
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
end
