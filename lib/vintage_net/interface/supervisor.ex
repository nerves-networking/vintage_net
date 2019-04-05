defmodule VintageNet.Interface.Supervisor do
  use DynamicSupervisor

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, :arg, name: __MODULE__)
  end

  def start_interface(iface) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {VintageNet.Interface, iface}
    )
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
