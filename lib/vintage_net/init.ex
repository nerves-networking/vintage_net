defmodule VintageNet.Init do
  use GenServer, restart: :transient

  alias VintageNet.Config
  alias VintageNet.Interface.Supervisor, as: IS

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    state =
      Enum.map(args, fn
        {:config, configs} -> {:config, Config.make(configs)}
        other -> other
      end)
      |> Map.new()

    {:ok, state, {:continue, :init_config}}
  end

  def handle_continue(:init_config, state) do
    Enum.each(state.config, fn iface ->
      IS.start_interface(iface)
    end)

    {:stop, :normal, state}
  end
end
