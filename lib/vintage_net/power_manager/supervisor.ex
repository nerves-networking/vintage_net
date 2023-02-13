defmodule VintageNet.PowerManager.Supervisor do
  @moduledoc """
  Supervision for all of the power management controllers
  """
  use Supervisor
  require Logger

  @spec start_link(any()) :: Supervisor.on_start()
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl Supervisor
  def init(_) do
    power_manager_specs =
      Application.get_env(:vintage_net, :power_managers)
      |> Enum.flat_map(&power_manager_to_spec/1)

    children =
      [
        {Registry, keys: :unique, name: VintageNet.PowerManager.Registry}
      ] ++ power_manager_specs

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp power_manager_to_spec({module, args}) when is_atom(module) and is_list(args) do
    with {:ok, ifname} <- fetch_ifname(args),
         :ok <- check_module(module) do
      id = Module.concat(VintageNet.PowerManager.PMControl, ifname)

      [
        Supervisor.child_spec(
          {VintageNet.PowerManager.PMControl, impl: module, impl_args: args},
          id: id
        )
      ]
    else
      {:error, reason} ->
        Logger.warning("Ignoring power management spec for #{module} since #{reason}")
        []
    end
  end

  defp power_manager_to_spec(other) do
    Logger.warning("Ignoring invalid power manager spec #{inspect(other)}")
    []
  end

  defp fetch_ifname(args) do
    case Keyword.fetch(args, :ifname) do
      {:ok, ifname} -> {:ok, ifname}
      :error -> {:error, "missing `:ifname` key"}
    end
  end

  defp check_module(module) do
    case Code.ensure_loaded?(module) do
      true -> :ok
      false -> {:error, "invalid module"}
    end
  end
end
