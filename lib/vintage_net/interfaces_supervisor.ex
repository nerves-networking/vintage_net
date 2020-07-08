defmodule VintageNet.InterfacesSupervisor do
  use DynamicSupervisor
  alias VintageNet.PredictableInterfaceName
  require Logger

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

  @impl DynamicSupervisor
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  defp start_configured_interfaces() do
    VintageNet.match(["interface", :_, "config"])
    |> Enum.map(fn {["interface", ifname, "config"], _value} -> ifname end)
    |> Enum.filter(&check_predictable_ifnames/1)
    |> Enum.each(&start_interface/1)
  end

  defp check_predictable_ifnames(ifname) do
    case PredictableInterfaceName.precheck(ifname) do
      :ok ->
        true

      {:error, _} ->
        Logger.warn(
          "VintageNet not configuring #{ifname} because predictable interface naming is enabled"
        )

        false
    end
  end
end
