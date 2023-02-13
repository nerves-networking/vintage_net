defmodule VintageNet.Interface.InternetConnectivityChecker do
  @moduledoc false
  require Logger

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    warn()

    %{
      id: VintageNet.Connectivity.InternetChecker,
      start: {VintageNet.Connectivity.InternetChecker, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @doc false
  @deprecated "Use VintageNet.Connectivity.InternetChecker now"
  @spec start_link(VintageNet.ifname()) :: GenServer.on_start()
  def start_link(ifname) do
    warn()
    GenServer.start_link(VintageNet.Connectivity.InternetChecker, ifname)
  end

  defp warn() do
    Logger.warning(
      "VintageNet.Interface.InternetConnectivityChecker is now VintageNet.Connectivity.InternetChecker"
    )
  end
end
