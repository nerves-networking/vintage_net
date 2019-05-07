defmodule VintageNet.WiFi.AccessPoint do
  @moduledoc """
  Information about a WiFi access point
  """
  defstruct bssid: "",
            frequency: 0,
            signal: 0,
            flags: [],
            ssid: ""

  @type t :: %__MODULE__{
          bssid: <<_::48>>,
          frequency: non_neg_integer(),
          signal: integer(),
          flags: [atom()],
          ssid: String.t()
        }
end
