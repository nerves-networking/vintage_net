defmodule VintageNet.WiFi.WPASupplicantTest do
  use ExUnit.Case

  alias VintageNet.WiFi.WPASupplicant
  alias VintageNetTest.MockWPASupplicant

  setup do
    socket_path = "test_tmp/tmp_wpa_supplicant_socket"
    File.mkdir_p!(socket_path)

    mock = start_supervised!({MockWPASupplicant, Path.join(socket_path, "test_wlan0")})

    p2p_dev_mock =
      start_supervised!({MockWPASupplicant, Path.join(socket_path, "p2p-dev-test_wlan0")},
        id: :p2p_dev
      )

    on_exit(fn ->
      _ = File.rm_rf(socket_path)
    end)

    {:ok, socket_path: socket_path, mock: mock, p2p_dev_mock: p2p_dev_mock}
  end

  test "attaches to wpa_supplicant", context do
    MockWPASupplicant.set_responses(context.mock, %{"ATTACH" => ["OK\n"]})

    _ =
      start_supervised!(
        {WPASupplicant,
         wpa_supplicant: "",
         wpa_supplicant_conf_path: "/dev/null",
         ifname: "test_wlan0",
         control_path: context.socket_path}
      )

    Process.sleep(100)

    # We care that the first message is ATTACH. There can be other messages.
    assert hd(MockWPASupplicant.get_requests(context.mock)) == "ATTACH"
  end

  test "pings wpa_supplicant", context do
    MockWPASupplicant.set_responses(context.mock, %{"ATTACH" => "OK\n", "PING" => "PONG\n"})

    _ =
      start_supervised!(
        {WPASupplicant,
         wpa_supplicant: "",
         wpa_supplicant_conf_path: "/dev/null",
         ifname: "test_wlan0",
         control_path: context.socket_path,
         keep_alive_interval: 10}
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
      start_supervised!(
        {WPASupplicant,
         wpa_supplicant: "",
         wpa_supplicant_conf_path: "/dev/null",
         ifname: "test_wlan0",
         control_path: context.socket_path}
      )

    ap_property = ["interface", "test_wlan0", "wifi", "access_points"]
    VintageNet.PropertyTable.clear(VintageNet, ap_property)

    VintageNet.subscribe(ap_property)
    :ok = WPASupplicant.scan("test_wlan0")

    assert_receive {VintageNet, ^ap_property, _old,
                    [
                      %VintageNet.WiFi.AccessPoint{
                        bssid: "78:8a:20:82:7a:50",
                        flags: [:wpa2_psk_ccmp, :ess],
                        frequency: 2437,
                        signal_dbm: -71,
                        ssid: "TestLAN"
                      }
                    ], _metadata}
  end

  test "ap-mode station connect updates property", context do
    MockWPASupplicant.set_responses(context.mock, %{
      "ATTACH" => "OK\n",
      "PING" => "PONG\n"
    })

    MockWPASupplicant.set_responses(context.p2p_dev_mock, %{
      "ATTACH" => "OK\n",
      "PING" => "PONG\n"
    })

    clients_property = ["interface", "test_wlan0", "wifi", "clients"]
    VintageNet.PropertyTable.clear(VintageNet, clients_property)
    VintageNet.subscribe(clients_property)

    _supplicant =
      start_supervised!(
        {WPASupplicant,
         wpa_supplicant: "",
         wpa_supplicant_conf_path: "/dev/null",
         ifname: "test_wlan0",
         control_path: context.socket_path,
         ap_mode: true}
      )

    # This serves two purposes:
    #  1. tests that the client property is initialized
    #  2. waits for the WPASupplicant to be ready to receive messages for our tests

    assert_receive {VintageNet, ^clients_property, nil, [], _metadata}

    :ok = MockWPASupplicant.send_message(context.mock, "<1>AP-STA-CONNECTED f8:a2:d6:b5:d4:07")
    assert_receive {VintageNet, ^clients_property, _old, ["f8:a2:d6:b5:d4:07"], _metadata}

    :ok = MockWPASupplicant.send_message(context.mock, "<1>AP-STA-DISCONNECTED f8:a2:d6:b5:d4:07")
    assert_receive {VintageNet, ^clients_property, _old, [], _metadata}

    :ok = MockWPASupplicant.send_message(context.mock, "<1>AP-STA-DISCONNECTED f8:a2:d6:b5:d4:07")
    refute_receive {VintageNet, ^clients_property, _old, [], _metadata}
  end

  test "handles scan failures", context do
    MockWPASupplicant.set_responses(context.mock, %{
      "ATTACH" => "OK\n",
      "PING" => "PONG\n",
      "SCAN" => ["FAIL-BUSY  \n"]
    })

    _supplicant =
      start_supervised!(
        {WPASupplicant,
         wpa_supplicant: "",
         wpa_supplicant_conf_path: "/dev/null",
         ifname: "test_wlan0",
         control_path: context.socket_path}
      )

    assert {:error, "FAIL-BUSY"} == WPASupplicant.scan("test_wlan0")
  end

  test "incremental scan works", context do
    # sometimes the wpa_supplicant just reports "BSS-ADDED" and never that there are results
    MockWPASupplicant.set_responses(context.mock, %{
      "ATTACH" => "OK\n",
      "PING" => "PONG\n",
      "SCAN" => [
        "OK\n",
        "<2>CTRL-EVENT-SCAN-STARTED ",
        "<2>CTRL-EVENT-BSS-ADDED 0 78:8a:20:87:7a:50"
      ],
      "BSS 78:8a:20:87:7a:50" =>
        "id=0\nbssid=78:8a:20:82:7a:50\nfreq=2437\nbeacon_int=100\ncapabilities=0x0431\nqual=0\nnoise=-89\nlevel=-71\ntsf=0000333220048880\nage=14\nie=0008426f7062654c414e010882848b968c1298240301062a01003204b048606c0b0504000a00002d1aac011bffffff00000000000000000001000000000000000000003d1606080c000000000000000000000000000000000000007f080000000000000040dd180050f2020101000003a4000027a4000042435e0062322f00dd0900037f01010000ff7fdd1300156d00010100010237e58106788a20867a5030140100000fac040100000fac040100000fac020000\nflags=[WPA2-PSK-CCMP][ESS]\nssid=TestLAN\nsnr=18\nest_throughput=48000\nupdate_idx=1\nbeacon_ie=0008426f7062654c414e010882848b968c1298240301060504010300002a01003204b048606c0b0504000a00002d1aac011bffffff00000000000000000001000000000000000000003d1606080c000000000000000000000000000000000000007f080000000000000040dd180050f2020101000003a4000027a4000042435e0062322f00dd0900037f01010000ff7fdd1300156d00010100010237e58106788a20867a5030140100000fac040100000fac040100000fac020000\n"
    })

    _supplicant =
      start_supervised!(
        {WPASupplicant,
         wpa_supplicant: "",
         wpa_supplicant_conf_path: "/dev/null",
         ifname: "test_wlan0",
         control_path: context.socket_path}
      )

    ap_property = ["interface", "test_wlan0", "wifi", "access_points"]
    VintageNet.PropertyTable.clear(VintageNet, ap_property)

    VintageNet.subscribe(ap_property)
    :ok = WPASupplicant.scan("test_wlan0")

    assert_receive {VintageNet, ^ap_property, _old,
                    [
                      %VintageNet.WiFi.AccessPoint{
                        bssid: "78:8a:20:82:7a:50",
                        flags: [:wpa2_psk_ccmp, :ess],
                        frequency: 2437,
                        signal_dbm: -71,
                        ssid: "TestLAN"
                      }
                    ], _metadata}
  end

  test "incremental add and remove bss", context do
    # sometimes the wpa_supplicant just reports "BSS-ADDED" and never that there are results
    MockWPASupplicant.set_responses(context.mock, %{
      "ATTACH" => "OK\n",
      "PING" => "PONG\n",
      "SCAN" => [
        "OK\n",
        "<2>CTRL-EVENT-SCAN-STARTED ",
        "<2>CTRL-EVENT-BSS-ADDED 7 78:8a:20:87:7a:50",
        "<2>CTRL-EVENT-BSS-REMOVED 7 78:8a:20:87:7a:50"
      ],
      "BSS 78:8a:20:87:7a:50" =>
        "id=0\nbssid=78:8a:20:87:7a:50\nfreq=2437\nbeacon_int=100\ncapabilities=0x0431\nqual=0\nnoise=-89\nlevel=-71\ntsf=0000333220048880\nage=14\nie=0008426f7062654c414e010882848b968c1298240301062a01003204b048606c0b0504000a00002d1aac011bffffff00000000000000000001000000000000000000003d1606080c000000000000000000000000000000000000007f080000000000000040dd180050f2020101000003a4000027a4000042435e0062322f00dd0900037f01010000ff7fdd1300156d00010100010237e58106788a20867a5030140100000fac040100000fac040100000fac020000\nflags=[WPA2-PSK-CCMP][ESS]\nssid=TestLAN\nsnr=18\nest_throughput=48000\nupdate_idx=1\nbeacon_ie=0008426f7062654c414e010882848b968c1298240301060504010300002a01003204b048606c0b0504000a00002d1aac011bffffff00000000000000000001000000000000000000003d1606080c000000000000000000000000000000000000007f080000000000000040dd180050f2020101000003a4000027a4000042435e0062322f00dd0900037f01010000ff7fdd1300156d00010100010237e58106788a20867a5030140100000fac040100000fac040100000fac020000\n"
    })

    _supplicant =
      start_supervised!(
        {WPASupplicant,
         wpa_supplicant: "",
         wpa_supplicant_conf_path: "/dev/null",
         ifname: "test_wlan0",
         control_path: context.socket_path}
      )

    ap_property = ["interface", "test_wlan0", "wifi", "access_points"]
    VintageNet.PropertyTable.clear(VintageNet, ap_property)

    VintageNet.subscribe(ap_property)
    :ok = WPASupplicant.scan("test_wlan0")

    ap_list = [
      %VintageNet.WiFi.AccessPoint{
        band: :wifi_2_4_ghz,
        bssid: "78:8a:20:87:7a:50",
        channel: 6,
        flags: [:wpa2_psk_ccmp, :ess],
        frequency: 2437,
        signal_dbm: -71,
        signal_percent: 48,
        ssid: "TestLAN"
      }
    ]

    # Added
    assert_receive {VintageNet, ^ap_property, [], ^ap_list, _metadata}

    # Removed
    assert_receive {VintageNet, ^ap_property, ^ap_list, [], _metadata}
  end

  test "eap status is set", context do
    MockWPASupplicant.set_responses(context.mock, %{
      "ATTACH" => "OK\n",
      "PING" => "PONG\n",
      "BSS 78:8a:20:87:7a:50" =>
        "id=0\nbssid=78:8a:20:87:7a:50\nfreq=2437\nbeacon_int=100\ncapabilities=0x0431\nqual=0\nnoise=-89\nlevel=-71\ntsf=0000333220048880\nage=14\nie=0008426f7062654c414e010882848b968c1298240301062a01003204b048606c0b0504000a00002d1aac011bffffff00000000000000000001000000000000000000003d1606080c000000000000000000000000000000000000007f080000000000000040dd180050f2020101000003a4000027a4000042435e0062322f00dd0900037f01010000ff7fdd1300156d00010100010237e58106788a20867a5030140100000fac040100000fac040100000fac020000\nflags=[WPA-EAP-CCMP+TKIP][ESS]\nssid=TestLAN\nsnr=18\nest_throughput=48000\nupdate_idx=1\nbeacon_ie=0008426f7062654c414e010882848b968c1298240301060504010300002a01003204b048606c0b0504000a00002d1aac011bffffff00000000000000000001000000000000000000003d1606080c000000000000000000000000000000000000007f080000000000000040dd180050f2020101000003a4000027a4000042435e0062322f00dd0900037f01010000ff7fdd1300156d00010100010237e58106788a20867a5030140100000fac040100000fac040100000fac020000\n"
    })

    _supplicant =
      start_supervised!(
        {WPASupplicant,
         wpa_supplicant: "",
         wpa_supplicant_conf_path: "/dev/null",
         ifname: "test_wlan0",
         control_path: context.socket_path}
      )

    Process.sleep(100)

    eap_status_property = ["interface", "test_wlan0", "eap_status"]
    VintageNet.PropertyTable.clear(VintageNet, eap_status_property)
    VintageNet.subscribe(eap_status_property)

    :ok =
      MockWPASupplicant.send_message(
        context.mock,
        "<1>CTRL-EVENT-EAP-STATUS parameter=\"\" status=\"started\""
      )

    assert_receive {VintageNet, ^eap_status_property, nil, %{status: :started}, _}

    :ok =
      MockWPASupplicant.send_message(
        context.mock,
        "<2>CTRL-EVENT-EAP-STATUS parameter=\"PEAP\" status=\"accept proposed method\""
      )

    assert_receive {VintageNet, ^eap_status_property, _, %{method: "PEAP"}, _}

    :ok =
      MockWPASupplicant.send_message(
        context.mock,
        "<3>CTRL-EVENT-EAP-STATUS parameter=\"success\" status=\"remote certificate verification\""
      )

    assert_receive {VintageNet, ^eap_status_property, _, %{remote_certificate_verified?: true}, _}

    :ok =
      MockWPASupplicant.send_message(
        context.mock,
        "<3>CTRL-EVENT-EAP-STATUS parameter=\"failure\" status=\"remote certificate verification\""
      )

    assert_receive {VintageNet, ^eap_status_property, _, %{remote_certificate_verified?: false},
                    _}

    :ok =
      MockWPASupplicant.send_message(
        context.mock,
        "<3>CTRL-EVENT-EAP-STATUS parameter=\"failure\" status=\"completion\""
      )

    assert_receive {VintageNet, ^eap_status_property, _, %{status: :failure}, _}

    :ok =
      MockWPASupplicant.send_message(
        context.mock,
        "<3>CTRL-EVENT-EAP-STATUS parameter=\"success\" status=\"completion\""
      )

    assert_receive {VintageNet, ^eap_status_property, _, %{status: :success}, _}
  end

  test "current_ap property is set", context do
    MockWPASupplicant.set_responses(context.mock, %{
      "ATTACH" => "OK\n",
      "PING" => "PONG\n",
      "BSS 78:8a:20:87:7a:50" =>
        "id=0\nbssid=78:8a:20:87:7a:50\nfreq=2437\nbeacon_int=100\ncapabilities=0x0431\nqual=0\nnoise=-89\nlevel=-71\ntsf=0000333220048880\nage=14\nie=0008426f7062654c414e010882848b968c1298240301062a01003204b048606c0b0504000a00002d1aac011bffffff00000000000000000001000000000000000000003d1606080c000000000000000000000000000000000000007f080000000000000040dd180050f2020101000003a4000027a4000042435e0062322f00dd0900037f01010000ff7fdd1300156d00010100010237e58106788a20867a5030140100000fac040100000fac040100000fac020000\nflags=[WPA2-PSK-CCMP][ESS]\nssid=TestLAN\nsnr=18\nest_throughput=48000\nupdate_idx=1\nbeacon_ie=0008426f7062654c414e010882848b968c1298240301060504010300002a01003204b048606c0b0504000a00002d1aac011bffffff00000000000000000001000000000000000000003d1606080c000000000000000000000000000000000000007f080000000000000040dd180050f2020101000003a4000027a4000042435e0062322f00dd0900037f01010000ff7fdd1300156d00010100010237e58106788a20867a5030140100000fac040100000fac040100000fac020000\n"
    })

    _supplicant =
      start_supervised!(
        {WPASupplicant,
         wpa_supplicant: "",
         wpa_supplicant_conf_path: "/dev/null",
         ifname: "test_wlan0",
         control_path: context.socket_path}
      )

    Process.sleep(100)

    current_ap_property = ["interface", "test_wlan0", "wifi", "current_ap"]
    VintageNet.PropertyTable.clear(VintageNet, current_ap_property)
    VintageNet.subscribe(current_ap_property)

    ap = %VintageNet.WiFi.AccessPoint{
      band: :wifi_2_4_ghz,
      bssid: "78:8a:20:87:7a:50",
      channel: 6,
      flags: [:wpa2_psk_ccmp, :ess],
      frequency: 2437,
      signal_dbm: -71,
      signal_percent: 48,
      ssid: "TestLAN"
    }

    # Try connecting
    :ok =
      MockWPASupplicant.send_message(
        context.mock,
        "<1>CTRL-EVENT-CONNECTED - Connection to 78:8a:20:87:7a:50 completed (reauth) [id=0 id_str=]"
      )

    assert_receive {VintageNet, ^current_ap_property, nil, ^ap, _}

    # Try some weird status
    :ok =
      MockWPASupplicant.send_message(
        context.mock,
        "<1>CTRL-EVENT-CONNECTED - Connection to 78:8a:20:87:7a:50 other (reauth) [id=0 id_str=]"
      )

    assert_receive {VintageNet, ^current_ap_property, ^ap, nil, _}

    # Connect again
    :ok =
      MockWPASupplicant.send_message(
        context.mock,
        "<1>CTRL-EVENT-CONNECTED - Connection to 78:8a:20:87:7a:50 completed (reauth) [id=0 id_str=]"
      )

    assert_receive {VintageNet, ^current_ap_property, nil, ^ap, _}

    # Disconnect properly
    :ok =
      MockWPASupplicant.send_message(
        context.mock,
        "<1>CTRL-EVENT-DISCONNECTED bssid=78:8a:20:87:7a:50 reason=0 locally_generated=1"
      )

    assert_receive {VintageNet, ^current_ap_property, ^ap, nil, _}

    # Test race condition where AP connects and disconnects before we get around to
    # asking about it.
    :ok =
      MockWPASupplicant.send_message(
        context.mock,
        "<1>CTRL-EVENT-CONNECTED - Connection to 11:22:33:44:55:66 completed (reauth) [id=0 id_str=]"
      )

    refute_receive {VintageNet, ^current_ap_property, _, _, _}
  end
end
