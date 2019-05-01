defmodule VintageNet.Interface.Supervisor do
  use Supervisor

  @spec start_link(String.t()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(ifname) do
    Supervisor.start_link(__MODULE__, ifname, name: via_name(ifname))
  end

  defp via_name(ifname) do
    {:via, Registry, {VintageNet.Interface.Registry, {__MODULE__, ifname}}}
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
  @spec set_technology(String.t(), [:supervisor.child_spec() | {module(), term()} | module()]) ::
          :ok
  def set_technology(ifname, []) do
    clear_technology(ifname)
  end

  def set_technology(ifname, child_specs) when is_list(child_specs) do
    clear_technology(ifname)

    supervisor_spec = %{
      id: :technology,
      start: {Supervisor, :start_link, [child_specs, [strategy: :one_for_all]]}
    }

    {:ok, _pid} = Supervisor.start_child(via_name(ifname), supervisor_spec)

    :ok
  end

  @doc """
  Clear out children and child_specs from a technology
  """
  @spec clear_technology(String.t()) :: :ok
  def clear_technology(ifname) do
    name = via_name(ifname)

    with :ok <- Supervisor.terminate_child(name, :technology) do
      Supervisor.delete_child(name, :technology)
    end

    :ok
  end
end
