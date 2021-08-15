defmodule VintageNet.Interface.LANConnectivityChecker do
  require Logger

  @moduledoc false

  def child_spec(opts) do
    warn()

    %{
      id: VintageNet.Connectivity.LANChecker,
      start: {VintageNet.Connectivity.LANChecker, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @doc false
  @deprecated "Use VintageNet.Connectivity.LANChecker now"
  @spec start_link(VintageNet.ifname()) :: GenServer.on_start()
  def start_link(ifname) do
    warn()
    GenServer.start_link(VintageNet.Connectivity.LANChecker, ifname)
  end

  defp warn() do
    Logger.warn(
      "VintageNet.Interface.LANConnectivityChecker is now VintageNet.Connectivity.LANChecker"
    )
  end
end
