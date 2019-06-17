defmodule VintageNet.WiFi.WPASupplicantTest do
  use ExUnit.Case

  alias VintageNet.WiFi.WPASupplicant
  alias VintageNetTest.MockWPASupplicant

  setup do
    socket_path = "test_tmp/tmp_wpa_supplicant_socket"
    mock = start_supervised!({MockWPASupplicant, socket_path})

    on_exit(fn ->
      _ = File.rm(socket_path)
      _ = File.rm(socket_path <> ".ex")
    end)

    {:ok, socket_path: socket_path, mock: mock}
  end

  test "attaches to wpa_supplicant", context do
    MockWPASupplicant.set_responses(context.mock, %{"ATTACH" => ["OK\n"]})
    _ = start_supervised!({WPASupplicant, ifname: "wlan0", control_path: context.socket_path})

    Process.sleep(100)
    assert MockWPASupplicant.get_requests(context.mock) == ["ATTACH"]
  end

  test "pings wpa_supplicant", context do
    MockWPASupplicant.set_responses(context.mock, %{"ATTACH" => "OK\n", "PING" => "PONG\n"})

    _ =
      start_supervised!(
        {WPASupplicant,
         ifname: "wlan0", control_path: context.socket_path, keep_alive_interval: 10}
      )

    Process.sleep(100)
    requests = MockWPASupplicant.get_requests(context.mock)
    assert "ATTACH" in requests
    assert "PING" in requests
  end

  test "scan updates properties", context do
    # TODO: Double check that this is what the real wpa_supplicant does
    MockWPASupplicant.set_responses(context.mock, %{
      "ATTACH" => "OK\n",
      "PING" => "PONG\n",
      "SCAN" => [
        "OK\n",
        "<2>CTRL-EVENT-SCAN-STARTED ",
        "<2>CTRL-EVENT-BSS-ADDED 0 78:8a:20:87:7a:50",
        "<2>CTRL-EVENT-SCAN-RESULTS ",
        "<2>CTRL-EVENT-NETWORK-NOT-FOUND "
      ],
      "BSS 0" =>
        "id=0\nbssid=78:8a:20:82:7a:50\nfreq=2437\nbeacon_int=100\ncapabilities=0x0431\nqual=0\nnoise=-89\nlevel=-71\ntsf=0000333220048880\nage=14\nie=0008426f7062654c414e010882848b968c1298240301062a01003204b048606c0b0504000a00002d1aac011bffffff00000000000000000001000000000000000000003d1606080c000000000000000000000000000000000000007f080000000000000040dd180050f2020101000003a4000027a4000042435e0062322f00dd0900037f01010000ff7fdd1300156d00010100010237e58106788a20867a5030140100000fac040100000fac040100000fac020000\nflags=[WPA2-PSK-CCMP][ESS]\nssid=TestLAN\nsnr=18\nest_throughput=48000\nupdate_idx=1\nbeacon_ie=0008426f7062654c414e010882848b968c1298240301060504010300002a01003204b048606c0b0504000a00002d1aac011bffffff00000000000000000001000000000000000000003d1606080c000000000000000000000000000000000000007f080000000000000040dd180050f2020101000003a4000027a4000042435e0062322f00dd0900037f01010000ff7fdd1300156d00010100010237e58106788a20867a5030140100000fac040100000fac040100000fac020000\n",
      "BSS 1" => ""
    })

    _supplicant =
      start_supervised!({WPASupplicant, ifname: "test_wlan0", control_path: context.socket_path})

    ap_property = ["interface", "test_wlan0", "access_points"]
    VintageNet.PropertyTable.clear(VintageNet, ap_property)

    VintageNet.subscribe(ap_property)
    :ok = WPASupplicant.scan("test_wlan0")

    assert_receive {VintageNet, ^ap_property, _old,
                    %{
                      "78:8a:20:82:7a:50" => %VintageNet.WiFi.AccessPoint{
                        bssid: "78:8a:20:82:7a:50",
                        flags: [:wpa2_psk_ccmp, :ess],
                        frequency: 2437,
                        signal: -71,
                        ssid: "TestLAN"
                      }
                    }, _metadata}
  end
end
