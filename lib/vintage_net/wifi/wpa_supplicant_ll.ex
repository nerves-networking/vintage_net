defmodule VintageNet.WiFi.WPASupplicantLL do
  use GenServer
  require Logger

  @moduledoc """
  This modules provides a low-level interface for interacting with the `wpa_supplicant`

  Example use:

  ```elixir
  iex> {:ok, ws} = VintageNet.WiFi.WPASupplicantLL.start_link("/tmp/vintage_net/wpa_supplicant/wlan0")
  {:ok, #PID<0.1795.0>}
  iex> VintageNet.WiFi.WPASupplicantLL.subscribe(ws)
  :ok
  iex> VintageNet.WiFi.WPASupplicantLL.control_request(ws, "ATTACH")
  {:ok, "OK\n"}
  iex> VintageNet.WiFi.WPASupplicantLL.control_request(ws, "SCAN")
  {:ok, "OK\n"}
  iex> flush
  {VintageNet.WiFi.WPASupplicant, 51, "CTRL-EVENT-SCAN-STARTED "}
  {VintageNet.WiFi.WPASupplicant, 51, "CTRL-EVENT-BSS-ADDED 0 78:8a:20:87:7a:50"}
  {VintageNet.WiFi.WPASupplicant, 51, "CTRL-EVENT-SCAN-RESULTS "}
  {VintageNet.WiFi.WPASupplicant, 51, "CTRL-EVENT-NETWORK-NOT-FOUND "}
  :ok
  iex> VintageNet.WiFi.WPASupplicantLL.control_request(ws, "BSS 0")
  {:ok,
  "id=0\nbssid=78:8a:20:82:7a:50\nfreq=2437\nbeacon_int=100\ncapabilities=0x0431\nqual=0\nnoise=-89\nlevel=-71\ntsf=0000333220048880\nage=14\nie=0008426f7062654c414e010882848b968c1298240301062a01003204b048606c0b0504000a00002d1aac011bffffff00000000000000000001000000000000000000003d1606080c000000000000000000000000000000000000007f080000000000000040dd180050f2020101000003a4000027a4000042435e0062322f00dd0900037f01010000ff7fdd1300156d00010100010237e58106788a20867a5030140100000fac040100000fac040100000fac020000\nflags=[WPA2-PSK-CCMP][ESS]\nssid=BopbeLAN\nsnr=18\nest_throughput=48000\nupdate_idx=1\nbeacon_ie=0008426f7062654c414e010882848b968c1298240301060504010300002a01003204b048606c0b0504000a00002d1aac011bffffff00000000000000000001000000000000000000003d1606080c000000000000000000000000000000000000007f080000000000000040dd180050f2020101000003a4000027a4000042435e0062322f00dd0900037f01010000ff7fdd1300156d00010100010237e58106788a20867a5030140100000fac040100000fac040100000fac020000\n"}
  ```

  """

  defmodule State do
    @moduledoc false
    defstruct control_file: nil,
              socket: nil,
              requests: [],
              notification_pid: nil
  end

  @doc """
  Start the WPASupplicant low-level interface

  Pass the path to the wpa_supplicant control file
  """
  @spec start_link(Path.t()) :: GenServer.on_start()
  def start_link(path) do
    GenServer.start_link(__MODULE__, path)
  end

  @spec control_request(GenServer.server(), binary()) :: {:ok, binary()} | {:error, any()}
  def control_request(server, request) do
    GenServer.call(server, {:control_request, request})
  end

  @doc """
  Subscribe to wpa_supplicant notifications
  """
  @spec subscribe(GenServer.server(), pid()) :: :ok
  def subscribe(server, pid \\ self()) do
    GenServer.call(server, {:subscribe, pid})
  end

  @impl true
  def init(path) do
    # Blindly create the control interface's directory in case we beat
    # wpa_supplicant.
    _ = File.mkdir_p(Path.dirname(path))

    # The path to our end of the socket so that wpa_supplicant can send us
    # notifications and responses
    our_path = path <> ".ex"

    # Blindly remove an old file just in case it exists from a previous run
    _ = File.rm(our_path)

    {:ok, socket} =
      :gen_udp.open(0, [:local, :binary, {:active, true}, {:ip, {:local, our_path}}])

    state = %State{control_file: path, socket: socket}
    {:ok, state}
  end

  @impl true
  def handle_call({:control_request, message}, from, state) do
    case :gen_udp.send(state.socket, {:local, state.control_file}, 0, message) do
      :ok ->
        new_requests = state.requests ++ [from]
        {:noreply, %{state | requests: new_requests}}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    {:reply, :ok, %{state | notification_pid: pid}}
  end

  @impl true
  def handle_info(
        {:udp, socket, _, 0, <<?<, priority, ?>, notification::binary()>>},
        %{socket: socket, notification_pid: pid} = state
      ) do
    if pid do
      send(pid, {__MODULE__, priority - ?0, notification})
    else
      _ = Logger.info("wpa_supplicant_ll dropping notification: #{notification}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:udp, socket, _, 0, response}, %{socket: socket} = state) do
    case List.pop_at(state.requests, 0) do
      {nil, _requests} ->
        _ = Logger.warn("wpa_supplicant sent an unexpected message: '#{response}'")
        {:noreply, state}

      {from, new_requests} ->
        GenServer.reply(from, {:ok, response})
        {:noreply, %{state | requests: new_requests}}
    end
  end
end
