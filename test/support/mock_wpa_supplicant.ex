defmodule VintageNetTest.MockWPASupplicant do
  use GenServer

  @spec start_link(Path.t()) :: GenServer.on_start()
  def start_link(path) do
    GenServer.start_link(__MODULE__, path)
  end

  @spec set_responses(GenServer.server(), map()) :: :ok
  def set_responses(server, responses) do
    GenServer.call(server, {:set_responses, responses})
  end

  @spec send_message(GenServer.server(), binary()) :: :ok
  def send_message(server, message) do
    GenServer.cast(server, {:send_message, message})
  end

  @impl true
  def init(path) do
    _ = File.rm(path)

    {:ok, socket} = :gen_udp.open(0, [:local, :binary, {:active, true}, {:ip, {:local, path}}])

    {:ok, %{socket_path: path, socket: socket, client_path: path <> ".ex", responses: %{}}}
  end

  @impl true
  def handle_call({:set_responses, responses}, _from, state) do
    {:reply, :ok, %{state | responses: responses}}
  end

  @impl true
  def handle_cast(
        {:send_message, message},
        %{socket: socket, client_path: client_path} = state
      ) do
    :ok = :gen_udp.send(socket, {:local, client_path}, 0, message)
    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:udp, socket, from, 0, message},
        %{socket: socket, responses: responses} = state
      ) do
    :ok =
      :gen_udp.send(
        socket,
        from,
        0,
        Map.get(responses, message, "Mock doesn't know about #{message}")
      )

    {:noreply, state}
  end
end
