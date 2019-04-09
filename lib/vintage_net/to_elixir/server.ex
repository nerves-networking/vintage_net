defmodule VintageNet.ToElixir.Server do
  use GenServer
  require Logger

  @moduledoc """
  This GenServer routes messages from C and shell scripts to the appropriate
  places in VintageNet.
  """

  @doc """
  Start the GenServer.
  """
  @spec start_link(Path.t()) :: GenServer.on_start()
  def start_link(path) do
    GenServer.start_link(__MODULE__, path, name: __MODULE__)
  end

  @impl true
  def init(path) do
    # Blindly try to remove an old file just in case it exists from a previous run
    _ = File.rm(path)
    _ = File.mkdir_p(Path.dirname(path))

    {:ok, socket} = :gen_udp.open(0, [:local, :binary, {:active, true}, {:ip, {:local, path}}])

    state = %{path: path, socket: socket}
    {:ok, state}
  end

  @impl true
  def handle_info({:udp, socket, _, 0, message}, %{socket: socket} = state) do
    dispatch(message)

    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Try to clean up
    _ = File.rm(state.path)
  end

  defp dispatch("udhcpc:" <> message) do
    _ = Logger.debug("Got a message from udhcpc: #{message}")
    :ok
  end

  defp dispatch(unknown) do
    _ = Logger.error("to_elixir: dropping unknown message '#{unknown}''")
    :ok
  end
end
