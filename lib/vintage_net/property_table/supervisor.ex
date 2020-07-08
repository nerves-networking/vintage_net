defmodule VintageNet.PropertyTable.Supervisor do
  use Supervisor

  alias VintageNet.PropertyTable

  @moduledoc false

  @spec start_link(PropertyTable.options()) :: Supervisor.on_start()
  def start_link(options) do
    Supervisor.start_link(__MODULE__, options)
  end

  @impl Supervisor
  def init(options) do
    name = Keyword.fetch!(options, :name)
    properties = Keyword.get(options, :properties, [])
    registry_name = registry_name(name)

    children = [
      {VintageNet.PropertyTable.Table, {name, registry_name, properties}},
      {Registry, [keys: :duplicate, name: registry_name]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec registry_name(PropertyTable.table_id()) :: Registry.registry()
  def registry_name(name) do
    Module.concat(PropertyTable.Registry, name)
  end
end
