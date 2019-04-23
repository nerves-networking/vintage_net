defmodule PropertyTableTest do
  use ExUnit.Case

  @table PropertyTableTestTable

  doctest PropertyTable

  setup do
    {:ok, _pid} = PropertyTable.start_link(name: @table)
    :ok
  end

  test "sending events" do
    name = ["test"]
    PropertyTable.subscribe(@table, name)

    PropertyTable.put(@table, name, 99)
    assert_receive {@table, ^name, nil, 99}

    PropertyTable.put(@table, name, 100)
    assert_receive {@table, ^name, 99, 100}

    PropertyTable.clear(@table, name)
    assert_receive {@table, ^name, 100, nil}

    PropertyTable.unsubscribe(@table, name)
  end

  test "sending specific event is received by generic subscriber" do
    name = ["test", "a", "b"]

    PropertyTable.subscribe(@table, [])
    PropertyTable.put(@table, name, 101)
    assert_receive {@table, ^name, nil, 101}
    PropertyTable.unsubscribe(@table, [])
  end

  test "duplicate events are dropped" do
    name = ["test", "a", "b"]

    PropertyTable.subscribe(@table, name)
    PropertyTable.put(@table, name, 102)
    PropertyTable.put(@table, name, 102)
    assert_receive {@table, ^name, nil, 102}
    refute_receive {@table, ^name, _, 102}

    PropertyTable.unsubscribe(@table, name)
  end

  test "getting the latest" do
    name = ["test", "a", "b"]
    assert PropertyTable.get(@table, name) == nil

    PropertyTable.put(@table, name, 105)
    assert PropertyTable.get(@table, name) == 105

    PropertyTable.put(@table, name, 106)
    assert PropertyTable.get(@table, name) == 106
  end

  test "getting a subtree" do
    name = ["test", "a", "b"]
    name2 = ["test", "a", "c"]

    assert PropertyTable.get_by_prefix(@table, []) == []

    PropertyTable.put(@table, name, 105)
    assert PropertyTable.get_by_prefix(@table, []) == [{name, 105}]

    PropertyTable.put(@table, name2, 106)
    assert PropertyTable.get_by_prefix(@table, []) == [{name, 105}, {name2, 106}]
    assert PropertyTable.get_by_prefix(@table, ["test"]) == [{name, 105}, {name2, 106}]
    assert PropertyTable.get_by_prefix(@table, ["test", "a"]) == [{name, 105}, {name2, 106}]
    assert PropertyTable.get_by_prefix(@table, name) == [{name, 105}]
    assert PropertyTable.get_by_prefix(@table, name2) == [{name2, 106}]
  end
end
