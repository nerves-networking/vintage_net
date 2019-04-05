defmodule VintageNet.Application do
  @moduledoc false

  use Application

  @spec start(Application.start_type(), any()) ::
          {:ok, pid()} | {:ok, pid(), Application.state()} | {:error, reason :: any()}
  def start(_type, _args) do
    children = [
      {VintageNet.Applier, []},
      {VintageNet.Interface.Supervisor, []}
    ]

    opts = [strategy: :one_for_one, name: VintageNet.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
