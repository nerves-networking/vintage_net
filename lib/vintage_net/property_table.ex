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
  @type property_with_wildcards :: [String.t() | :_]
  @type value :: any()
  @type property_value :: {property(), value()}
  @type metadata :: map()

  @type options :: [name: table_id(), properties: [property_value()]]

  @spec start_link(options()) :: {:ok, pid} | {:error, term}
  def start_link(options) do
    name = Keyword.get(options, :name)

    unless !is_nil(name) and is_atom(name) do
      raise ArgumentError, "expected :name to be given and to be an atom, got: #{inspect(name)}"
    end

    VintageNet.PropertyTable.Supervisor.start_link(options)
  end

  @doc """
  Returns a specification to start a property_table under a supervisor.
  See `Supervisor`.
  """
  @spec child_spec(keyword()) :: Supervisor.child_spec()
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
  @spec subscribe(table_id(), property_with_wildcards()) :: :ok
  def subscribe(table, name) when is_list(name) do
    assert_property_with_wildcards(name)

    registry = VintageNet.PropertyTable.Supervisor.registry_name(table)
    {:ok, _} = Registry.register(registry, :property_registry, name)

    :ok
  end

  @doc """
  Stop subscribing to a property
  """
  @spec unsubscribe(table_id(), property_with_wildcards()) :: :ok
  def unsubscribe(table, name) when is_list(name) do
    registry = VintageNet.PropertyTable.Supervisor.registry_name(table)
    Registry.unregister(registry, :property_registry)
  end

  @doc """
  Get the current value of a property
  """
  @spec get(table_id(), property(), value()) :: value()
  def get(table, name, default \\ nil) when is_list(name) do
    assert_property(name)
    Table.get(table, name, default)
  end

  @doc """
  Fetch a property with the time that it was set

  Timestamps come from `System.monotonic_time()`
  """
  @spec fetch_with_timestamp(table_id(), property()) :: {:ok, value(), integer()} | :error
  def fetch_with_timestamp(table, name) when is_list(name) do
    assert_property(name)
    Table.fetch_with_timestamp(table, name)
  end

  @doc """
  Get a list of all properties matching the specified prefix
  """
  @spec get_by_prefix(table_id(), property()) :: [{property(), value()}]
  def get_by_prefix(table, prefix) when is_list(prefix) do
    assert_property(prefix)

    Table.get_by_prefix(table, prefix)
  end

  @doc """
  Get a list of all properties matching the specified prefix
  """
  @spec match(table_id(), property_with_wildcards()) :: [{property(), value()}]
  def match(table, pattern) when is_list(pattern) do
    assert_property_with_wildcards(pattern)

    Table.match(table, pattern)
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

  defp assert_property(name) do
    Enum.each(name, fn
      v when is_binary(v) -> :ok
      :_ -> raise ArgumentError, "Wildcards not allowed in this property"
      _ -> raise ArgumentError, "Property should be a list of strings"
    end)
  end

  defp assert_property_with_wildcards(name) do
    Enum.each(name, fn
      v when is_binary(v) -> :ok
      :_ -> :ok
      _ -> raise ArgumentError, "Property should be a list of strings"
    end)
  end
end
