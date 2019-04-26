defmodule VintageNet.Interface2 do
  use GenStateMachine

  require Logger

  alias VintageNet.IP
  alias VintageNet.Interface.{CommandRunner, RawConfig}

  defmodule State do
    @moduledoc false

    defstruct ifname: nil,
              config: nil,
              next_config: nil,
              command_runner: nil,
              waiters: []
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

  defp server_name(ifname) do
    Module.concat(VintageNet.Interfaces, ifname)
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

  @doc """
  Wait for the interface to be configured or unconfigured
  """
  @spec wait_until_configured(String.t()) :: :ok
  def wait_until_configured(ifname) do
    GenStateMachine.call(server_name(ifname), :wait)
  end

  # @spec status(String.t()) :: status()
  # def status(interface) do
  #   interface
  #   |> server_name()
  #   |> GenServer.call(:status)
  # end

  @impl true
  def init(args) do
    Process.flag(:trap_exit, true)

    Logger.debug("interface2 starting")
    ifname = Keyword.get(args, :ifname)
    config = Keyword.get(args, :config)

    cleanup_interface(ifname)

    initial_data = %State{ifname: ifname}

    next_actions = if config, do: [{:next_event, :internal, {:configure, config}}], else: []

    {:ok, :unconfigured, initial_data, next_actions}
  end

  # :unconfigured

  def handle_event({:call, from}, :wait, :unconfigured, %State{} = data) do
    Logger.debug(":unconfigured -> wait")

    {:keep_state, data, {:reply, from, :ok}}
  end

  @impl true
  def handle_event(:internal, {:configure, config}, :unconfigured, %State{} = data) do
    Logger.debug(":unconfigured -> internal configure")
    CommandRunner.create_files(config.files)
    new_data = run_commands(data, config.up_cmds)

    {:next_state, :configuring, %{new_data | config: config},
     {:state_timeout, config.up_cmd_millis, :configuring_timeout}}
  end

  @impl true
  def handle_event({:call, from}, {:configure, config}, :unconfigured, %State{} = data) do
    Logger.debug(":unconfigured -> configure")
    CommandRunner.create_files(config.files)
    new_data = run_commands(data, config.up_cmds)
    action = [{:reply, from, :ok}, {:state_timeout, config.up_cmd_millis, :configuring_timeout}]
    {:next_state, :configuring, %{new_data | config: config}, action}
  end

  # :configuring

  @impl true
  def handle_event(:info, {:commands_done, :ok}, :configuring, %State{} = data) do
    # TODO
    Logger.debug(":configuring -> done success")
    {new_data, actions} = reply_to_waiters(data)
    new_data = %{new_data | command_runner: nil}
    {:next_state, :configured, new_data, actions}
  end

  @impl true
  def handle_event(
        :info,
        {:commands_done, {:error, _reason}},
        :configuring,
        %State{config: config} = data
      ) do
    Logger.debug(":configuring -> done error")
    {new_data, actions} = reply_to_waiters(data)
    new_data = %{new_data | command_runner: nil}
    actions = [{:state_timeout, config.retry_millis, :retry_timeout} | actions]
    {:next_state, :retrying, new_data, actions}
  end

  @impl true
  def handle_event(
        :info,
        {:EXIT, pid, reason},
        :configuring,
        %State{command_runner: pid, config: config} = data
      ) do
    Logger.debug(":configuring -> done crash (#{inspect(reason)})")
    {new_data, actions} = reply_to_waiters(data)
    new_data = %{new_data | command_runner: nil}
    actions = [{:state_timeout, config.retry_millis, :retry_timeout} | actions]
    {:next_state, :retrying, new_data, actions}
  end

  @impl true
  def handle_event(
        :state_timeout,
        _event,
        :configuring,
        %State{command_runner: pid, config: config} = data
      ) do
    Logger.debug(":configuring -> recovering from hang")
    Process.exit(pid, :kill)
    {new_data, actions} = reply_to_waiters(data)
    new_data = %{new_data | command_runner: nil}
    actions = [{:state_timeout, config.retry_millis, :retry_timeout} | actions]
    {:next_state, :retrying, new_data, actions}
  end

  # :configured

  def handle_event({:call, from}, :wait, :configured, %State{} = data) do
    Logger.debug(":configured -> wait")
    {:keep_state, data, {:reply, from, :ok}}
  end

  @impl true
  def handle_event({:call, from}, :unconfigure, :configured, %State{config: config} = data) do
    # TODO
    Logger.debug(":configured -> unconfigure")
    new_data = run_commands(data, config.down_cmds)

    action = [
      {:reply, from, :ok},
      {:state_timeout, config.down_cmd_millis, :unconfiguring_timeout}
    ]

    {:next_state, :unconfiguring, new_data, action}
  end

  @impl true
  def handle_event(
        {:call, from},
        {:configure, new_config},
        :configured,
        %State{config: old_config} = data
      ) do
    # TODO
    Logger.debug(":configured -> configure")
    new_data = run_commands(data, old_config.down_cmds)

    action = [
      {:reply, from, :ok},
      {:state_timeout, old_config.down_cmd_millis, :unconfiguring_timeout}
    ]

    {:next_state, :reconfiguring, %{new_data | next_config: new_config}, action}
  end

  # :unconfiguring

  @impl true
  def handle_event(:info, {:commands_done, :ok}, :unconfiguring, %State{config: config} = data) do
    # TODO
    Logger.debug(":unconfiguring -> done success")
    CommandRunner.remove_files(config.files)
    {new_data, actions} = reply_to_waiters(data)
    new_data = %{new_data | command_runner: nil, config: nil}
    {:next_state, :unconfigured, new_data, actions}
  end

  @impl true
  def handle_event(
        :info,
        {:commands_done, {:error, _reason}},
        :unconfiguring,
        %State{config: config} = data
      ) do
    # TODO
    Logger.debug(":unconfiguring -> done error")
    CommandRunner.remove_files(config.files)
    {new_data, actions} = reply_to_waiters(data)
    new_data = %{new_data | command_runner: nil, config: nil}
    {:next_state, :unconfigured, new_data, actions}
  end

  @impl true
  def handle_event(
        :info,
        {:EXIT, pid, reason},
        :unconfiguring,
        %State{config: config, command_runner: pid} = data
      ) do
    # TODO
    Logger.debug(":unconfiguring -> done crash (#{inspect(reason)})")
    CommandRunner.remove_files(config.files)
    {new_data, actions} = reply_to_waiters(data)
    new_data = %{new_data | command_runner: nil, config: nil}
    {:next_state, :unconfigured, new_data, actions}
  end

  @impl true
  def handle_event(
        :state_timeout,
        _event,
        :unconfiguring,
        %State{command_runner: pid, config: config} = data
      ) do
    Logger.debug(":unconfiguring -> recovering from hang")
    Process.exit(pid, :kill)
    CommandRunner.remove_files(config.files)
    {new_data, actions} = reply_to_waiters(data)
    new_data = %{new_data | command_runner: nil, config: nil}
    {:next_state, :unconfigured, new_data, actions}
  end

  # :reconfiguring

  @impl true
  def handle_event(
        :info,
        {:commands_done, :ok},
        :reconfiguring,
        %State{config: config, next_config: new_config} = data
      ) do
    # TODO
    Logger.debug(":reconfiguring -> done success")
    CommandRunner.remove_files(config.files)
    CommandRunner.create_files(new_config.files)
    new_data = run_commands(data, new_config.up_cmds)

    action = [
      {:state_timeout, new_config.up_cmd_millis, :configuring_timeout}
    ]

    {:next_state, :configuring, %{new_data | config: new_config, next_config: nil}, action}
  end

  @impl true
  def handle_event(
        :info,
        {:commands_done, {:error, _reason}},
        :reconfiguring,
        %State{config: config, next_config: new_config} = data
      ) do
    # TODO
    Logger.debug(":reconfiguring -> done error")
    CommandRunner.remove_files(config.files)
    CommandRunner.create_files(new_config.files)
    new_data = run_commands(data, new_config.up_cmds)

    action = [
      {:state_timeout, new_config.up_cmd_millis, :configuring_timeout}
    ]

    {:next_state, :configuring, %{new_data | config: new_config, next_config: nil}, action}
  end

  @impl true
  def handle_event(
        :info,
        {:EXIT, pid, reason},
        :reconfiguring,
        %State{config: config, command_runner: pid, next_config: new_config} = data
      ) do
    # TODO
    Logger.debug(":reconfiguring -> done crash (#{inspect(reason)})")
    CommandRunner.remove_files(config.files)
    CommandRunner.create_files(new_config.files)
    new_data = run_commands(data, new_config.up_cmds)

    action = [
      {:state_timeout, new_config.up_cmd_millis, :configuring_timeout}
    ]

    {:next_state, :configuring, %{new_data | config: new_config, next_config: nil}, action}
  end

  @impl true
  def handle_event(
        :state_timeout,
        _event,
        :reconfiguring,
        %State{command_runner: pid, config: config, next_config: new_config} = data
      ) do
    Logger.debug(":reconfiguring -> recovering from hang")
    Process.exit(pid, :kill)
    CCommandRunner.remove_files(config.files)
    CommandRunner.create_files(new_config.files)
    new_data = run_commands(data, new_config.up_cmds)

    action = [
      {:state_timeout, new_config.up_cmd_millis, :configuring_timeout}
    ]

    {:next_state, :configuring, %{new_data | config: new_config, next_config: nil}, action}
  end

  # :retrying

  @impl true
  def handle_event({:call, from}, :unconfigure, :retrying, %State{config: config} = data) do
    # TODO
    Logger.debug(":retrying -> unconfigure")
    CommandRunner.remove_files(config.files)
    action = {:reply, from, :ok}
    {:next_state, :unconfigured, %{data | config: nil}, action}
  end

  @impl true
  def handle_event(:state_timeout, _event, :retrying, %State{config: config} = data) do
    CommandRunner.create_files(config.files)
    new_data = run_commands(data, config.up_cmds)
    {:next_state, :configuring, new_data}
  end

  # Catch all event handlers
  @impl true
  def handle_event(:info, {:EXIT, _pid, _reason}, state, data) do
    # Ignore normal command runner exits
    Logger.debug("#{inspect(state)} -> process exit (ignoring)")
    {:keep_state, data}
  end

  @impl true
  def handle_event(
        {:call, from},
        :wait,
        other_state,
        %State{waiters: waiters} = data
      ) do
    Logger.debug("#{inspect(other_state)} -> wait")
    {:keep_state, %{data | waiters: [from | waiters]}}
  end

  defp reply_to_waiters(data) do
    actions = for from <- data.waiters, do: {:reply, from, :ok}
    {%{data | waiters: []}, actions}
  end

  defp run_commands(data, commands) do
    interface_pid = self()
    {:ok, pid} = Task.start_link(fn -> run_commands_and_report(commands, interface_pid) end)
    %{data | command_runner: pid}
  end

  defp run_commands_and_report(commands, interface_pid) do
    Logger.debug("Running commands: #{inspect(commands)}")
    result = CommandRunner.run(commands)
    Logger.debug("Done. Sending response")
    send(interface_pid, {:commands_done, result})
  end

  defp cleanup_interface(_ifname) do
    # This function is called to restore the filesystem to a pristine
    # state or as close as possible to one. It is called from `init/1`
    # so it can't fail.

    # TODO!!!
  end
end
