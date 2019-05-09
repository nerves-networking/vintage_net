defmodule VintageNet.InterfacesMonitor do
  @moduledoc """
  Monitor available interfaces

  Currently this works by polling the system for what interfaces are visible. They may or may not be configured.
  """

  use GenServer

  alias VintageNet.PropertyTable

  @refresh 30_000

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Return a list of interfaces
  """
  @spec interfaces() :: [VintageNet.ifname()]
  def interfaces() do
    GenServer.call(__MODULE__, :interfaces)
  end

  @impl true
  def init(_args) do
    {:ok, refresh([]), @refresh}
  end

  @impl true
  def handle_call(:interfaces, _from, old_names) do
    new_names = refresh(old_names)
    {:reply, new_names, new_names, @refresh}
  end

  @impl true
  def handle_info(:timeout, old_names) do
    new_names = refresh(old_names)
    {:noreply, new_names, @refresh}
  end

  defp refresh(old_names) do
    new_names = get_interfaces()

    List.myers_difference(old_names, new_names)
    |> Enum.each(&publish_deltas/1)

    new_names
  end

  defp publish_deltas({:eq, _list}), do: :ok

  defp publish_deltas({:del, list}) do
    Enum.each(list, fn name -> PropertyTable.clear(VintageNet, property_name(name)) end)
  end

  defp publish_deltas({:ins, list}) do
    Enum.each(list, fn name ->
      PropertyTable.put(VintageNet, property_name(name), true)
    end)
  end

  defp property_name(name) do
    ["interface", name, "present"]
  end

  defp get_interfaces() do
    {:ok, addrs} = :inet.getifaddrs()
    for {name, _info} <- addrs, do: to_string(name)
  end
end
