defmodule VintageNet.Applier do
  use GenServer
  require Logger

  @moduledoc """
  This module applies digested configurations.
  """

  @doc """
  Start up the network configuration applier
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Apply a configuration to the system
  """
  def update_config(input) do
    GenServer.call(__MODULE__, {:update_config, input}, 20_000)
  end

  @impl true
  def init(args) do
    # Matt - I'm sure you won't be able to help yourself with this next line.
    state = Map.new(args)
    {:ok, state, {:continue, :first_time_config}}
  end

  @impl true
  def handle_continue(:first_time_config, state) do
    Enum.each(state.config, &bringup_interface/1)
    {:noreply, state}
  end

  @impl true
  def handle_call({:update_config, input}, _from, state) do
    Enum.each(state.config, &cleanup_interface/1)
    Enum.each(input, &bringup_interface/1)

    {:reply, :ok, %{state | config: input}}
  end

  defp bringup_interface({ifname, ifconfig}) do
    Logger.info("Bringing up #{ifname}")
    # Create all of the files
    Enum.each(ifconfig.files, fn {path, content} -> create_and_write_file(path, content) end)

    # Run all of the up commands
    Enum.each(ifconfig.up_cmds, &run_command/1)
    Logger.info("Done bringing up #{ifname}")
  end

  defp cleanup_interface({ifname, ifconfig}) do
    Logger.info("Bringing down #{ifname}")
    # Run all of the down commands
    Enum.each(ifconfig.down_cmds, &run_command/1)

    # Erase all of the files
    Enum.each(ifconfig.files, fn {path, _contents} -> File.rm(path) end)
    Logger.info("Done bringing down #{ifname}")
  end

  defp create_and_write_file(path, content) do
    dir = Path.dirname(path)
    File.exists?(dir) || File.mkdir_p!(dir)

    File.write!(path, content)
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
