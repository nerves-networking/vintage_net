defmodule VintageNet.InterfacesSupervisor do
  use DynamicSupervisor

  @moduledoc false

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_) do
    case DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__) do
      {:ok, pid} ->
        start_configured_interfaces()
        {:ok, pid}

      other ->
        other
    end
  end

  @spec start_interface(VintageNet.ifname()) ::
          :ignore | {:error, any()} | {:ok, pid()} | {:ok, pid(), any()}
  def start_interface(ifname) do
    DynamicSupervisor.start_child(__MODULE__, {VintageNet.Interface.Supervisor, ifname})
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  defp start_configured_interfaces() do
    VintageNet.match(["interface", :_, "config"])
    |> Enum.map(fn {["interface", ifname, "config"], _value} -> ifname end)
    |> Enum.each(&start_interface/1)
  end
end
