defmodule VintageNet.WiFi.ScanTest do
  use ExUnit.Case
  alias VintageNet.WiFi.Scan

  doctest Scan

  test "wpa2 access points" do
    results = """
    bssid / frequency / signal level / flags / ssid
    78:8a:20:87:7a:50\t2437\t-81\t[WPA2-PSK-CCMP][ESS]\tmylan
    62:01:94:b3:a7:3c\t2412\t-55\t[ESS]\tanother_lan
    """

    output = [
      %VintageNet.WiFi.AccessPoint{
        bssid: "78:8a:20:87:7a:50",
        frequency: 2437,
        signal: -81,
        flags: [:wpa2_psk_ccmp, :ess],
        ssid: "mylan"
      },
      %VintageNet.WiFi.AccessPoint{
        bssid: "62:01:94:b3:a7:3c",
        frequency: 2412,
        signal: -55,
        flags: [:ess],
        ssid: "another_lan"
      }
    ]

    assert output == Scan.parse(results)
  end
end
