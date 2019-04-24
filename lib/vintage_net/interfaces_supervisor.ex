defmodule VintageNet.InterfacesSupervisor do
  use DynamicSupervisor

  def start_link(_) do
    {:ok, pid} = DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)

    start_configured_interfaces()

    {:ok, pid}
  end

  def start_interface(iface) do
    DynamicSupervisor.start_child(__MODULE__, {VintageNet.Interface.Supervisor, iface})
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  defp start_configured_interfaces() do
    args = Application.get_all_env(:vintage_net)

    Enum.map(args, fn
      {:config, configs} -> {:config, VintageNet.Config.make(configs)}
      other -> other
    end)
    |> Keyword.get(:config)
    |> Enum.each(fn iface -> start_interface(iface) end)
  end
end
