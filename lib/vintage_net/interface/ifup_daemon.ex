defmodule VintageNet.Interface.IfupDaemon do
  @moduledoc """
  Wrap MuonTrap.Daemon to start and stop a program based on whether the network is up

  Unlike MuonTrap.Daemon, the arguments are called out in the child_spec so it looks like
  this:

  ```
  {VintageNet.Interface.IfupDaemon, ifname: ifname, command: program, args: arguments, opts: options]}
  ```
  """
  use GenServer
  require Logger

  @typedoc false
  @type init_args :: [
          ifname: VintageNet.ifname(),
          command: binary(),
          args: [binary()],
          opts: keyword()
        ]

  @enforce_keys [:ifname, :command, :args]
  defstruct [:ifname, :command, :args, :opts, :pid]

  @doc """
  Start the IfupDaemon
  """
  @spec start_link(init_args()) :: GenServer.on_start()
  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args)
  end

  @doc """
  Return whether the daemon is running
  """
  @spec running?(GenServer.server()) :: boolean()
  def running?(server) do
    GenServer.call(server, :running?)
  end

  @impl GenServer
  def init(init_args) do
    state = struct!(__MODULE__, init_args)
    {:ok, state, {:continue, :continue}}
  end

  @impl GenServer
  def handle_continue(:continue, %{ifname: ifname} = state) do
    VintageNet.subscribe(lower_up_property(ifname))

    new_state =
      case VintageNet.get(lower_up_property(ifname)) do
        true ->
          start_daemon(state)

        _not_true ->
          # If the physical layer isn't up, don't start until
          # we're notified that it is available.
          state
      end

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call(:running?, _from, state) do
    {:reply, state.pid != nil and Process.alive?(state.pid), state}
  end

  @impl GenServer
  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], _old_value, true, _meta},
        %{ifname: ifname} = state
      ) do
    # Physical layer is up. Optimistically assume that the LAN is accessible.
    {:noreply, start_daemon(state)}
  end

  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], _old_value, _false_or_nil, _meta},
        %{ifname: ifname} = state
      ) do
    # Physical layer is down or disconnected. We're definitely disconnected.
    {:noreply, stop_daemon(state)}
  end

  defp start_daemon(%{pid: nil} = state) do
    Logger.debug("[vintage_net(#{state.ifname})] starting #{state.command}")

    {:ok, pid} = MuonTrap.Daemon.start_link(state.command, state.args, state.opts)
    %{state | pid: pid}
  end

  defp start_daemon(state), do: state

  defp stop_daemon(%{pid: pid} = state) when is_pid(pid) do
    Logger.debug("[vintage_net(#{state.ifname})] stopping #{state.command}")

    if Process.alive?(pid), do: GenServer.stop(pid)

    %{state | pid: nil}
  end

  defp stop_daemon(state), do: state

  defp lower_up_property(ifname) do
    ["interface", ifname, "lower_up"]
  end
end
