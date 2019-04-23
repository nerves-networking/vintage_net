defmodule VintageNet.Interface.Supervisor do
  use Supervisor

  def start_link(iface) do
    Supervisor.start_link(__MODULE__, iface)
  end

  @impl true
  def init({ifname, _} = iface) do
    children = [
      {VintageNet.Interface.ConnectivityChecker, ifname},
      VintageNet.Interface.CommandRunner,
      {VintageNet.Interface, iface}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
