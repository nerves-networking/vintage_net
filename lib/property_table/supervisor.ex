defmodule PropertyTable.Supervisor do
  use Supervisor

  @doc """
  Start
  """
  @spec start_link(PropertyTable.table_id()) :: Supervisor.on_start()
  def start_link(name) do
    Supervisor.start_link(__MODULE__, name)
  end

  @impl true
  def init(name) do
    registry_name = registry_name(name)

    children = [
      {PropertyTable.Table, {name, registry_name}},
      {Registry, [keys: :duplicate, name: registry_name]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec registry_name(PropertyTable.table_id()) :: Registry.registry()
  def registry_name(name) do
    Module.concat(PropertyTable.Registry, name)
  end
end
