defmodule VintageNet.PropertyTable.Table do
  use GenServer

  alias VintageNet.PropertyTable

  @moduledoc false

  @spec start_link({PropertyTable.table_id(), Registry.registry()}) :: GenServer.on_start()
  def start_link({table, _registry_name} = args) do
    GenServer.start_link(__MODULE__, args, name: table)
  end

  @spec get(PropertyTable.table_id(), PropertyTable.property(), PropertyTable.value()) ::
          PropertyTable.value()
  def get(table, name, default) do
    case :ets.lookup(table, name) do
      [{^name, value}] -> value
      [] -> default
    end
  end

  @spec get_by_prefix(PropertyTable.table_id(), PropertyTable.property()) :: [
          {PropertyTable.property(), PropertyTable.value()}
        ]
  def get_by_prefix(table, prefix) do
    matchspec = {append(prefix), :"$2"}

    :ets.match(table, matchspec)
    |> Enum.map(fn [k, v] -> {prefix ++ k, v} end)
    |> Enum.sort()
  end

  defp append([]), do: :"$1"
  defp append([h]), do: [h | :"$1"]
  defp append([h | t]), do: [h | append(t)]

  @doc """
  Update or add a property

  If the property changed, this will send events to all listeners.
  """
  @spec put(
          PropertyTable.table_id(),
          PropertyTable.property(),
          PropertyTable.value(),
          PropertyTable.metadata()
        ) ::
          :ok

  def put(table, name, nil, _metadata) do
    clear(table, name)
  end

  def put(table, name, value, metadata) do
    GenServer.call(table, {:put, name, value, metadata})
  end

  @doc """
  Clear a property

  If the property changed, this will send events to all listeners.
  """
  @spec clear(PropertyTable.table_id(), PropertyTable.property()) :: :ok
  def clear(table, name) when is_list(name) do
    GenServer.call(table, {:clear, name})
  end

  @doc """
  Clear out all of the properties under a prefix
  """
  @spec clear_prefix(PropertyTable.table_id(), PropertyTable.property()) :: :ok
  def clear_prefix(table, name) when is_list(name) do
    GenServer.call(table, {:clear_prefix, name})
  end

  @impl true
  def init({table, registry_name}) do
    ^table = :ets.new(table, [:named_table, read_concurrency: true])

    state = %{table: table, registry: registry_name}
    {:ok, state}
  end

  @impl true
  def handle_call({:put, name, value, metadata}, _from, state) do
    case :ets.lookup(state.table, name) do
      [{^name, ^value}] ->
        # No change, so no notifications
        :ok

      [{^name, old_value}] ->
        :ets.insert(state.table, {name, value})
        dispatch(state, name, old_value, value, metadata)

      [] ->
        :ets.insert(state.table, {name, value})
        dispatch(state, name, nil, value, metadata)
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:clear, name}, _from, state) do
    case :ets.lookup(state.table, name) do
      [{^name, old_value}] ->
        :ets.delete(state.table, name)
        dispatch(state, name, old_value, nil, %{})

      [] ->
        :ok
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:clear_prefix, prefix}, _from, state) do
    to_delete = get_by_prefix(state.table, prefix)
    metadata = %{}

    # Delete everything first and then send notifications so
    # if handlers call "get", they won't see something that
    # will be deleted shortly.
    Enum.each(to_delete, fn {name, _value} ->
      :ets.delete(state.table, name)
    end)

    Enum.each(to_delete, fn {name, value} ->
      dispatch(state, name, value, nil, metadata)
    end)

    {:reply, :ok, state}
  end

  defp dispatch(state, name, old_value, new_value, metadata) do
    message = {state.table, name, old_value, new_value, metadata}

    Registry.match(state.registry, :property_registry, :_)
    |> Enum.each(fn {pid, match} ->
      is_property_match?(match, name) && send(pid, message)
    end)
  end

  defp is_property_match?([], _name), do: true

  defp is_property_match?([value | match_rest], [value | name_rest]) do
    is_property_match?(match_rest, name_rest)
  end

  defp is_property_match?([:_ | match_rest], [_any | name_rest]) do
    is_property_match?(match_rest, name_rest)
  end

  defp is_property_match?(_match, _name), do: false
end
