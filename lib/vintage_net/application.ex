defmodule VintageNet.Application do
  @moduledoc false
  require Logger

  use Application

  alias VintageNet.Persistence

  @spec start(Application.start_type(), any()) ::
          {:ok, pid()} | {:ok, pid(), Application.state()} | {:error, reason :: any()}
  def start(_type, _args) do
    args = Application.get_all_env(:vintage_net)
    socket_path = Path.join(Keyword.get(args, :tmpdir), Keyword.get(args, :to_elixir_socket))
    hw_path_ifnames = Keyword.get(args, :ifnames, [])
    # Resolve paths to all of the programs that might be used.
    if using_elixir_busybox() do
      args
      |> resolve_paths(&resolve_busybox_path/1)
      |> put_env()

      Application.put_env(:vintage_net, :path, busybox_path() |> Enum.join(":"))
    else
      args
      |> resolve_paths(&resolve_standard_path/1)
      |> put_env()
    end

    # Load the initial interface configuration and store in the
    # property table
    properties = load_initial_configurations() |> Enum.map(&config_to_property/1)

    children = [
      {VintageNet.PropertyTable, properties: properties, name: VintageNet},
      {VintageNet.PredictableInterfaceName, hw_path_ifnames},
      VintageNet.InterfacesMonitor,
      {VintageNet.ToElixir.Server, socket_path},
      {VintageNet.NameResolver, args},
      VintageNet.RouteManager,
      {Registry, keys: :unique, name: VintageNet.Interface.Registry},
      VintageNet.InterfacesSupervisor
    ]

    opts = [strategy: :rest_for_one, name: VintageNet.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp using_elixir_busybox() do
    Code.ensure_loaded?(Busybox)
  end

  defp put_env(list) do
    Enum.each(list, fn {k, v} -> Application.put_env(:vintage_net, k, v) end)
  end

  defp resolve_paths(env, resolver) do
    env
    |> Enum.filter(fn {k, _v} -> String.starts_with?(to_string(k), "bin_") end)
    |> Enum.filter(fn {_k, v} -> !String.starts_with?(v, "/") end)
    |> Enum.map(resolver)
  end

  defp resolve_busybox_path({key, program_name}) do
    case apply(Busybox, :find_executable, [program_name]) do
      nil ->
        resolve_standard_path({key, program_name})

      path ->
        {key, path}
    end
  end

  defp busybox_path() do
    apply(Busybox, :path, [])
  end

  defp resolve_standard_path({key, program_name}) do
    case System.find_executable(program_name) do
      nil ->
        {key, program_name}

      path ->
        {key, path}
    end
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
