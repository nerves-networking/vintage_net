defmodule VintageNet.Application do
  @moduledoc false

  use Application

  @spec start(Application.start_type(), any()) ::
          {:ok, pid()} | {:ok, pid(), Application.state()} | {:error, reason :: any()}
  def start(_type, _args) do
    args = Application.get_all_env(:vintage_net)
    socket_path = Path.join(Keyword.get(args, :tmpdir), Keyword.get(args, :to_elixir_socket))

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

    children = [
      {VintageNet.PropertyTable, name: VintageNet},
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
end
