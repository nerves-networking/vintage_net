defmodule VintageNet.PropertyTable do
  @moduledoc """
  PropertyTables are in-memory key-value stores

  Users can subscribe to keys or groups of keys to be notified of changes.

  Keys are hierarchically layed out with each key being represented as a list
  for the path to the key. For example, to get the current state of the network
  interface `eth0`, you would get the value of the key, `["net", "ethernet",
  "eth0"]`.

  Values can be any Elixir data structure except for `nil`. `nil` is used to
  identify non-existent keys. Therefore, setting a property to `nil` deletes
  the property.

  Users can get and listen for changes in multiple keys by specifying prefix
  paths. For example, if you wants to get every network property, run:

      PropertyTable.get_by_prefix(table, ["net"])

  Likewise, you can subscribe to changes in the network status by running:

      PropertyTable.subscribe(table, ["net"])

  Properties can include metadata. `PropertyTable` only specifies that metadata
  is a map.
  """

  alias VintageNet.PropertyTable.Table

  @typedoc """
  A table_id identifies a group of properties
  """
  @type table_id() :: atom()

  @typedoc """
  Properties
  """
  @type property :: [String.t()]
  @type value :: any()
  @type metadata :: map()

  @spec start_link(name: table_id()) :: {:ok, pid} | {:error, term}
  def start_link(options) do
    name = Keyword.get(options, :name)

    unless !is_nil(name) and is_atom(name) do
      raise ArgumentError, "expected :name to be given and to be an atom, got: #{inspect(name)}"
    end

    VintageNet.PropertyTable.Supervisor.start_link(name)
  end

  @doc """
  Returns a specification to start a property_table under a supervisor.
  See `Supervisor`.
  """
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, PropertyTable),
      start: {VintageNet.PropertyTable, :start_link, [opts]},
      type: :supervisor
    }
  end

  @doc """
  Subscribe to receive events
  """
  @spec subscribe(table_id(), property()) :: :ok
  def subscribe(table, name) when is_list(name) do
    assert_name(name)

    registry = VintageNet.PropertyTable.Supervisor.registry_name(table)
    {:ok, _} = Registry.register(registry, name, nil)

    :ok
  end

  @doc """
  Stop subscribing to a property
  """
  @spec unsubscribe(table_id(), property()) :: :ok
  def unsubscribe(table, name) when is_list(name) do
    registry = VintageNet.PropertyTable.Supervisor.registry_name(table)
    Registry.unregister(registry, name)
  end

  @doc """
  Get the current value of a property
  """
  @spec get(table_id(), property(), value()) :: value()
  def get(table, name, default \\ nil) when is_list(name) do
    Table.get(table, name, default)
  end

  @doc """
  Get a list of all properties matching the specified prefix
  """
  @spec get_by_prefix(table_id(), property()) :: [{property(), value()}]
  def get_by_prefix(table, prefix) when is_list(prefix) do
    assert_name(prefix)

    Table.get_by_prefix(table, prefix)
  end

  @doc """
  Update a property and notify listeners
  """
  @spec put(table_id(), property(), value(), metadata()) :: :ok
  def put(table, name, value, metadata \\ %{}) when is_list(name) do
    Table.put(table, name, value, metadata)
  end

  @doc """
  Clear out a property
  """
  defdelegate clear(table, name), to: Table

  @doc """
  Clear out all properties under a prefix
  """
  defdelegate clear_prefix(table, name), to: Table

  defp assert_name(name) do
    Enum.all?(name, fn
      name when is_binary(name) -> true
      :_ -> true
      _ -> false
    end) ||
      raise ArgumentError, "Expected name or prefix to be a list of strings"
  end
end
