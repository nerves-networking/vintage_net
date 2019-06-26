defmodule VintageNet.WiFi.WPASupplicant do
  use GenServer

  alias VintageNet.WiFi.{WPASupplicantDecoder, WPASupplicantLL}
  require Logger

  @moduledoc """

  """
  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(args) do
    ifname = Keyword.fetch!(args, :ifname)
    GenServer.start_link(__MODULE__, args, name: via_name(ifname))
  end

  defp via_name(ifname) do
    {:via, Registry, {VintageNet.Interface.Registry, {__MODULE__, ifname}}}
  end

  @doc """
  Initiate a scan of WiFi networks
  """
  @spec scan(VintageNet.ifname()) :: :ok
  def scan(ifname) do
    GenServer.call(via_name(ifname), :scan)
  end

  @impl true
  def init(args) do
    control_path = Keyword.fetch!(args, :control_path)
    ifname = Keyword.fetch!(args, :ifname)
    keep_alive_interval = Keyword.get(args, :keep_alive_interval, 60000)

    {:ok, ll} = WPASupplicantLL.start_link(control_path)
    :ok = WPASupplicantLL.subscribe(ll)

    state = %{
      keep_alive_interval: keep_alive_interval,
      ll: ll,
      ifname: ifname,
      access_points: %{},
      clients: []
    }

    {:ok, state, {:continue, :continue}}
  end

  @impl true
  def handle_continue(:continue, state) do
    {:ok, "OK\n"} = WPASupplicantLL.control_request(state.ll, "ATTACH")

    # Refresh the AP list
    access_points = get_access_points(state.ll)

    new_state = %{state | access_points: access_points}

    # Make sure that the property table is in sync with our state
    update_access_points_property(new_state)
    update_clients_property(new_state)

    {:noreply, new_state, state.keep_alive_interval}
  end

  @impl true
  def handle_call(:scan, _from, state) do
    response =
      case WPASupplicantLL.control_request(state.ll, "SCAN") do
        {:ok, <<"OK", _rest::binary>>} -> :ok
        {:ok, something_else} -> {:error, String.trim(something_else)}
        error -> error
      end

    {:reply, response, state}
  end

  @impl true
  def handle_info(:timeout, state) do
    case WPASupplicantLL.control_request(state.ll, "PING") do
      {:ok, <<"PONG", _rest::binary>>} ->
        {:noreply, state, state.keep_alive_interval}

      other ->
        raise "Bad PING response: #{inspect(other)}"
    end
  end

  @impl true
  def handle_info({VintageNet.WiFi.WPASupplicantLL, _priority, message}, state) do
    notification = WPASupplicantDecoder.decode_notification(message)

    new_state = handle_notification(notification, state)
    {:noreply, new_state, new_state.keep_alive_interval}
  end

  defp handle_notification({:event, "CTRL-EVENT-SCAN-RESULTS"}, state) do
    # Collect all of the access points
    access_points = get_access_points(state.ll)
    new_state = %{state | access_points: access_points}

    update_access_points_property(new_state)

    new_state
  end

  defp handle_notification({:event, "CTRL-EVENT-BSS-ADDED", _index, bssid}, state) do
    case get_access_point_info(state.ll, bssid) do
      {:ok, ap} ->
        access_points = Map.put(state.access_points, ap.bssid, ap)
        new_state = %{state | access_points: access_points}
        update_access_points_property(new_state)
        new_state

      _error ->
        _ = Logger.warn("AP added and then removed before we could get info on it: #{bssid}")
        state
    end
  end

  defp handle_notification({:event, "CTRL-EVENT-BSS-REMOVED", _index, bssid}, state) do
    access_points = Map.delete(state.access_points, bssid)
    new_state = %{state | access_points: access_points}
    update_access_points_property(new_state)
    new_state
  end

  # Ignored
  defp handle_notification({:event, "CTRL-EVENT-SCAN-STARTED"}, state), do: state

  defp handle_notification({:event, "AP-STA-CONNECTED", client}, state) do
    if client in state.clients do
      state
    else
      clients = [client | state.clients]
      new_state = %{state | clients: clients}
      update_clients_property(new_state)
      new_state
    end
  end

  defp handle_notification({:event, "AP-STA-DISCONNECTED", client}, state) do
    clients = List.delete(state.clients, client)
    new_state = %{state | clients: clients}
    update_clients_property(new_state)
    new_state
  end

  defp handle_notification(unhandled, state) do
    _ = Logger.info("WPASupplicant ignoring #{inspect(unhandled)}")
    state
  end

  defp get_access_points(ll) do
    get_access_points(ll, 0, %{})
  end

  defp get_access_points(ll, index, acc) do
    case get_access_point_info(ll, index) do
      {:ok, ap} ->
        get_access_points(ll, index + 1, Map.put(acc, ap.bssid, ap))

      _error ->
        acc
    end
  end

  defp get_access_point_info(ll, index_or_bssid) do
    with {:ok, raw_response} <- WPASupplicantLL.control_request(ll, "BSS #{index_or_bssid}") do
      case WPASupplicantDecoder.decode_kv_response(raw_response) do
        empty when empty == %{} ->
          {:error, :unknown}

        response ->
          frequency = String.to_integer(response["freq"])
          signal_dbm = String.to_integer(response["level"])
          flags = WPASupplicantDecoder.parse_flags(response["flags"])
          ssid = response["ssid"]
          bssid = response["bssid"]

          ap = VintageNet.WiFi.AccessPoint.new(bssid, ssid, frequency, signal_dbm, flags)
          {:ok, ap}
      end
    end
  end

  defp update_access_points_property(state) do
    VintageNet.PropertyTable.put(
      VintageNet,
      ["interface", state.ifname, "wifi", "access_points"],
      state.access_points
    )
  end

  defp update_clients_property(state) do
    VintageNet.PropertyTable.put(
      VintageNet,
      ["interface", state.ifname, "wifi", "clients"],
      state.clients
    )
  end
end
