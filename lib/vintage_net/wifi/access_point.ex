defmodule VintageNet.WiFi.AccessPoint do
  alias VintageNet.WiFi.Utils

  @moduledoc """
  Information about a WiFi access point

  * `:bssid` - a unique address for the access point
  * `:flags` - a list of flags describing properties on the access point
  * `:frequency` - the access point's frequency in MHz
  * `:signal_dbm` - the signal strength in dBm
  * `:ssid` - the access point's name
  """

  @type flag ::
          :wpa2_psk_ccmp
          | :wpa2_eap_ccmp
          | :wpa2_psk_ccmp_tkip
          | :wpa_psk_ccmp_tkip
          | :ibss
          | :mesh
          | :ess
          | :p2p
          | :wps
          | :rsn_ccmp

  @type band :: :wifi_2_4_ghz | :wifi_5_ghz | :unknown

  defstruct [:bssid, :frequency, :band, :channel, :signal_dbm, :signal_percent, :flags, :ssid]

  @type t :: %__MODULE__{
          bssid: String.t(),
          frequency: non_neg_integer(),
          band: band(),
          channel: non_neg_integer(),
          signal_dbm: integer(),
          signal_percent: 0..100,
          flags: [flag()],
          ssid: String.t()
        }

  @doc """
  Create a new AccessPoint struct
  """
  @spec new(String.t(), String.t(), non_neg_integer(), integer(), [flag()]) ::
          VintageNet.WiFi.AccessPoint.t()
  def new(bssid, ssid, frequency, signal_dbm, flags) do
    info = Utils.frequency_info(frequency)

    %__MODULE__{
      bssid: bssid,
      frequency: frequency,
      band: info.band,
      channel: info.channel,
      signal_dbm: signal_dbm,
      signal_percent: info.dbm_to_percent.(signal_dbm),
      flags: flags,
      ssid: ssid
    }
  end
end
