defmodule VintageNet.Interface do
  use GenServer

  require Logger

  defmodule State do
    @moduledoc false

    defstruct iface: nil, command_ref: nil
  end

  def start_link(iface) do
    GenServer.start_link(__MODULE__, iface)
  end

  def up(interface_pid) do
    GenServer.cast(interface_pid, :ifup)
  end

  def down(interface_pid) do
    GenServer.cast(interface_pid, :ifdown)
  end

  @impl true
  def init(iface) do
    {:ok, iface, {:continue, :ifup}}
  end

  @impl true
  def handle_cast(:ifup, iface) do
    bringup_interface(iface)
    {:noreply, iface}
  end

  @impl true
  def handle_cast(:ifdown, iface) do
    cleanup_interface(iface)
    {:noreply, iface}
  end

  @impl true
  def handle_continue(:ifup, iface) do
    bringup_interface(iface)
    {:noreply, iface}
  end

  defp bringup_interface({ifname, ifconfig}) do
    Logger.info("Bringing up #{ifname}")
    # Create all of the files
    Enum.each(ifconfig.files, fn {path, content} -> create_and_write_file(path, content) end)

    # Run all of the up commands
    Enum.each(ifconfig.up_cmds, &run_command/1)
    Logger.info("Done bringing up #{ifname}")
  end

  defp create_and_write_file(path, content) do
    dir = Path.dirname(path)
    File.exists?(dir) || File.mkdir_p!(dir)

    File.write!(path, content)
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
    case System.cmd(command, args) do
      {_, 0} ->
        :ok

      {message, _not_zero} ->
        Logger.error("Error running #{command} #{inspect(args)}: #{message}")
        {:error, message}
    end
  end
end
