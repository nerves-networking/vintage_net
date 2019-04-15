defmodule VintageNet.Interface do
  use GenServer

  require Logger

  alias VintageNet.IP

  defmodule State do
    @moduledoc false

    defstruct iface: nil,
              command_pid: nil,
              command_queue: [],
              command_timer: nil,
              status: :down,
              current_command: nil
  end

  def start_link({name, _} = iface) do
    GenServer.start_link(__MODULE__, iface, name: via_name(name))
  end

  def via_name(iface_name) do
    VintageNet.Interface.Registry.via_name(__MODULE__, iface_name)
  end

  def status(interface) do
    name = via_name(interface)
    GenServer.call(name, :status)
  end

  def up(interface) do
    name = via_name(interface)
    GenServer.cast(name, :ifup)
  end

  def down(interface) do
    name = via_name(interface)
    GenServer.cast(name, :ifdown)
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
  def handle_cast(:ifdown, %State{iface: {_, ifconfig}} = state) do
    case ifconfig.down_cmds do
      [] ->
        {:noreply, state}

      [command | rest] ->
        {:ok, command_pid} = run_command(command)

        {:noreply,
         %{
           state
           | command_queue: rest,
             command_pid: command_pid,
             current_command: command,
             command_timer: command_timeout_timer()
         }}
    end
  end

  @impl true
  def handle_continue(:ifup, %State{command_queue: []} = state) do
    {:noreply, %{state | status: :up}}
  end

  def handle_continue(
        :ifup,
        %State{iface: iface, command_queue: [command | rest]} = state
      ) do
    status_check_timer()
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
  def handle_info(:retry_command, %State{current_command: command} = state) do
    {:ok, command_pid} = run_command(command)

    {:noreply,
     %{
       state
       | command_timer: command_timeout_timer(),
         command_pid: command_pid
     }}
  end

  def handle_info(
        :command_timeout,
        %State{command_pid: command_pid, current_command: command} = state
      ) do
    if Process.alive?(command_pid) do
      Logger.warn("Command timed out #{inspect(command)}")
      Process.exit(command_pid, :normal)
      retry_command()
      {:noreply, %{state | command_pid: nil, command_timer: nil}}
    else
      {:noreply, %{state | command_pid: nil, current_command: nil}}
    end
  end

  def handle_info(
        :command_finished,
        %State{command_timer: timer, command_queue: [], status: :down} = state
      ) do
    Process.cancel_timer(timer)

    {:noreply, %{state | command_pid: nil, command_timer: nil, status: :up, current_command: nil}}
  end

  def handle_info(
        :command_finished,
        %State{command_timer: timer, command_queue: [], status: :up, iface: {_, ifconfig}} = state
      ) do
    Process.cancel_timer(timer)
    Enum.each(ifconfig.files, fn {path, _contents} -> File.rm(path) end)

    {:noreply,
     %{state | command_pid: nil, command_timer: nil, status: :down, current_command: nil}}
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

  def handle_info(:check_status, %State{iface: iface} = state) do
    check_iface_status(iface)
    {:noreply, state}
  end

  def handle_info({:iface_status, status}, %State{status: status} = state) do
    status_check_timer()
    {:noreply, state}
  end

  def handle_info({:iface_status, _}, %State{status: :down} = state) do
    status_check_timer()
    {:noreply, %{state | status: :up}}
  end

  def handle_info({:iface_status, _}, %State{status: :up} = state) do
    status_check_timer()
    {:noreply, %{state | status: :down}}
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

  defp check_iface_status({iface, _}) do
    interface_pid = self()

    Task.start_link(fn ->
      case IP.iface_flags(iface) do
        {:error, reason} ->
          Logger.error("#{reason}")

        flags ->
          if Enum.member?(flags, :up) do
            send(interface_pid, {:iface_status, :up})
          else
            send(interface_pid, {:iface_status, :down})
          end
      end
    end)
  end

  defp command_timeout_timer() do
    Process.send_after(self(), :command_timeout, 5_000)
  end

  defp retry_command() do
    Process.send_after(self(), :retry_command, 5_000)
  end

  defp status_check_timer() do
    Process.send_after(self(), :check_status, 2_500)
  end
end
