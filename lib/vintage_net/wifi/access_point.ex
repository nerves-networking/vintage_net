defmodule VintageNet.WiFi.AccessPoint do
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

  defstruct bssid: "",
            frequency: 0,
            band: "",
            channel: 0,
            signal_dbm: 0,
            flags: [],
            ssid: ""

  @type t :: %__MODULE__{
          bssid: String.t(),
          channel: non_neg_integer(),
          frequency: non_neg_integer(),
          signal_dbm: integer(),
          flags: [flag()],
          ssid: String.t()
        }
end
