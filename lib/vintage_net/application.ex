defmodule VintageNet.Application do
  @moduledoc false
  require Logger

  use Application

  alias VintageNet.Persistence

  @spec start(Application.start_type(), any()) ::
          {:ok, pid()} | {:ok, pid(), Application.state()} | {:error, reason :: any()}
  def start(_type, _args) do
    args = Application.get_all_env(:vintage_net)
    hw_path_ifnames = Keyword.get(args, :ifnames, [])

    # Load the initial interface configuration and store in the
    # property table
    properties = load_initial_configurations() |> Enum.map(&config_to_property/1)

    children = [
      {VintageNet.PropertyTable, properties: properties, name: VintageNet},
      {VintageNet.PredictableInterfaceName, hw_path_ifnames},
      VintageNet.PowerManager.Supervisor,
      {BEAMNotify,
       name: "vintage_net_comm",
       report_env: true,
       dispatcher: &VintageNet.OSEventDispatcher.dispatch/2},
      VintageNet.InterfacesMonitor,
      {VintageNet.NameResolver, args},
      VintageNet.RouteManager,
      {Registry, keys: :unique, name: VintageNet.Interface.Registry},
      VintageNet.InterfacesSupervisor
    ]

    opts = [strategy: :rest_for_one, name: VintageNet.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp load_initial_configurations() do
    # Get the default interface configurations
    configs = Application.get_env(:vintage_net, :config) |> Map.new()

    persisted_ifnames = Persistence.call(:enumerate, [])

    Enum.reduce(persisted_ifnames, configs, &load_and_merge_config/2)
  end

  defp load_and_merge_config(ifname, configs) do
    case Persistence.call(:load, [ifname]) do
      {:ok, config} ->
        Map.put(configs, ifname, config)

      {:error, reason} ->
        Logger.warn("VintageNet(#{ifname}): ignoring saved config due to #{inspect(reason)}")

        configs
    end
  end

  defp config_to_property({ifname, config}) do
    {["interface", ifname, "config"], config}
  end
end
