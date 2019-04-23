defmodule PropertyTable do
  @moduledoc """
  Documentation for PropertyTable.
  """
  alias PropertyTable.Table

  @type table() :: atom()

  @type property_name :: [String.t()]
  @type property_value :: any()

  @spec start_link(name: table()) :: {:ok, pid} | {:error, term}
  def start_link(options) do
    name = Keyword.get(options, :name)

    unless !is_nil(name) and is_atom(name) do
      raise ArgumentError, "expected :name to be given and to be an atom, got: #{inspect(name)}"
    end

    PropertyTable.Supervisor.start_link(name)
  end

  @doc """
  Returns a specification to start a property_table under a supervisor.
  See `Supervisor`.
  """
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, PropertyTable),
      start: {PropertyTable, :start_link, [opts]},
      type: :supervisor
    }
  end

  @doc """
  Subscribe to receive events
  """
  @spec subscribe(table(), property_name()) :: :ok
  def subscribe(table, name) when is_list(name) do
    assert_name(name)

    registry = PropertyTable.Supervisor.registry_name(table)
    {:ok, _} = Registry.register(registry, name, nil)

    :ok
  end

  @spec unsubscribe(table(), property_name()) :: :ok
  def unsubscribe(table, name) when is_list(name) do
    registry = PropertyTable.Supervisor.registry_name(table)
    Registry.unregister(registry, name)
  end

  @doc """
  Get the current value of a property
  """
  @spec get(table(), property_name(), property_value()) :: property_value()
  def get(table, name, default \\ nil) when is_list(name) do
    Table.get(table, name, default)
  end

  @doc """
  Get a list of all properties matching the specified prefix
  """
  @spec get_by_prefix(table(), property_name()) :: [{property_name(), property_value()}]
  def get_by_prefix(table, prefix) when is_list(prefix) do
    assert_name(prefix)

    Table.get_by_prefix(table, prefix)
  end

  @doc """
  Update a property and notify listeners
  """
  @spec put(table, property_name(), property_value()) :: :ok
  def put(table, name, value) when is_list(name) do
    Table.put(table, name, value)
  end

  @doc """
  Clear out a property
  """
  defdelegate clear(table, name), to: Table

  defp assert_name(name) do
    Enum.all?(name, &is_binary/1) ||
      raise ArgumentError, "Expected name or prefix to be a list of atoms"
  end
end
