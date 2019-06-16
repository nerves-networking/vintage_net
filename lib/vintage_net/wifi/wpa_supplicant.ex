defmodule VintageNet.WiFi.WPASupplicant do
  use GenServer

  alias VintageNet.WiFi.{WPASupplicantDecoder, WPASupplicantLL}
  require Logger

  @moduledoc """

  """

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Initiate a scan of WiFi networks
  """
  def scan(server) do
    GenServer.call(server, :scan)
  end

  @impl true
  def init(args) do
    control_path = Keyword.fetch!(args, :control_path)
    ifname = Keyword.fetch!(args, :ifname)

    {:ok, ll} = WPASupplicantLL.start_link(control_path)
    :ok = WPASupplicantLL.subscribe(ll)

    state = %{
      keep_alive_interval: Keyword.get(args, :keep_alive_interval, 60000),
      ll: ll,
      ifname: ifname
    }

    {:ok, state, {:continue, :continue}}
  end

  @impl true
  def handle_continue(:continue, state) do
    {:ok, "OK\n"} = WPASupplicantLL.control_request(state.ll, "ATTACH")
    {:noreply, state, state.keep_alive_interval}
  end

  @impl true
  def handle_call(:scan, _from, state) do
    {:ok, "OK\n"} = WPASupplicantLL.control_request(state.ll, "SCAN")
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:timeout, state) do
    {:ok, "PONG\n"} = WPASupplicantLL.control_request(state.ll, "PING")
    {:noreply, state, state.keep_alive_interval}
  end

  @impl true
  def handle_info({VintageNet.WiFi.WPASupplicantLL, _priority, message}, state) do
    new_state = handle_notification(String.trim_trailing(message), state)
    {:noreply, new_state, new_state.keep_alive_interval}
  end

  defp handle_notification("CTRL-EVENT-SCAN-RESULTS", state) do
    # Collect all of the access points
    access_points = all_bss(state.ll, 0, %{})

    VintageNet.PropertyTable.put(
      VintageNet,
      ["interface", state.ifname, "access_points"],
      access_points
    )

    state
  end

  # Ignored on purpose
  defp handle_notification("CTRL-EVENT-SCAN-STARTED", state), do: state
  defp handle_notification("CTRL-EVENT-BSS-ADDED " <> _rest, state), do: state
  defp handle_notification("CTRL-EVENT-BSS-REMOVED " <> _rest, state), do: state
  defp handle_notification("CTRL-EVENT-NETWORK-NOT-FOUND", state), do: state

  defp handle_notification(unknown_message, state) do
    _ = Logger.info("WPASupplicant ignoring #{inspect(unknown_message)}")
    state
  end

  defp all_bss(ll, count, acc) do
    {:ok, raw_response} = WPASupplicantLL.control_request(ll, "BSS #{count}")
    response = WPASupplicantDecoder.decode_kv_response(raw_response)

    if response == %{} do
      acc
    else
      ap = %VintageNet.WiFi.AccessPoint{
        bssid: response["bssid"],
        frequency: response["freq"],
        signal: response["level"],
        flags: parse_flags(response["flags"]),
        ssid: response["ssid"]
      }

      all_bss(ll, count + 1, Map.put(acc, ap.bssid, ap))
    end
  end

  defp parse_flags(flags) do
    flags
    |> String.split(["]", "["], trim: true)
    |> Enum.flat_map(&parse_flag/1)
  end

  defp parse_flag("WPA2-PSK-CCMP"), do: [:wpa2_psk_ccmp]
  defp parse_flag("WPA2-EAP-CCMP"), do: [:wpa2_eap_ccmp]
  defp parse_flag("WPA2-PSK-CCMP+TKIP"), do: [:wpa2_psk_ccmp_tkip]
  defp parse_flag("WPA-PSK-CCMP+TKIP"), do: [:wpa_psk_ccmp_tkip]
  defp parse_flag("IBSS"), do: [:ibss]
  defp parse_flag("MESH"), do: [:mesh]
  defp parse_flag("ESS"), do: [:ess]
  defp parse_flag("P2P"), do: [:p2p]
  defp parse_flag("WPS"), do: [:wps]
  defp parse_flag("RSN--CCMP"), do: [:rsn_ccmp]

  defp parse_flag(other) do
    _ = Logger.warn("Ignoring unknown WiFi Access Point flag: #{other}")
    []
  end
end
