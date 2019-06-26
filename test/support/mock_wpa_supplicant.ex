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

  @spec get_requests(GenServer.server()) :: []
  def get_requests(server) do
    GenServer.call(server, :get_requests)
  end

  @spec send_message(GenServer.server(), binary()) :: :ok
  def send_message(server, message) do
    GenServer.cast(server, {:send_message, message})
  end

  @impl true
  def init(path) do
    _ = File.rm(path)

    {:ok, socket} = :gen_udp.open(0, [:local, :binary, {:active, true}, {:ip, {:local, path}}])

    {:ok,
     %{
       socket_path: path,
       socket: socket,
       client_path: path <> ".ex",
       responses: %{},
       requests: []
     }}
  end

  @impl true
  def handle_call({:set_responses, responses}, _from, state) do
    {:reply, :ok, %{state | responses: responses}}
  end

  @impl true
  def handle_call(:get_requests, _from, %{requests: requests} = state) do
    {:reply, requests, state}
  end

  @impl true
  def handle_cast(
        {:send_message, message},
        %{socket: socket, client_path: client_path} = state
      ) do
    case :gen_udp.send(socket, {:local, client_path}, 0, message) do
      :ok ->
        :ok

      {:error, reason} ->
        raise ":gen_udp.send failed to send to #{client_path}: #{inspect(reason)}"
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:udp, socket, from, 0, message},
        %{socket: socket, responses: responses, requests: requests} = state
      ) do
    responses
    |> lookup(message)
    |> Enum.each(fn payload ->
      :ok = :gen_udp.send(socket, from, 0, payload)
    end)

    {:noreply, %{state | requests: requests ++ [message]}}
  end

  defp lookup(responses, message) do
    case Map.get(responses, message, "Mock doesn't know about #{message}") do
      list when is_list(list) -> list
      other -> [other]
    end
  end
end
