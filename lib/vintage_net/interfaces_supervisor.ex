defmodule VintageNet.InterfacesSupervisor do
  use DynamicSupervisor

  alias VintageNet.Persistence

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_) do
    with {:ok, pid} <- DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__) do
      start_configured_interfaces()
      {:ok, pid}
    end
  end

  @doc """
  Return the currently known interfaces
  """
  @spec interfaces() :: [String.t()]
  def interfaces() do
    # TODO!!!!
    []
  end

  @spec start_interface(String.t()) ::
          :ignore | {:error, any()} | {:ok, pid()} | {:ok, pid(), any()}
  def start_interface(ifname) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {VintageNet.Interface.Supervisor, ifname}
    )
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  defp start_configured_interfaces() do
    Enum.each(enumerate_interfaces(), &start_interface/1)
  end

  defp enumerate_interfaces() do
    # Merge interfaces from the Application config and persistence

    app_ifnames = for %{ifname: ifname} <- Application.get_env(:vintage_net, :config), do: ifname
    persisted_ifnames = Persistence.call(:enumerate, [])

    Enum.concat(app_ifnames, persisted_ifnames) |> Enum.uniq()
  end
end
