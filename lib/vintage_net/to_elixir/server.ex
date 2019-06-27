defmodule VintageNet.ToElixir.Server do
  use GenServer
  require Logger

  alias VintageNet.ToElixir.{UdhcpcHandler, UdhcpdHandler}

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
  def handle_info({:udp, socket, _, 0, data}, %{socket: socket} = state) do
    data
    |> :erlang.binary_to_term()
    |> normalize_argv0()
    |> dispatch()

    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Try to clean up
    _ = File.rm(state.path)
  end

  defp normalize_argv0({[argv0 | args], env}) do
    {[Path.basename(argv0) | args], env}
  end

  defp dispatch({["udhcpc_handler", command], %{interface: interface} = env}) do
    UdhcpcHandler.dispatch(udhcpc_command(command), interface, env)
    :ok
  end

  defp dispatch({["udhcpd_handler", lease_file], _env}) do
    [_, interface, "leases"] = String.split(lease_file, ".")
    UdhcpdHandler.dispatch(:lease_update, interface, lease_file)
  end

  defp dispatch({["to_elixir" | args], _env}) do
    message = Enum.join(args, " ")
    _ = Logger.debug("Got a generic message: #{message}")
    :ok
  end

  defp dispatch(unknown) do
    _ = Logger.error("to_elixir: dropping unknown report '#{inspect(unknown)}''")
    :ok
  end

  defp udhcpc_command("deconfig"), do: :deconfig
  defp udhcpc_command("leasefail"), do: :leasefail
  defp udhcpc_command("nak"), do: :nak
  defp udhcpc_command("renew"), do: :renew
  defp udhcpc_command("bound"), do: :bound
end
