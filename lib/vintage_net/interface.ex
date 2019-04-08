defmodule VintageNet.Interface do
  use GenServer

  require Logger

  defmodule State do
    @moduledoc false

    defstruct iface: nil,
              command_pid: nil,
              command_queue: [],
              command_timer: nil,
              status: :down,
              current_command: nil
  end

  def start_link(iface) do
    GenServer.start_link(__MODULE__, iface)
  end

  def status(interface_pid) do
    GenServer.call(interface_pid, :status)
  end

  def up(interface_pid) do
    GenServer.cast(interface_pid, :ifup)
  end

  def down(interface_pid) do
    GenServer.cast(interface_pid, :ifdown)
  end

  @impl true
  def init({_iface, ifconfig} = iface) do
    {:ok, %State{iface: iface, command_queue: ifconfig.up_cmds}, {:continue, :ifup}}
  end

  @impl true
  def handle_call(:status, _from, %State{status: status} = state), do: {:reply, status, state}

  @impl true
  def handle_cast(:ifup, %State{iface: iface}) do
    {:noreply, %State{iface: iface}}
  end

  @impl true
  def handle_cast(:ifdown, iface) do
    cleanup_interface(iface)
    {:noreply, iface}
  end

  @impl true
  def handle_continue(:ifup, %State{command_queue: []} = state) do
    {:noreply, %{state | status: :up}}
  end

  def handle_continue(
        :ifup,
        %State{iface: iface, command_queue: [command | rest]} = state
      ) do
    {:ok, command_pid} = bringup_interface(iface, command)

    {:noreply,
     %{
       state
       | command_queue: rest,
         command_pid: command_pid,
         command_timer: command_timeout_timer(),
         current_command: command
     }}
  end

  @impl true
  def handle_info(
        :command_timeout,
        %State{command_pid: command_pid, current_command: command_data} = state
      ) do
    if Process.alive?(command_pid) do
      Logger.warn("Command timed out #{inspect(command_data)}")
      Process.exit(command_pid, :kill)
      {:stop, :command_timeout}
    else
      {:noreply, %{state | command_pid: nil, current_command: nil}}
    end
  end

  def handle_info(:command_finished, %State{command_timer: timer, command_queue: []} = state) do
    Process.cancel_timer(timer)

    {:noreply, %{state | command_pid: nil, command_timer: nil, status: :up, current_command: nil}}
  end

  def handle_info(
        :command_finished,
        %State{
          iface: iface,
          command_timer: timer,
          command_queue: [command | rest]
        } = state
      ) do
    Process.cancel_timer(timer)

    {:ok, command_pid} = bringup_interface(iface, command)

    {:noreply,
     %{
       state
       | command_pid: command_pid,
         command_timer: command_timeout_timer(),
         command_queue: rest,
         current_command: command
     }}
  end

  defp write_interface_files(ifconfig) do
    Enum.each(ifconfig.files, fn {path, content} -> create_and_write_file(path, content) end)
  end

  defp create_and_write_file(path, content) do
    dir = Path.dirname(path)
    File.exists?(dir) || File.mkdir_p!(dir)

    File.write!(path, content)
  end

  defp bringup_interface({_ifname, ifconfig}, command) do
    :ok = write_interface_files(ifconfig)
    run_command(command)
  end

  defp cleanup_interface({ifname, ifconfig}) do
    Logger.info("Bringing down #{ifname}")
    # Run all of the down commands
    Enum.each(ifconfig.down_cmds, &run_command/1)

    # Erase all of the files
    Enum.each(ifconfig.files, fn {path, _contents} -> File.rm(path) end)
    Logger.info("Done bringing down #{ifname}")
  end

  defp run_command({:run, command, args}) do
    interface_pid = self()

    Task.start_link(fn ->
      case MuonTrap.cmd(command, args) do
        {_, 0} ->
          send(interface_pid, :command_finished)

        {message, _not_zero} ->
          Logger.error("Error running #{command}, #{inspect(args)}: #{message}")
          {:error, message}
      end
    end)
  end

  defp command_timeout_timer() do
    Process.send_after(self(), :command_timeout, 5_000)
  end
end
