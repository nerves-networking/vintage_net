defmodule VintageNet.Interface.Supervisor do
  use Supervisor

  def start_link(ifname) do
    Supervisor.start_link(__MODULE__, ifname, name: server_name(ifname))
  end

  defp server_name(ifname) do
    Module.concat(__MODULE__, ifname)
  end

  @impl true
  def init(ifname) do
    children = [
      {VintageNet.Interface, ifname}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  @doc """
  Add child_specs provided by technologies to supervision
  """
  def set_technology(ifname, []) do
    clear_technology(ifname)
  end

  def set_technology(ifname, child_specs) do
    clear_technology(ifname)

    supervisor_child_spec = [{Supervisor, [child_specs, strategy: :one_for_one, id: :technology]}]
    Supervisor.start_child(server_name(ifname), supervisor_child_spec)
  end

  @doc """
  Clear out children and childspecs from a technology
  """
  def clear_technology(ifname) do
    name = server_name(ifname)

    with :ok <- Supervisor.terminate_child(name, :technology) do
      Supervisor.delete_child(name, :technology)
    end
  end
end
