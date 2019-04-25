defmodule VintageNet.Interface2 do
  use GenStateMachine

  require Logger

  alias VintageNet.IP

  defmodule State do
    @moduledoc false

    defstruct ifname: nil,
              config: nil
  end

  @doc """
  Start up an interface with an initial configuration

  Parameters:

  * `ifname`: the name of the interface (like `eth0`)
  * `config`: an initial configuration for the interface
  """
  @spec start_link(ifname: String.t(), config: map()) :: GenServer.on_start()
  def start_link(args) do
    ifname = Keyword.fetch!(args, :ifname)

    GenStateMachine.start_link(__MODULE__, args, name: server_name(ifname))
  end

  @doc """
  Stop the interface

  Note that this doesn't unconfigure it.
  """
  def stop(ifname) do
    GenStateMachine.stop(server_name(ifname))
  end

  @doc """
  Set a configuration on an interface
  """
  @spec configure(String.t(), map()) :: :ok
  def configure(ifname, config) do
    GenStateMachine.call(server_name(ifname), {:configure, config})
  end

  @doc """
  Unconfigure the interface

  This doesn't exit this GenServer, but the interface
  won't be usable in any real way until it's configured
  again.

  This function is not normally called.
  """
  @spec unconfigure(String.t()) :: :ok
  def unconfigure(ifname) do
    GenStateMachine.call(server_name(ifname), :unconfigure)
  end

  # @spec status(String.t()) :: status()
  # def status(interface) do
  #   interface
  #   |> server_name()
  #   |> GenServer.call(:status)
  # end

  @impl true
  def init(args) do
    ifname = Keyword.get(args, :ifname)
    config = Keyword.get(args, :config)

    cleanup_interface(ifname)

    initial_data = %State{ifname: ifname}

    next_actions = if config, do: [{:next_event, :internal, {:configure, config}}], else: []

    {:ok, :unconfigured, initial_data, next_actions}
  end

  @impl true
  def handle_event(:internal, {:configure, config}, :unconfigured, %State{} = data) do
    # TODO
    {:next_state, :configuring, data}
  end

  @impl true
  def handle_event({:call, from}, {:configure, config}, :unconfigured, %State{} = data) do
    # TODO
    action = {:reply, from, :ok}
    {:next_state, :configuring, data, action}
  end

  @impl true
  def handle_event({:call, from}, :unconfigure, :unconfigured, %State{} = data) do
    # TODO
    action = {:reply, from, :ok}
    {:next_state, :unconfiguring, data, action}
  end

  defp server_name(ifname) do
    Module.concat(VintageNet.Interfaces, ifname)
  end

  defp cleanup_interface(ifname) do
    # This function is called to restore the filesystem to a pristine
    # state or as close as possible to one. It is called from `init/1`
    # so it can't fail.

    # TODO!!!
  end
end
