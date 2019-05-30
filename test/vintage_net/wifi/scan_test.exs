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

  test "wpa2 eap access point" do
    results = """
    bssid / frequency / signal level / flags / ssid
    ac:86:74:5b:ea:42\t2462\t-81\t[WPA2-EAP-CCMP][ESS]\tenterprise lan
    """

    output = [
      %VintageNet.WiFi.AccessPoint{
        bssid: "ac:86:74:5b:ea:42",
        frequency: 2462,
        signal: -81,
        flags: [:wpa2_eap_ccmp, :ess],
        ssid: "enterprise lan"
      }
    ]

    assert output == Scan.parse(results)
  end

  test "mesh access point" do
    results = """
    bssid / frequency / signal level / flags / ssid
    ae:86:74:5b:ea:46\t2462\t-69\t[RSN--CCMP][MESH]\tmesh
    """

    output = [
      %VintageNet.WiFi.AccessPoint{
        bssid: "ae:86:74:5b:ea:46",
        frequency: 2462,
        signal: -69,
        flags: [:rsn_ccmp, :mesh],
        ssid: "mesh"
      }
    ]

    assert output == Scan.parse(results)
  end

  test "ibss access point" do
    results = """
    bssid / frequency / signal level / flags / ssid
    26:9e:db:0d:4f:21\t2412\t-74\t[IBSS]\tSETUP
    """

    output = [
      %VintageNet.WiFi.AccessPoint{
        bssid: "26:9e:db:0d:4f:21",
        frequency: 2412,
        signal: -74,
        flags: [:ibss],
        ssid: "SETUP"
      }
    ]

    assert output == Scan.parse(results)
  end

  test "wps access point" do
    results = """
    bssid / frequency / signal level / flags / ssid
    04:18:d6:47:1a:6a\t2462\t-74\t[WPA2-PSK-CCMP+TKIP][WPS]\twps lan
    """

    output = [
      %VintageNet.WiFi.AccessPoint{
        bssid: "04:18:d6:47:1a:6a",
        frequency: 2462,
        signal: -74,
        flags: [:wpa2_psk_ccmp_tkip, :wps],
        ssid: "wps lan"
      }
    ]

    assert output == Scan.parse(results)
  end
end
