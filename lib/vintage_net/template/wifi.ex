defmodule VintageNet.Template.WiFi do
  @moduledoc """
  Settings templates for WiFi connections
  """

  def simple_wpa2(ssid, passphrase) do
    {:ok, psk} = VintageNet.WiFi.WPA2.to_psk(ssid, passphrase)

    %{
      type: :wifi,
      wifi: %{
        regulatory_domain: "US",
        ssid: ssid,
        mode: :client,
        psk: psk,
        key_mgmt: :wpa_psk
      },
      ipv4: %{method: :dhcp}
    }
  end
end
