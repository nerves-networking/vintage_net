defmodule VintageNet.Interface do
  use GenStateMachine

  require Logger

  alias VintageNet.Interface.{CommandRunner, RawConfig}
  alias VintageNet.Persistence

  defmodule State do
    @moduledoc false

    defstruct ifname: nil,
              config: nil,
              next_config: nil,
              command_runner: nil,
              waiters: []
  end

  @doc """
  Start up an interface

  Parameters:

  * `ifname` - which interface
  """
  @spec start_link(String.t()) :: GenServer.on_start()
  def start_link(ifname) do
    GenStateMachine.start_link(__MODULE__, ifname, name: via_name(ifname))
  end

  defp via_name(ifname) do
    {:via, Registry, {VintageNet.Interface.Registry, ifname}}
  end

  @doc """
  Stop the interface

  Note that this doesn't unconfigure it.
  """
  def stop(ifname) do
    GenStateMachine.stop(via_name(ifname))
  end

  @doc """
  Convert a configuration to a raw one

  This can be used to validate a configuration without applying it.
  """
  @spec to_raw_config(String.t(), map()) :: {:ok, RawConfig.t()} | {:error, any()}
  def to_raw_config(ifname, config) do
    opts = Application.get_all_env(:vintage_net)

    with {:ok, technology} <- Map.fetch(config, :type),
         {:ok, raw_config} <- technology.to_raw_config(ifname, config, opts) do
      {:ok, raw_config}
    else
      :error -> {:error, :type_missing}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Set a configuration on an interface
  """
  @spec configure(String.t(), map()) :: :ok | {:error, any()}
  def configure(ifname, config) do
    opts = Application.get_all_env(:vintage_net)

    with {:ok, technology} <- Map.fetch(config, :type),
         {:ok, raw_config} <- technology.to_raw_config(ifname, config, opts) do
      configure(raw_config)
    else
      :error -> {:error, :type_missing}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Configure an interface the low level way with a "raw_config"
  """
  @spec configure(RawConfig.t()) :: :ok
  def configure(raw_config) do
    GenStateMachine.call(via_name(raw_config.ifname), {:configure, raw_config})
  end

  @doc """
  Return the current configuration
  """
  @spec get_configuration(String.t()) :: map()
  def get_configuration(ifname) do
    GenStateMachine.call(via_name(ifname), :get_configuration)
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
    configure(null_raw_config(ifname))
  end

  @doc """
  Wait for the interface to be configured
  """
  @spec wait_until_configured(String.t()) :: :ok
  def wait_until_configured(ifname) do
    GenStateMachine.call(via_name(ifname), :wait)
  end

  @doc """
  Run an I/O command on the specified interface
  """
  def ioctl(ifname, command) do
    GenStateMachine.call(via_name(ifname), {:ioctl, command})
  end

  @impl true
  def init(ifname) do
    Process.flag(:trap_exit, true)

    cleanup_interface(ifname)

    initial_data = %State{ifname: ifname, config: null_raw_config(ifname)}
    update_properties(:configured, initial_data)

    actions =
      case load_config(ifname) do
        {:ok, saved_raw_config} ->
          [{:next_event, :internal, {:configure, saved_raw_config}}]

        {:error, reason} ->
          Logger.info("VintageNet: no starting configuration for #{ifname} (#{inspect(reason)})")

          []
      end

    {:ok, :configured, initial_data, actions}
  end

  defp load_config(ifname) do
    with {:ok, config} <- Persistence.call(:load, [ifname]),
         {:ok, raw_config} <- to_raw_config(ifname, config) do
      {:ok, raw_config}
    else
      {:error, reason} ->
        Application.get_env(:vintage_net, :config)
        |> Enum.find(fn {k, _v} -> k == ifname end)
        |> case do
          {_ifname, config} ->
            Logger.info(
              "VintageNet: persisted config for #{ifname} failed so reverting to app config: #{
                inspect(reason)
              }"
            )

            to_raw_config(ifname, config)

          nil ->
            {:error, :no_config}
        end
    end
  end

  # :configuring

  @impl true
  def handle_event(:info, {:commands_done, :ok}, :configuring, %State{} = data) do
    # TODO
    Logger.debug(":configuring -> done success")
    {new_data, actions} = reply_to_waiters(data)
    new_data = %{new_data | command_runner: nil}

    update_properties(:configured, new_data)

    VintageNet.Interface.Supervisor.set_technology(data.ifname, data.config.child_specs)

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
    update_properties(:retrying, new_data)
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
    update_properties(:retrying, new_data)
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
    update_properties(:retrying, new_data)
    {:next_state, :retrying, new_data, actions}
  end

  # :configured

  def handle_event({:call, from}, :wait, :configured, %State{} = data) do
    Logger.debug(":configured -> wait (return immediately)")
    {:keep_state, data, {:reply, from, :ok}}
  end

  @impl true
  def handle_event(
        :internal,
        {:configure, new_config},
        :configured,
        %State{config: old_config} = data
      ) do
    Logger.debug(":configured -> internal configure")

    new_data = run_commands(data, old_config.down_cmds)

    action = [
      {:state_timeout, old_config.down_cmd_millis, :unconfiguring_timeout}
    ]

    update_properties(:reconfiguring, new_data)
    {:next_state, :reconfiguring, %{new_data | next_config: new_config}, action}
  end

  @impl true
  def handle_event(
        {:call, from},
        {:configure, new_config},
        :configured,
        %State{config: old_config} = data
      ) do
    Logger.debug(":configured -> configure")

    new_data = run_commands(data, old_config.down_cmds)

    action = [
      {:reply, from, :ok},
      {:state_timeout, old_config.down_cmd_millis, :unconfiguring_timeout}
    ]

    update_properties(:reconfiguring, new_data)
    {:next_state, :reconfiguring, %{new_data | next_config: new_config}, action}
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
    new_data = %{new_data | config: new_config, next_config: nil}

    action = [
      {:state_timeout, new_config.up_cmd_millis, :configuring_timeout}
    ]

    update_properties(:configuring, new_data)
    {:next_state, :configuring, new_data, action}
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
    new_data = %{new_data | config: new_config, next_config: nil}

    action = [
      {:state_timeout, new_config.up_cmd_millis, :configuring_timeout}
    ]

    update_properties(:configuring, new_data)
    {:next_state, :configuring, new_data, action}
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
    new_data = %{new_data | config: new_config, next_config: nil}

    action = [
      {:state_timeout, new_config.up_cmd_millis, :configuring_timeout}
    ]

    update_properties(:configuring, new_data)
    {:next_state, :configuring, new_data, action}
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
    CommandRunner.remove_files(config.files)
    CommandRunner.create_files(new_config.files)
    new_data = run_commands(data, new_config.up_cmds)
    new_data = %{new_data | config: new_config, next_config: nil}

    action = [
      {:state_timeout, new_config.up_cmd_millis, :configuring_timeout}
    ]

    update_properties(:configuring, new_data)
    {:next_state, :configuring, new_data, action}
  end

  # :retrying

  @impl true
  def handle_event(:state_timeout, _event, :retrying, %State{config: config} = data) do
    CommandRunner.create_files(config.files)
    new_data = run_commands(data, config.up_cmds)
    update_properties(:configuring, new_data)
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

  @impl true
  def handle_event({:call, from}, :get_configuration, _state, data) do
    {:reply, from, data.config.source_config}
  end

  @impl true
  def terminate(_reason, _state, %{ifname: ifname}) do
    PropertyTable.clear(VintageNet, ["interface", ifname, "type"])
    PropertyTable.clear(VintageNet, ["interface", ifname, "state"])
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

  defp null_raw_config(ifname) do
    {:ok, config} = VintageNet.Technology.Null.to_raw_config(ifname)
    config
  end

  defp cleanup_interface(_ifname) do
    # This function is called to restore the filesystem to a pristine
    # state or as close as possible to one. It is called from `init/1`
    # so it can't fail.

    # TODO!!!
  end

  defp update_properties(state, data) do
    ifname = data.ifname
    config = data.config

    PropertyTable.put(VintageNet, ["interface", ifname, "type"], config.type)
    PropertyTable.put(VintageNet, ["interface", ifname, "state"], to_string(state))
  end
end
