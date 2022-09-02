defmodule VintageNet.Telemetry do
  @moduledoc false

  # Telemetry server that provides the necessary state for us to determine
  # the duration between an interface being internet connected and disconnected.

  use GenServer

  @doc """
  Start the telemetry server
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    VintageNet.subscribe(["interface", :_, "connection"])
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(
        {VintageNet, ["interface", ifname, "connection"], _old, :internet,
         %{new_timestamp: start_timestamp}},
        state
      ) do
    system_time = System.system_time()
    state = Map.put(state, ifname, start_timestamp)

    :telemetry.execute([:vintage_net, :connection, :start], %{system_time: system_time}, %{
      ifname: ifname
    })

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        {VintageNet, ["interface", ifname, "connection"], _old, :disconnected,
         %{new_timestamp: disconnect_ts}},
        state
      ) do
    case Map.get(state, ifname) do
      nil ->
        {:noreply, state}

      start_ts ->
        duration = disconnect_ts - start_ts

        :telemetry.execute([:vintage_net, :connection, :stop], %{duration: duration}, %{
          ifname: ifname
        })

        {:noreply, Map.drop(state, [ifname])}
    end
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
