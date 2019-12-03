defmodule VintageNet.Interface do
  use GenStateMachine

  @moduledoc """
  Manage a network interface at a very high level

  This module handles configuring network interfaces, making sure that configuration failures
  get retried, and then cleaning up after it's not needed.

  The actual code that supplies the configuration implements the `VintageNet.Technology`
  behaviour.
  """
  require Logger

  alias VintageNet.Interface.{CommandRunner, RawConfig}
  alias VintageNet.{Persistence, PropertyTable, RouteManager}

  defmodule State do
    @moduledoc false

    defstruct ifname: nil,
              config: nil,
              next_config: nil,
              command_runner: nil,
              waiters: [],
              inflight_ioctls: %{}
  end

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

  Note that this doesn't unconfigure it.
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
      technology = technology_from_config(config)
      raw_config = technology.to_raw_config(ifname, config, opts)
      {:ok, raw_config}
    rescue
      error in ArgumentError -> {:error, error.message}
      error in FunctionClauseError -> {:error, error.message}
    catch
      _kind, what ->
        {:error, "Configuration has unrecoverable error that caused: #{inspect(what)}"}
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
  @spec configure(VintageNet.ifname(), map()) :: :ok
  def configure(ifname, config) do
    opts = Application.get_all_env(:vintage_net)
    technology = technology_from_config(config)
    raw_config = technology.to_raw_config(ifname, config, opts)
    configure(raw_config)
  end

  @doc """
  Configure an interface the low level way with a "raw_config"
  """
  @spec configure(RawConfig.t()) :: :ok
  def configure(raw_config) do
    GenStateMachine.call(via_name(raw_config.ifname), {:configure, raw_config})
  end

  defp technology_from_config(%{type: type}) do
    unless Code.ensure_compiled?(type) do
      raise(ArgumentError, """
      Invalid technology #{inspect(type)}.

      Check the spelling and that you have the dependency that provides it in your mix.exs.
      See the `vintage_net` docs for examples.
      """)
    end

    type
  end

  defp technology_from_config(_missing),
    do:
      raise(ArgumentError, """
      Missing :type field.

      This should be set to a network technology. These are provided in other libraries.
      See the `vintage_net` docs and cookbook for examples.
      """)

  @doc """
  Return the current configuration
  """
  @spec get_configuration(VintageNet.ifname()) :: map()
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
  @spec unconfigure(VintageNet.ifname()) :: :ok
  def unconfigure(ifname) do
    configure(null_raw_config(ifname))
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

  @impl true
  def init(ifname) do
    Process.flag(:trap_exit, true)

    cleanup_interface(ifname)

    initial_data = %State{ifname: ifname, config: null_raw_config(ifname)}
    update_properties(:configured, initial_data)

    VintageNet.subscribe(["interface", ifname, "present"])

    actions =
      case load_config(ifname) do
        {:ok, saved_raw_config} ->
          [{:next_event, :internal, {:configure, saved_raw_config}}]

        {:error, reason} ->
          _ = Logger.info("VintageNet: no starting config for #{ifname} (#{inspect(reason)})")
          []
      end

    {:ok, :configured, initial_data, actions}
  end

  defp load_config(ifname) do
    with {:ok, config} <- Persistence.call(:load, [ifname]),
         {:ok, raw_config} <- to_raw_config(ifname, config) do
      {:ok, raw_config}
    else
      {:error, :corrupt} ->
        _ = Logger.warn("VintageNet(#{ifname}): ignoring corrupt config and using default")
        load_default_config(ifname)

      {:error, reason} ->
        _ = Logger.info("VintageNet(#{ifname}): loading config failed: #{inspect(reason)}")
        load_default_config(ifname)
    end
  end

  defp load_default_config(ifname) do
    Application.get_env(:vintage_net, :config)
    |> Enum.find(fn {k, _v} -> k == ifname end)
    |> case do
      {_ifname, config} ->
        to_raw_config(ifname, config)

      nil ->
        {:error, :no_config}
    end
  end

  # :configuring

  @impl true
  def handle_event(:info, {:commands_done, :ok}, :configuring, %State{} = data) do
    # _ = Logger.debug(":configuring -> done success")
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

  @impl true
  def handle_event(
        :info,
        {:commands_done, {:error, _reason}},
        :configuring,
        %State{config: config} = data
      ) do
    _ = Logger.debug(":configuring -> done error: retrying after #{config.retry_millis} ms")
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
    _ =
      Logger.debug(
        ":configuring -> done crash (#{inspect(reason)}): retrying after #{config.retry_millis} ms"
      )

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
    _ =
      Logger.debug(
        ":configuring -> recovering from hang: retrying after #{config.retry_millis} ms"
      )

    Process.exit(pid, :kill)
    {new_data, actions} = reply_to_waiters(data)
    new_data = %{new_data | command_runner: nil}
    actions = [{:state_timeout, config.retry_millis, :retry_timeout} | actions]
    update_properties(:retrying, new_data)
    {:next_state, :retrying, new_data, actions}
  end

  @impl true
  def handle_event(
        {:call, from},
        {:configure, new_config},
        :configuring,
        %State{command_runner: pid, config: old_config} = data
      ) do
    _ = Logger.debug(":configuring -> configuring (stopping the old configuration)")
    Process.exit(pid, :kill)
    rm(old_config.cleanup_files)
    CommandRunner.remove_files(old_config.files)

    {new_data, actions} = reply_to_waiters(data)
    new_data = %{new_data | config: new_config, command_runner: nil}

    actions = [{:reply, from, :ok} | actions]

    start_configuring(new_config, new_data, actions)
  end

  @impl true
  def handle_event(
        :info,
        {VintageNet, ["interface", ifname, "present"], _old_value, nil, _meta},
        :configuring,
        %State{ifname: ifname, command_runner: pid, config: config} = data
      ) do
    _ =
      Logger.debug(
        ":configuring -> interface disappeared: retrying after #{config.retry_millis} ms"
      )

    Process.exit(pid, :kill)
    {new_data, actions} = reply_to_waiters(data)
    new_data = %{new_data | command_runner: nil}
    actions = [{:state_timeout, config.retry_millis, :retry_timeout} | actions]
    update_properties(:retrying, new_data)
    {:next_state, :retrying, new_data, actions}
  end

  # :configured

  def handle_event({:call, from}, :wait, :configured, %State{} = data) do
    # _ = Logger.debug(":configured -> wait (return immediately)")
    {:keep_state, data, {:reply, from, :ok}}
  end

  @impl true
  def handle_event(
        :internal,
        {:configure, new_config},
        :configured,
        %State{config: old_config} = data
      ) do
    # _ = Logger.debug(":configured -> internal configure")

    {new_data, actions} = cancel_ioctls(data)

    new_data = run_commands(new_data, old_config.down_cmds)

    actions = [
      {:state_timeout, old_config.down_cmd_millis, :unconfiguring_timeout} | actions
    ]

    update_properties(:reconfiguring, new_data)
    {:next_state, :reconfiguring, %{new_data | next_config: new_config}, actions}
  end

  @impl true
  def handle_event(
        {:call, from},
        {:configure, new_config},
        :configured,
        %State{config: old_config} = data
      ) do
    # _ = Logger.debug(":configured -> configure")

    {new_data, actions} = cancel_ioctls(data)
    new_data = run_commands(new_data, old_config.down_cmds)

    actions = [
      {:reply, from, :ok},
      {:state_timeout, old_config.down_cmd_millis, :unconfiguring_timeout} | actions
    ]

    update_properties(:reconfiguring, new_data)
    {:next_state, :reconfiguring, %{new_data | next_config: new_config}, actions}
  end

  @impl true
  def handle_event(
        {:call, from},
        {:ioctl, command, args},
        :configured,
        %State{} = data
      ) do
    # _ = Logger.debug(":configured -> run ioctl")

    # Delegate the ioctl to the technology
    mfa = {data.config.type, :ioctl, [data.ifname, command, args]}
    new_data = run_ioctl(data, from, mfa)

    {:keep_state, new_data}
  end

  @impl true
  def handle_event(
        :info,
        {:ioctl_done, ioctl_pid, result},
        :configured,
        %State{inflight_ioctls: inflight} = data
      ) do
    # _ = Logger.debug(":configured -> ioctl done")

    {{from, _mfa}, new_inflight} = Map.pop(inflight, ioctl_pid)
    action = {:reply, from, result}
    new_data = %{data | inflight_ioctls: new_inflight}

    {:keep_state, new_data, action}
  end

  @impl true
  def handle_event(
        :info,
        {:EXIT, pid, reason},
        :configured,
        %State{inflight_ioctls: inflight} = data
      ) do
    # If an ioctl crashed, then return an error.
    # Otherwise, it's a latent exit from something that exited normally.
    case Map.pop(inflight, pid) do
      {{from, mfa}, new_inflight} ->
        _ =
          Logger.debug(
            ":configured -> unexpected ioctl(#{inspect(mfa)}) exit (#{inspect(reason)})"
          )

        action = {:reply, from, {:error, {:exit, reason}}}
        new_data = %{data | inflight_ioctls: new_inflight}
        {:keep_state, new_data, action}

      {nil, _} ->
        # _ = Logger.debug(":configured -> ignoring process exit")
        {:keep_state, data}
    end
  end

  @impl true
  def handle_event(
        :info,
        {VintageNet, ["interface", ifname, "present"], _old_value, nil, _meta},
        :configured,
        %State{ifname: ifname, config: config} = data
      ) do
    _ = Logger.debug(":configured -> interface disappeared")

    {new_data, actions} = cancel_ioctls(data)

    new_data = run_commands(new_data, config.down_cmds)

    actions = [
      {:state_timeout, config.down_cmd_millis, :unconfiguring_timeout} | actions
    ]

    update_properties(:reconfiguring, new_data)
    {:next_state, :reconfiguring, %{new_data | next_config: config}, actions}
  end

  # :reconfiguring

  @impl true
  def handle_event(
        :info,
        {:commands_done, :ok},
        :reconfiguring,
        %State{config: old_config, next_config: new_config} = data
      ) do
    # TODO
    # _ = Logger.debug("#{data.ifname}:reconfiguring -> cleanup success")
    rm(old_config.cleanup_files)
    CommandRunner.remove_files(old_config.files)

    data = %{data | config: new_config, next_config: nil}

    if interface_available?(data) do
      start_configuring(new_config, data, [])
    else
      {new_data, actions} = reply_to_waiters(data)
      new_data = %{new_data | command_runner: nil}
      actions = [{:state_timeout, new_config.retry_millis, :retry_timeout} | actions]
      update_properties(:retrying, new_data)
      {:next_state, :retrying, new_data, actions}
    end
  end

  @impl true
  def handle_event(
        :info,
        {:commands_done, {:error, _reason}},
        :reconfiguring,
        %State{config: old_config, next_config: new_config} = data
      ) do
    # TODO
    _ = Logger.debug(":reconfiguring -> done error")
    rm(old_config.cleanup_files)
    CommandRunner.remove_files(old_config.files)

    data = %{data | config: new_config, next_config: nil}

    if interface_available?(data) do
      start_configuring(new_config, data, [])
    else
      {new_data, actions} = reply_to_waiters(data)
      new_data = %{new_data | command_runner: nil}
      actions = [{:state_timeout, new_config.retry_millis, :retry_timeout} | actions]
      update_properties(:retrying, new_data)
      {:next_state, :retrying, new_data, actions}
    end
  end

  @impl true
  def handle_event(
        :info,
        {:EXIT, pid, reason},
        :reconfiguring,
        %State{config: old_config, command_runner: pid, next_config: new_config} = data
      ) do
    # TODO
    _ = Logger.debug(":reconfiguring -> done crash (#{inspect(reason)})")
    rm(old_config.cleanup_files)
    CommandRunner.remove_files(old_config.files)
    data = %{data | config: new_config, next_config: nil}

    if interface_available?(data) do
      start_configuring(new_config, data, [])
    else
      {new_data, actions} = reply_to_waiters(data)
      new_data = %{new_data | command_runner: nil}
      actions = [{:state_timeout, new_config.retry_millis, :retry_timeout} | actions]
      update_properties(:retrying, new_data)
      {:next_state, :retrying, new_data, actions}
    end
  end

  @impl true
  def handle_event(
        :state_timeout,
        _event,
        :reconfiguring,
        %State{command_runner: pid, config: old_config, next_config: new_config} = data
      ) do
    _ = Logger.debug(":reconfiguring -> recovering from hang")
    Process.exit(pid, :kill)
    rm(old_config.cleanup_files)
    CommandRunner.remove_files(old_config.files)

    data = %{data | config: new_config, next_config: nil}

    if interface_available?(data) do
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

  @impl true
  def handle_event(:state_timeout, _event, :retrying, %State{config: new_config} = data) do
    if interface_available?(data) do
      start_configuring(new_config, data, [])
    else
      {:keep_state, data, {:state_timeout, new_config.retry_millis, :retry_timeout}}
    end
  end

  @impl true
  def handle_event(
        :info,
        {VintageNet, ["interface", ifname, "present"], _old_value, true, _meta},
        :retrying,
        %State{ifname: ifname, config: new_config} = data
      ) do
    rm(new_config.cleanup_files)
    cleanup_interface(data.ifname)
    CommandRunner.create_files(new_config.files)
    new_data = run_commands(data, new_config.up_cmds)

    actions = [
      {:state_timeout, new_config.up_cmd_millis, :configuring_timeout}
    ]

    update_properties(:configuring, new_data)
    {:next_state, :configuring, new_data, actions}
  end

  @impl true
  def handle_event(
        {:call, from},
        {:configure, new_config},
        :retrying,
        data
      ) do
    # _ = Logger.debug(":retrying -> configure")

    data = %{data | config: new_config}
    actions = [{:reply, from, :ok}]

    if interface_available?(data) do
      start_configuring(new_config, data, actions)
    else
      {:keep_state, data, [{:state_timeout, new_config.retry_millis, :retry_timeout} | actions]}
    end
  end

  # Catch all event handlers
  @impl true
  def handle_event(:info, {:EXIT, _pid, _reason}, _state, data) do
    # Ignore latent or expected command runner and ioctl exits
    # _ = Logger.debug("#{inspect(state)} -> process exit (ignoring)")
    {:keep_state, data}
  end

  @impl true
  def handle_event(
        {:call, from},
        :wait,
        _other_state,
        %State{waiters: waiters} = data
      ) do
    # _ = Logger.debug("#{inspect(other_state)} -> wait")
    {:keep_state, %{data | waiters: [from | waiters]}}
  end

  @impl true
  def handle_event(
        {:call, from},
        {:ioctl, _command, _args},
        other_state,
        data
      ) do
    _ = Logger.debug("#{inspect(other_state)} -> call ioctl (returning error)")
    {:keep_state, data, {:reply, from, {:error, :unconfigured}}}
  end

  @impl true
  def handle_event({:call, from}, :get_configuration, _state, data) do
    {:keep_state, data, {:reply, from, data.config.source_config}}
  end

  @impl true
  def handle_event(
        :info,
        {VintageNet, ["interface", ifname, "present"], _old_value, present, _meta},
        other_state,
        %State{ifname: ifname} = data
      ) do
    _ = Logger.debug("#{inspect(other_state)} -> interface #{ifname} is now #{inspect(present)}")
    {:keep_state, data}
  end

  @impl true
  def terminate(_reason, _state, %{ifname: ifname}) do
    PropertyTable.clear(VintageNet, ["interface", ifname, "type"])
    PropertyTable.clear(VintageNet, ["interface", ifname, "state"])
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
    VintageNet.Technology.Null.to_raw_config(ifname)
  end

  defp cleanup_interface(ifname) do
    # This function is called to restore everything to a pristine
    # state or as close as possible to one. It is called from `init/1`
    # so it can't fail.

    RouteManager.clear_route(ifname)

    # More?
  end

  defp rm(files) do
    Enum.each(files, &File.rm(&1))
  end

  defp update_properties(state, data) do
    ifname = data.ifname
    config = data.config

    PropertyTable.put(VintageNet, ["interface", ifname, "type"], config.type)
    PropertyTable.put(VintageNet, ["interface", ifname, "state"], state)

    if state != :configured do
      # Once a state is `:configured`, then the configuration provides the connection
      # status. When not configured, report it as `:disconnected` to avoid any confusion
      # with stale or unset values.
      PropertyTable.put(VintageNet, ["interface", ifname, "connection"], :disconnected)
    end
  end

  defp run_ioctl(data, from, mfa) do
    interface_pid = self()

    {:ok, pid} = Task.start_link(fn -> run_ioctl_and_report(mfa, interface_pid) end)

    new_inflight = Map.put(data.inflight_ioctls, pid, {from, mfa})

    %{data | inflight_ioctls: new_inflight}
  end

  defp run_ioctl_and_report({module, function_name, args}, interface_pid) do
    result = apply(module, function_name, args)
    send(interface_pid, {:ioctl_done, self(), result})
  end

  defp cancel_ioctls(data) do
    actions =
      Enum.map(data.inflight_ioctls, fn {pid, {from, _mfa}} ->
        Process.exit(pid, :kill)
        {:reply, from, {:error, :cancelled}}
      end)

    {%{data | inflight_ioctls: %{}}, actions}
  end

  defp interface_available?(data) do
    not data.config.require_interface or VintageNet.get(["interface", data.ifname, "present"])
  end
end
