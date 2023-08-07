defmodule VintageNet.Interface do
  @moduledoc """
  Manage a network interface at a very high level

  This module handles configuring network interfaces, making sure that configuration failures
  get retried, and then cleaning up after it's not needed.

  The actual code that supplies the configuration implements the `VintageNet.Technology`
  behaviour.
  """
  use GenStateMachine

  alias VintageNet.Interface.CommandRunner
  alias VintageNet.Interface.RawConfig
  alias VintageNet.Persistence
  alias VintageNet.PowerManager.PMControl
  alias VintageNet.PredictableInterfaceName
  alias VintageNet.RouteManager
  alias VintageNet.Technology
  alias VintageNet.Technology.Null

  require Logger

  defstruct ifname: nil,
            config: nil,
            next_config: nil,
            command_runner: nil,
            waiters: [],
            inflight_ioctls: %{}

  @doc """
  Start up an interface

  Parameters:

  * `ifname` - which interface
  """
  @spec start_link(VintageNet.ifname()) :: GenServer.on_start()
  def start_link(ifname) do
    GenStateMachine.start_link(__MODULE__, ifname, name: via_name(ifname))
  end

  defp via_name(ifname) do
    {:via, Registry, {VintageNet.Interface.Registry, ifname}}
  end

  @doc """
  Stop the interface

  Note that this doesn't deconfigure it.
  """
  @spec stop(VintageNet.ifname()) :: :ok
  def stop(ifname) do
    GenStateMachine.stop(via_name(ifname))
  end

  @doc """
  Convert a configuration to a raw one

  This can be used to validate a configuration without applying it.
  """
  @spec to_raw_config(VintageNet.ifname(), map()) :: {:ok, RawConfig.t()} | {:error, any()}
  def to_raw_config(ifname, config) do
    opts = Application.get_all_env(:vintage_net)

    try do
      technology = Technology.module_from_config!(config)
      normalized_config = technology.normalize(config)
      raw_config = technology.to_raw_config(ifname, normalized_config, opts)
      {:ok, raw_config}
    catch
      _kind, maybe_exception ->
        if Kernel.is_exception(maybe_exception) do
          {:error, Exception.message(maybe_exception)}
        else
          {:error,
           """
           Configuration has an unrecoverable error:

           #{inspect(maybe_exception)}

           #{Exception.format_stacktrace(__STACKTRACE__)}
           """}
        end
    end
  end

  @doc """
  Set a configuration on an interface

  Configurations with invalid parameters raise exceptions. It's
  still possible that network configurations won't work even if they
  don't raise, but it should be due to something in the environment.
  For example, a network cable isn't plugged in or a WiFi access point
  is out of range.
  """
  @spec configure(VintageNet.ifname(), map(), VintageNet.configure_options()) ::
          :ok | {:error, any()}
  def configure(ifname, config, options \\ []) do
    # The logic here is to validate the config by converting it to a
    # raw_config. We'd need to do that anyway, so just get it over with.  The
    # next step is to persist the config. This is important since if the
    # Interface GenServer ever crashes and restarts, we want it to use this new
    # config. `maybe_start_interface` might start up an Interface GenServer. If
    # it does, then it will reach into the PropertyTable for the config and it would
    # be bad for it to get an old config. If a GenServer isn't started,
    # configure the running one.
    with {:ok, raw_config} <- to_raw_config(ifname, config),
         :ok <- PredictableInterfaceName.precheck(ifname),
         normalized_config = raw_config.source_config,
         :changed <- configuration_changed(ifname, normalized_config),
         persist_configuration(ifname, normalized_config, options),
         PropertyTable.put(VintageNet, ["interface", ifname, "config"], normalized_config),
         {:error, :already_started} <- maybe_start_interface(ifname) do
      GenStateMachine.call(via_name(raw_config.ifname), {:configure, raw_config})
    end
  end

  defp configuration_changed(ifname, normalized_config) do
    case PropertyTable.get(VintageNet, ["interface", ifname, "config"]) do
      ^normalized_config -> :ok
      _ -> :changed
    end
  end

  defp persist_configuration(ifname, normalized_config, options) do
    if Keyword.get(options, :persist, true) do
      with {:error, reason} <- Persistence.call(:save, [ifname, normalized_config]) do
        log(:warn, ifname, "Error saving configuration: #{inspect(reason)}")
      end
    end

    :ok
  end

  defp maybe_start_interface(ifname) do
    case VintageNet.InterfacesSupervisor.start_interface(ifname) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> {:error, :already_started}
      {:error, other} -> {:error, other}
    end
  end

  @doc """
  Deconfigure the interface

  This doesn't exit this GenServer, but the interface
  won't be usable in any real way until it's configured
  again.

  This function is not normally called.
  """
  @spec deconfigure(VintageNet.ifname(), VintageNet.configure_options()) :: :ok | {:error, any()}
  def deconfigure(ifname, options \\ []) do
    configure(ifname, %{type: Null, reason: "Interface deconfigured"}, options)
  end

  @doc """
  Wait for the interface to be configured
  """
  @spec wait_until_configured(VintageNet.ifname()) :: :ok
  def wait_until_configured(ifname) do
    GenStateMachine.call(via_name(ifname), :wait)
  end

  @doc """
  Run an I/O command on the specified interface
  """
  @spec ioctl(VintageNet.ifname(), atom(), any()) :: :ok | {:ok, any()} | {:error, any()}
  def ioctl(ifname, command, args) do
    GenStateMachine.call(via_name(ifname), {:ioctl, command, args})
  end

  defp debug(data, message), do: log(:debug, data.ifname, message)

  defp log(level, ifname, message) do
    Logger.log(level, ["VintageNet(", ifname, "): ", message])
  end

  @impl GenStateMachine
  def init(ifname) do
    Process.flag(:trap_exit, true)

    cleanup_interface(ifname)

    initial_data = %__MODULE__{ifname: ifname, config: null_raw_config(ifname)}
    update_properties(:configured, initial_data)

    raw_config = get_raw_config(ifname)
    actions = [{:next_event, :internal, {:configure, raw_config}}]

    {:ok, :configured, initial_data, actions}
  end

  defp get_raw_config(ifname) do
    # Get and convert the configuration to raw form for use.
    case PropertyTable.get(VintageNet, ["interface", ifname, "config"]) do
      nil ->
        # No configuration, so use a null config and fix the property table
        raw_config = null_raw_config(ifname)
        PropertyTable.put(VintageNet, ["interface", ifname, "config"], raw_config.source_config)
        raw_config

      config ->
        # This is "guaranteed" to work since configurations are validated before
        # saving them in the property table.
        {:ok, raw_config} = to_raw_config(ifname, config)
        raw_config
    end
  end

  # :configuring

  @impl GenStateMachine
  def handle_event(:info, {:commands_done, :ok}, :configuring, %__MODULE__{} = data) do
    # debug(data, ":configuring -> done success")
    {new_data, actions} = reply_to_waiters(data)
    new_data = %{new_data | command_runner: nil}

    update_properties(:configured, new_data)

    VintageNet.Interface.Supervisor.set_technology(
      data.ifname,
      data.config.restart_strategy,
      data.config.child_specs
    )

    {:next_state, :configured, new_data, actions}
  end

  @impl GenStateMachine
  def handle_event(
        :info,
        {:commands_done, {:error, _reason}},
        :configuring,
        %__MODULE__{config: config} = data
      ) do
    debug(data, ":configuring -> done error: retrying after #{config.retry_millis} ms")
    {new_data, actions} = reply_to_waiters(data)
    new_data = %{new_data | command_runner: nil}
    actions = [{:state_timeout, config.retry_millis, :retry_timeout} | actions]
    update_properties(:retrying, new_data)
    {:next_state, :retrying, new_data, actions}
  end

  @impl GenStateMachine
  def handle_event(
        :info,
        {:EXIT, pid, reason},
        :configuring,
        %__MODULE__{command_runner: pid, config: config} = data
      ) do
    debug(
      data,
      ":configuring -> done crash (#{inspect(reason)}): retrying after #{config.retry_millis} ms"
    )

    {new_data, actions} = reply_to_waiters(data)
    new_data = %{new_data | command_runner: nil}
    actions = [{:state_timeout, config.retry_millis, :retry_timeout} | actions]
    update_properties(:retrying, new_data)
    {:next_state, :retrying, new_data, actions}
  end

  @impl GenStateMachine
  def handle_event(
        :state_timeout,
        _event,
        :configuring,
        %__MODULE__{command_runner: pid, config: config} = data
      ) do
    debug(data, ":configuring -> recovering from hang: retrying after #{config.retry_millis} ms")

    Process.exit(pid, :kill)
    {new_data, actions} = reply_to_waiters(data)
    new_data = %{new_data | command_runner: nil}
    actions = [{:state_timeout, config.retry_millis, :retry_timeout} | actions]
    update_properties(:retrying, new_data)
    {:next_state, :retrying, new_data, actions}
  end

  @impl GenStateMachine
  def handle_event(
        {:call, from},
        {:configure, new_config},
        :configuring,
        %__MODULE__{command_runner: pid, config: old_config} = data
      ) do
    debug(data, ":configuring -> configuring (stopping the old configuration)")
    Process.exit(pid, :kill)
    rm(old_config.cleanup_files)
    CommandRunner.remove_files(old_config.files)

    {new_data, actions} = reply_to_waiters(data)
    new_data = %{new_data | config: new_config, command_runner: nil}

    actions = [{:reply, from, :ok} | actions]

    start_configuring(new_config, new_data, actions)
  end

  @impl GenStateMachine
  def handle_event(
        :info,
        {VintageNet, ["interface", an_ifname, "present"], _old_value, nil, _meta},
        :configuring,
        %__MODULE__{command_runner: pid, config: config} = data
      ) do
    debug(data, ":configuring -> #{an_ifname} removed: retrying after #{config.retry_millis}ms")

    Process.exit(pid, :kill)
    {new_data, actions} = reply_to_waiters(data)
    new_data = %{new_data | command_runner: nil}
    actions = [{:state_timeout, config.retry_millis, :retry_timeout} | actions]
    update_properties(:retrying, new_data)
    {:next_state, :retrying, new_data, actions}
  end

  # :configured

  def handle_event({:call, from}, :wait, :configured, %__MODULE__{} = data) do
    # debug(data, ":configured -> wait (return immediately)")
    {:keep_state, data, {:reply, from, :ok}}
  end

  @impl GenStateMachine
  def handle_event(
        :internal,
        {:configure, new_config},
        :configured,
        %__MODULE__{config: old_config} = data
      ) do
    debug(data, ":configured -> internal configure (#{inspect(new_config.type)})")

    {new_data, actions} = cancel_ioctls(data)
    VintageNet.Interface.Supervisor.clear_technology(data.ifname)
    new_data = run_commands(new_data, old_config.down_cmds)

    actions = [
      {:state_timeout, old_config.down_cmd_millis, :unconfiguring_timeout} | actions
    ]

    update_properties(:reconfiguring, new_data)
    {:next_state, :reconfiguring, %{new_data | next_config: new_config}, actions}
  end

  @impl GenStateMachine
  def handle_event(
        {:call, from},
        {:configure, new_config},
        :configured,
        %__MODULE__{config: old_config} = data
      ) do
    debug(data, ":configured -> configure (#{inspect(new_config.type)})")

    {new_data, actions} = cancel_ioctls(data)
    VintageNet.Interface.Supervisor.clear_technology(data.ifname)
    new_data = run_commands(new_data, old_config.down_cmds)

    actions = [
      {:reply, from, :ok},
      {:state_timeout, old_config.down_cmd_millis, :unconfiguring_timeout} | actions
    ]

    update_properties(:reconfiguring, new_data)
    {:next_state, :reconfiguring, %{new_data | next_config: new_config}, actions}
  end

  @impl GenStateMachine
  def handle_event(
        {:call, from},
        {:ioctl, command, args},
        :configured,
        %__MODULE__{} = data
      ) do
    # debug(data, ":configured -> run ioctl")

    # Delegate the ioctl to the technology
    mfargs = {data.config.type, :ioctl, [data.ifname, command, args]}
    new_data = run_ioctl(data, from, mfargs)

    {:keep_state, new_data}
  end

  @impl GenStateMachine
  def handle_event(
        :info,
        {:ioctl_done, ioctl_pid, result},
        :configured,
        %__MODULE__{inflight_ioctls: inflight} = data
      ) do
    # debug(data, ":configured -> ioctl done")

    {{from, _mfargs}, new_inflight} = Map.pop(inflight, ioctl_pid)
    action = {:reply, from, result}
    new_data = %{data | inflight_ioctls: new_inflight}

    {:keep_state, new_data, action}
  end

  @impl GenStateMachine
  def handle_event(
        :info,
        {:EXIT, pid, reason},
        :configured,
        %__MODULE__{inflight_ioctls: inflight} = data
      ) do
    # If an ioctl crashed, then return an error.
    # Otherwise, it's a latent exit from something that exited normally.
    case Map.pop(inflight, pid) do
      {{from, mfargs}, new_inflight} ->
        debug(data, ":configured -> ioctl(#{inspect(mfargs)}) exited (#{inspect(reason)})")

        action = {:reply, from, {:error, {:exit, reason}}}
        new_data = %{data | inflight_ioctls: new_inflight}
        {:keep_state, new_data, action}

      {nil, _} ->
        # debug(data, ":configured -> ignoring process exit")
        {:keep_state, data}
    end
  end

  @impl GenStateMachine
  def handle_event(
        :info,
        {VintageNet, ["interface", an_ifname, "present"], _old_value, nil, _meta},
        :configured,
        %__MODULE__{config: config} = data
      ) do
    debug(data, ":configured -> #{an_ifname} removed")

    {new_data, actions} = cancel_ioctls(data)
    VintageNet.Interface.Supervisor.clear_technology(data.ifname)
    new_data = run_commands(new_data, config.down_cmds)

    actions = [
      {:state_timeout, config.down_cmd_millis, :unconfiguring_timeout} | actions
    ]

    update_properties(:reconfiguring, new_data)
    {:next_state, :reconfiguring, %{new_data | next_config: config}, actions}
  end

  # :reconfiguring

  @impl GenStateMachine
  def handle_event(
        :info,
        {:commands_done, :ok},
        :reconfiguring,
        %__MODULE__{config: old_config, next_config: new_config} = data
      ) do
    # TODO
    # debug(data, "#{data.ifname}:reconfiguring -> cleanup success")
    rm(old_config.cleanup_files)
    CommandRunner.remove_files(old_config.files)
    update_ifname_subscriptions(old_config.required_ifnames, new_config.required_ifnames)

    power_interface(data.ifname, new_config.type)

    data = %{data | config: new_config, next_config: nil}

    if interfaces_available?(data) do
      start_configuring(new_config, data, [])
    else
      {new_data, actions} = reply_to_waiters(data)
      new_data = %{new_data | command_runner: nil}
      actions = [{:state_timeout, new_config.retry_millis, :retry_timeout} | actions]
      update_properties(:retrying, new_data)
      {:next_state, :retrying, new_data, actions}
    end
  end

  @impl GenStateMachine
  def handle_event(
        :info,
        {:commands_done, {:error, _reason}},
        :reconfiguring,
        %__MODULE__{config: old_config, next_config: new_config} = data
      ) do
    # TODO
    debug(data, ":reconfiguring -> done error")
    rm(old_config.cleanup_files)
    CommandRunner.remove_files(old_config.files)
    update_ifname_subscriptions(old_config.required_ifnames, new_config.required_ifnames)
    power_interface(data.ifname, new_config.type)

    data = %{data | config: new_config, next_config: nil}

    if interfaces_available?(data) do
      start_configuring(new_config, data, [])
    else
      {new_data, actions} = reply_to_waiters(data)
      new_data = %{new_data | command_runner: nil}
      actions = [{:state_timeout, new_config.retry_millis, :retry_timeout} | actions]
      update_properties(:retrying, new_data)
      {:next_state, :retrying, new_data, actions}
    end
  end

  @impl GenStateMachine
  def handle_event(
        :info,
        {:EXIT, pid, reason},
        :reconfiguring,
        %__MODULE__{config: old_config, command_runner: pid, next_config: new_config} = data
      ) do
    # TODO
    debug(data, ":reconfiguring -> done crash (#{inspect(reason)})")
    rm(old_config.cleanup_files)
    CommandRunner.remove_files(old_config.files)
    update_ifname_subscriptions(old_config.required_ifnames, new_config.required_ifnames)
    power_interface(data.ifname, new_config.type)

    data = %{data | config: new_config, next_config: nil}

    if interfaces_available?(data) do
      start_configuring(new_config, data, [])
    else
      {new_data, actions} = reply_to_waiters(data)
      new_data = %{new_data | command_runner: nil}
      actions = [{:state_timeout, new_config.retry_millis, :retry_timeout} | actions]
      update_properties(:retrying, new_data)
      {:next_state, :retrying, new_data, actions}
    end
  end

  @impl GenStateMachine
  def handle_event(
        :state_timeout,
        _event,
        :reconfiguring,
        %__MODULE__{command_runner: pid, config: old_config, next_config: new_config} = data
      ) do
    debug(data, ":reconfiguring -> recovering from hang")
    Process.exit(pid, :kill)
    rm(old_config.cleanup_files)
    CommandRunner.remove_files(old_config.files)
    update_ifname_subscriptions(old_config.required_ifnames, new_config.required_ifnames)
    power_interface(data.ifname, new_config.type)

    data = %{data | config: new_config, next_config: nil}

    if interfaces_available?(data) do
      start_configuring(new_config, data, [])
    else
      {new_data, actions} = reply_to_waiters(data)
      new_data = %{new_data | command_runner: nil}
      actions = [{:state_timeout, new_config.retry_millis, :retry_timeout} | actions]
      update_properties(:retrying, new_data)
      {:next_state, :retrying, new_data, actions}
    end
  end

  # :retrying

  @impl GenStateMachine
  def handle_event(:state_timeout, _event, :retrying, %__MODULE__{config: new_config} = data) do
    if interfaces_available?(data) do
      start_configuring(new_config, data, [])
    else
      {:keep_state, data, {:state_timeout, new_config.retry_millis, :retry_timeout}}
    end
  end

  @impl GenStateMachine
  def handle_event(
        :info,
        {VintageNet, ["interface", an_ifname, "present"], _old_value, true, _meta},
        :retrying,
        %__MODULE__{config: new_config} = data
      ) do
    debug(data, ":retrying -> #{an_ifname} up")
    # One of the dependent interfaces appeared, so check
    if interfaces_available?(data) do
      start_configuring(new_config, data, [])
    else
      {:keep_state, data}
    end
  end

  @impl GenStateMachine
  def handle_event(
        {:call, from},
        {:configure, new_config},
        :retrying,
        data
      ) do
    debug(data, ":retrying -> configure (#{inspect(new_config.type)})")
    power_interface(data.ifname, new_config.type)

    data = %{data | config: new_config}
    actions = [{:reply, from, :ok}]

    if interfaces_available?(data) do
      start_configuring(new_config, data, actions)
    else
      {:keep_state, data, [{:state_timeout, new_config.retry_millis, :retry_timeout} | actions]}
    end
  end

  @impl GenStateMachine
  def handle_event(:info, {:commands_done, _}, :retrying, %__MODULE__{} = data) do
    # This is a latent message that didn't get processed because a crash
    # got handled first. It can be produced by getting one of an
    # interface's supervised processes to crash on a
    # VintageNet.deconfigure/1 call.
    {:keep_state, data}
  end

  # Catch all event handlers
  @impl GenStateMachine
  def handle_event(:info, {:EXIT, _pid, _reason}, _state, data) do
    # Ignore latent or expected command runner and ioctl exits
    # debug(data, "#{inspect(state)} -> process exit (ignoring)")
    {:keep_state, data}
  end

  @impl GenStateMachine
  def handle_event(
        {:call, from},
        :wait,
        _other_state,
        %__MODULE__{waiters: waiters} = data
      ) do
    # debug(data, "#{inspect(other_state)} -> wait")
    {:keep_state, %{data | waiters: [from | waiters]}}
  end

  @impl GenStateMachine
  def handle_event(
        {:call, from},
        {:ioctl, _command, _args},
        other_state,
        data
      ) do
    debug(data, "#{inspect(other_state)} -> call ioctl (returning error)")
    {:keep_state, data, {:reply, from, {:error, :unconfigured}}}
  end

  @impl GenStateMachine
  def handle_event(
        :info,
        {VintageNet, ["interface", ifname, "present"], _old_value, present, _meta},
        other_state,
        %__MODULE__{ifname: ifname} = data
      ) do
    debug(data, "#{inspect(other_state)} -> interface #{ifname} is now #{inspect(present)}")
    {:keep_state, data}
  end

  @impl GenStateMachine
  def terminate(_reason, _state, %{ifname: ifname}) do
    PropertyTable.delete(VintageNet, ["interface", ifname, "type"])
    PropertyTable.delete(VintageNet, ["interface", ifname, "state"])
  end

  defp start_configuring(new_config, data, actions) do
    rm(new_config.cleanup_files)
    cleanup_interface(data.ifname)
    CommandRunner.create_files(new_config.files)
    new_data = run_commands(data, new_config.up_cmds)

    actions = [
      {:state_timeout, new_config.up_cmd_millis, :configuring_timeout} | actions
    ]

    update_properties(:configuring, new_data)
    {:next_state, :configuring, new_data, actions}
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
    result = CommandRunner.run(commands)
    send(interface_pid, {:commands_done, result})
  end

  defp null_raw_config(ifname) do
    Null.to_raw_config(ifname)
  end

  defp cleanup_interface(ifname) do
    # This function is called to restore everything to a pristine
    # state or as close as possible to one. It is called from `init/1`
    # so it can't fail.

    RouteManager.clear_route(ifname)
  end

  defp rm(files) do
    Enum.each(files, &File.rm(&1))
  end

  defp update_properties(state, data) do
    ifname = data.ifname
    config = data.config

    PropertyTable.put_many(VintageNet, [
      {["interface", ifname, "type"], config.type},
      {["interface", ifname, "state"], state}
    ])

    if state != :configured do
      # Once a state is `:configured`, then the configuration provides the connection
      # status. When not configured, make sure there are no routing tables entries or
      # stale properties.
      RouteManager.set_connection_status(ifname, :disconnected)
    end
  end

  defp run_ioctl(data, from, mfargs) do
    interface_pid = self()

    {:ok, pid} = Task.start_link(fn -> run_ioctl_and_report(mfargs, interface_pid) end)

    new_inflight = Map.put(data.inflight_ioctls, pid, {from, mfargs})

    %{data | inflight_ioctls: new_inflight}
  end

  defp run_ioctl_and_report({module, function_name, args}, interface_pid) do
    result = apply(module, function_name, args)
    send(interface_pid, {:ioctl_done, self(), result})
  end

  defp cancel_ioctls(data) do
    actions =
      Enum.map(data.inflight_ioctls, fn {pid, {from, _mfargs}} ->
        Process.exit(pid, :kill)
        {:reply, from, {:error, :cancelled}}
      end)

    {%{data | inflight_ioctls: %{}}, actions}
  end

  defp update_ifname_subscriptions(old_required_ifnames, required_ifnames) do
    new_subscriptions = required_ifnames -- old_required_ifnames
    removed_subscriptions = old_required_ifnames -- required_ifnames

    Enum.each(new_subscriptions, fn ifname ->
      VintageNet.subscribe(["interface", ifname, "present"])
    end)

    Enum.each(removed_subscriptions, fn ifname ->
      VintageNet.unsubscribe(["interface", ifname, "present"])
    end)
  end

  defp interfaces_available?(data) do
    Enum.all?(data.config.required_ifnames, &interface_available?/1)
  end

  defp interface_available?(ifname) when is_binary(ifname) do
    VintageNet.get(["interface", ifname, "present"])
  end

  # Power on non-Null interfaces
  defp power_interface(ifname, Null) do
    PMControl.power_off(ifname)
  end

  defp power_interface(ifname, _type) do
    PMControl.power_on(ifname)
  end
end
