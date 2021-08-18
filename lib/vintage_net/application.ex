defmodule VintageNet.Application do
  @moduledoc false
  require Logger

  use Application

  alias VintageNet.Persistence
  require Logger

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
      {VintageNet.RouteManager, args},
      {Registry, keys: :unique, name: VintageNet.Interface.Registry},
      VintageNet.InterfacesSupervisor
    ]

    opts = [strategy: :rest_for_one, name: VintageNet.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp load_initial_configurations() do
    # Get the default interface configurations
    configs = get_config_env() |> Map.new()

    persisted_ifnames = Persistence.call(:enumerate, [])

    Enum.reduce(persisted_ifnames, configs, &load_and_merge_config/2)
  end

  @doc """
  Return network configurations stored in the application environment

  This function is guaranteed to return a list of `{ifname, map}` tuples even
  if the application environment is messed up. Invalid entries generate log
  messages.
  """
  @spec get_config_env() :: [{VintageNet.ifname(), map()}]
  def get_config_env() do
    # Configurations can be stored either under :default_config or :config.
    # :config is the old way which is used a lot, but causes confusion if
    # you've overwritten the network configuration on a device. E.g., why
    # doesn't my network configuration change when I change the config.exs?

    configs =
      Application.get_env(:vintage_net, :default_config) ||
        Application.get_env(:vintage_net, :config)

    if is_list(configs) do
      Enum.filter(configs, &valid_config?/1)
    else
      []
    end
  end

  # Minimally check configurations to make sure they at least have the right form.
  defp valid_config?({ifname, %{type: type}}) when is_binary(ifname) and is_atom(type), do: true

  defp valid_config?(config) do
    Logger.warn("VintageNet: Dropping invalid configuration #{inspect(config)}")

    false
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
