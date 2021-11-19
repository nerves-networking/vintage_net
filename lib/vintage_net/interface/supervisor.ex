defmodule VintageNet.Interface.Supervisor do
  @moduledoc false
  use Supervisor

  @doc """
  Start the interface supervisor
  """
  @spec start_link(VintageNet.ifname()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(ifname) do
    Supervisor.start_link(__MODULE__, ifname, name: via_name(ifname))
  end

  defp via_name(ifname) do
    {:via, Registry, {VintageNet.Interface.Registry, {__MODULE__, ifname}}}
  end

  @impl Supervisor
  def init(ifname) do
    children = [
      {VintageNet.Interface, ifname}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  @doc """
  Add child_specs provided by technologies to supervision
  """
  @spec set_technology(VintageNet.ifname(), Supervisor.strategy(), [
          :supervisor.child_spec() | {module(), term()} | module()
        ]) ::
          :ok
  def set_technology(ifname, _restart_strategy, []) do
    clear_technology(ifname)
  end

  def set_technology(ifname, restart_strategy, child_specs) when is_list(child_specs) do
    clear_technology(ifname)

    supervisor_spec = %{
      id: :technology,
      start: {Supervisor, :start_link, [child_specs, [strategy: restart_strategy]]}
    }

    {:ok, _pid} = Supervisor.start_child(via_name(ifname), supervisor_spec)

    :ok
  end

  @doc """
  Clear out children and child_specs from a technology
  """
  @spec clear_technology(VintageNet.ifname()) :: :ok
  def clear_technology(ifname) do
    name = via_name(ifname)

    with :ok <- Supervisor.terminate_child(name, :technology) do
      Supervisor.delete_child(name, :technology)
    end

    :ok
  end
end
