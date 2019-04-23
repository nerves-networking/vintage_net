defmodule PropertyTable.Table do
  use GenServer

  @doc """
  """
  @spec start_link({PropertyTable.table(), Registry.registry()}) :: GenServer.on_start()
  def start_link({table, _registry_name} = args) do
    GenServer.start_link(__MODULE__, args, name: table)
  end

  @doc """
  Looks up the bucket pid for `name` stored in `server`.

  Returns `{:ok, pid}` if the bucket exists, `:error` otherwise.
  """
  @spec get(PropertyTable.table(), PropertyTable.property_name(), PropertyTable.property_value()) ::
          PropertyTable.property_value()
  def get(table, name, default) do
    case :ets.lookup(table, name) do
      [{^name, value}] -> value
      [] -> default
    end
  end

  @spec get_by_prefix(PropertyTable.table(), PropertyTable.property_name()) :: [
          {PropertyTable.property_name(), PropertyTable.property_value()}
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
  @spec put(PropertyTable.table(), PropertyTable.property_name(), PropertyTable.property_value()) ::
          :ok
  def put(table, name, value) do
    GenServer.call(table, {:put, name, value})
  end

  @doc """
  Clear a property

  If the property changed, this will send events to all listeners.
  """
  @spec clear(PropertyTable.table(), PropertyTable.property_name()) :: :ok
  def clear(table, name) when is_list(name) do
    GenServer.call(table, {:clear, name})
  end

  @impl true
  def init({table, registry_name}) do
    ^table = :ets.new(table, [:named_table, read_concurrency: true])

    state = %{table: table, registry: registry_name}
    {:ok, state}
  end

  @impl true
  def handle_call({:put, name, value}, _from, state) do
    case :ets.lookup(state.table, name) do
      [{^name, ^value}] ->
        # No change, so no notifications
        :ok

      [{^name, old_value}] ->
        :ets.insert(state.table, {name, value})
        dispatch(state, name, old_value, value)

      [] ->
        :ets.insert(state.table, {name, value})
        dispatch(state, name, nil, value)
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:clear, name}, _from, state) do
    case :ets.lookup(state.table, name) do
      [{^name, old_value}] ->
        :ets.delete(state.table, name)
        dispatch(state, name, old_value, nil)

      [] ->
        :ok
    end

    {:reply, :ok, state}
  end

  defp dispatch(state, name, old_value, new_value) do
    message = {state.table, name, old_value, new_value}
    dispatch_all_prefixes(state.registry, name, message)
  end

  defp dispatch_all_prefixes(registry, name, message) do
    all_prefixes(name)
    |> Enum.each(fn prefix -> dispatch_exact(registry, prefix, message) end)
  end

  defp dispatch_exact(registry, name, message) do
    Registry.dispatch(registry, name, fn entries ->
      for {pid, _} <- entries, do: send(pid, message)
    end)
  end

  defp all_prefixes(name) do
    reversed = Enum.reverse(name)
    all_suffixes([name], reversed)
  end

  defp all_suffixes(acc, []), do: acc

  defp all_suffixes(acc, [_h | t]) do
    reversed_t = Enum.reverse(t)
    all_suffixes([reversed_t | acc], t)
  end
end
