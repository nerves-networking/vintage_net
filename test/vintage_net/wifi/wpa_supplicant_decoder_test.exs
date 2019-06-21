defmodule VintageNet.WiFi.WPASupplicantDecoderTest do
  use ExUnit.Case

  alias VintageNet.WiFi.WPASupplicantDecoder

  test "decodes kv responses" do
    # MIB requests
    assert WPASupplicantDecoder.decode_kv_response("""
           dot11RSNAOptionImplemented=TRUE
           dot11RSNAPreauthenticationImplemented=TRUE
           dot11RSNAEnabled=FALSE
           dot11RSNAPreauthenticationEnabled=FALSE
           dot11RSNAConfigVersion=1
           dot11RSNAConfigPairwiseKeysSupported=5
           dot11RSNAConfigGroupCipherSize=128
           dot11RSNAConfigPMKLifetime=43200
           dot11RSNAConfigPMKReauthThreshold=70
           dot11RSNAConfigNumberOfPTKSAReplayCounters=1
           dot11RSNAConfigSATimeout=60
           dot11RSNAAuthenticationSuiteSelected=00-50-f2-2
           dot11RSNAPairwiseCipherSelected=00-50-f2-4
           dot11RSNAGroupCipherSelected=00-50-f2-4
           dot11RSNAPMKIDUsed=
           dot11RSNAAuthenticationSuiteRequested=00-50-f2-2
           dot11RSNAPairwiseCipherRequested=00-50-f2-4
           dot11RSNAGroupCipherRequested=00-50-f2-4
           dot11RSNAConfigNumberOfGTKSAReplayCounters=0
           dot11RSNA4WayHandshakeFailures=0
           dot1xSuppPaeState=5
           dot1xSuppHeldPeriod=60
           dot1xSuppAuthPeriod=30
           dot1xSuppStartPeriod=30
           dot1xSuppMaxStart=3
           dot1xSuppSuppControlledPortStatus=Authorized
           dot1xSuppBackendPaeState=2
           dot1xSuppEapolFramesRx=0
           dot1xSuppEapolFramesTx=440
           dot1xSuppEapolStartFramesTx=2
           dot1xSuppEapolLogoffFramesTx=0
           dot1xSuppEapolRespFramesTx=0
           dot1xSuppEapolReqIdFramesRx=0
           dot1xSuppEapolReqFramesRx=0
           dot1xSuppInvalidEapolFramesRx=0
           dot1xSuppEapLengthErrorFramesRx=0
           dot1xSuppLastEapolFrameVersion=0
           dot1xSuppLastEapolFrameSource=00:00:00:00:00:00
           """) ==
             %{
               "dot11RSNAOptionImplemented" => "TRUE",
               "dot11RSNAPreauthenticationImplemented" => "TRUE",
               "dot11RSNAEnabled" => "FALSE",
               "dot11RSNAPreauthenticationEnabled" => "FALSE",
               "dot11RSNAConfigVersion" => "1",
               "dot11RSNAConfigPairwiseKeysSupported" => "5",
               "dot11RSNAConfigGroupCipherSize" => "128",
               "dot11RSNAConfigPMKLifetime" => "43200",
               "dot11RSNAConfigPMKReauthThreshold" => "70",
               "dot11RSNAConfigNumberOfPTKSAReplayCounters" => "1",
               "dot11RSNAConfigSATimeout" => "60",
               "dot11RSNAAuthenticationSuiteSelected" => "00-50-f2-2",
               "dot11RSNAPairwiseCipherSelected" => "00-50-f2-4",
               "dot11RSNAGroupCipherSelected" => "00-50-f2-4",
               "dot11RSNAPMKIDUsed" => "",
               "dot11RSNAAuthenticationSuiteRequested" => "00-50-f2-2",
               "dot11RSNAPairwiseCipherRequested" => "00-50-f2-4",
               "dot11RSNAGroupCipherRequested" => "00-50-f2-4",
               "dot11RSNAConfigNumberOfGTKSAReplayCounters" => "0",
               "dot11RSNA4WayHandshakeFailures" => "0",
               "dot1xSuppPaeState" => "5",
               "dot1xSuppHeldPeriod" => "60",
               "dot1xSuppAuthPeriod" => "30",
               "dot1xSuppStartPeriod" => "30",
               "dot1xSuppMaxStart" => "3",
               "dot1xSuppSuppControlledPortStatus" => "Authorized",
               "dot1xSuppBackendPaeState" => "2",
               "dot1xSuppEapolFramesRx" => "0",
               "dot1xSuppEapolFramesTx" => "440",
               "dot1xSuppEapolStartFramesTx" => "2",
               "dot1xSuppEapolLogoffFramesTx" => "0",
               "dot1xSuppEapolRespFramesTx" => "0",
               "dot1xSuppEapolReqIdFramesRx" => "0",
               "dot1xSuppEapolReqFramesRx" => "0",
               "dot1xSuppInvalidEapolFramesRx" => "0",
               "dot1xSuppEapLengthErrorFramesRx" => "0",
               "dot1xSuppLastEapolFrameVersion" => "0",
               "dot1xSuppLastEapolFrameSource" => "00:00:00:00:00:00"
             }

    # STATUS response
    assert WPASupplicantDecoder.decode_kv_response("""
           bssid=02:00:01:02:03:04
           ssid=test network
           pairwise_cipher=CCMP
           group_cipher=CCMP
           key_mgmt=WPA-PSK
           wpa_state=COMPLETED
           ip_address=192.168.1.21
           Supplicant PAE state=AUTHENTICATED
           suppPortStatus=Authorized
           EAP state=SUCCESS
           """) == %{
             "bssid" => "02:00:01:02:03:04",
             "ssid" => "test network",
             "pairwise_cipher" => "CCMP",
             "group_cipher" => "CCMP",
             "key_mgmt" => "WPA-PSK",
             "wpa_state" => "COMPLETED",
             "ip_address" => "192.168.1.21",
             "Supplicant PAE state" => "AUTHENTICATED",
             "suppPortStatus" => "Authorized",
             "EAP state" => "SUCCESS"
           }

    # STATUS-VERBOSE response
    assert WPASupplicantDecoder.decode_kv_response("""
           bssid=02:00:01:02:03:04
           ssid=test network
           id=0
           pairwise_cipher=CCMP
           group_cipher=CCMP
           key_mgmt=WPA-PSK
           wpa_state=COMPLETED
           ip_address=192.168.1.21
           Supplicant PAE state=AUTHENTICATED
           suppPortStatus=Authorized
           heldPeriod=60
           authPeriod=30
           startPeriod=30
           maxStart=3
           portControl=Auto
           Supplicant Backend state=IDLE
           EAP state=SUCCESS
           reqMethod=0
           methodState=NONE
           decision=COND_SUCC
           ClientTimeout=60
           """) == %{
             "bssid" => "02:00:01:02:03:04",
             "ssid" => "test network",
             "id" => "0",
             "pairwise_cipher" => "CCMP",
             "group_cipher" => "CCMP",
             "key_mgmt" => "WPA-PSK",
             "wpa_state" => "COMPLETED",
             "ip_address" => "192.168.1.21",
             "Supplicant PAE state" => "AUTHENTICATED",
             "suppPortStatus" => "Authorized",
             "heldPeriod" => "60",
             "authPeriod" => "30",
             "startPeriod" => "30",
             "maxStart" => "3",
             "portControl" => "Auto",
             "Supplicant Backend state" => "IDLE",
             "EAP state" => "SUCCESS",
             "reqMethod" => "0",
             "methodState" => "NONE",
             "decision" => "COND_SUCC",
             "ClientTimeout" => "60"
           }

    # BSS response
    assert WPASupplicantDecoder.decode_kv_response("""
           bssid=00:09:5b:95:e0:4e
           freq=2412
           beacon_int=0
           capabilities=0x0011
           qual=51
           noise=161
           level=212
           tsf=0000000000000000
           ie=000b6a6b6d2070726976617465010180dd180050f20101000050f20401000050f20401000050f2020000
           ssid=jkm private
           """) == %{
             "bssid" => "00:09:5b:95:e0:4e",
             "freq" => "2412",
             "beacon_int" => "0",
             "capabilities" => "0x0011",
             "qual" => "51",
             "noise" => "161",
             "level" => "212",
             "tsf" => "0000000000000000",
             "ie" =>
               "000b6a6b6d2070726976617465010180dd180050f20101000050f20401000050f20401000050f2020000",
             "ssid" => "jkm private"
           }

    # BSS response with a Unicode ssid
    assert WPASupplicantDecoder.decode_kv_response(
             "id=2\nbssid=e2:9a:d0:06:94:9c\nfreq=2412\nbeacon_int=100\ncapabilities=0x1511\nqual=0\nnoise=-89\nlevel=-45\ntsf=0000000007680407\nage=1\nie=0018f09f91bef09f91bef09f91bef09f91bef09f91bef09f91be010882848b962430486c0301010706555320010d1e200100230213002a010032040c12186030140100000fac040100000fac040100000fac020c002d1a2d0017ffff0000000000000000000000000000000000000000003d16010000000000000000000000000000000000000000007f080400000000000040dd0a0017f206010103010000dd0d0017f206020106c09ad001c70fdd090010180200001c0000dd180050f2020101800003a4000027a4000042435e0062322f00\nflags=[WPA2-PSK-CCMP][ESS]\nssid=\\xf0\\x9f\\x91\\xbe\\xf0\\x9f\\x91\\xbe\\xf0\\x9f\\x91\\xbe\\xf0\\x9f\\x91\\xbe\\xf0\\x9f\\x91\\xbe\\xf0\\x9f\\x91\\xbe\nsnr=44\nest_throughput=65000\nupdate_idx=7\nbeacon_ie=0018f09f91bef09f91bef09f91bef09f91bef09f91bef09f91be010882848b962430486c0301010504000300000706555320010d1e200100230213002a010032040c12186030140100000fac040100000fac040100000fac020c002d1a2d0017ffff0000000000000000000000000000000000000000003d16010000000000000000000000000000000000000000007f080400000000000040dd0a0017f206010103010000dd0d0017f206020106c09ad001c70fdd090010180200001c0000dd180050f2020101800003a4000027a4000042435e0062322f00\n"
           ) ==
             %{
               "bssid" => "e2:9a:d0:06:94:9c",
               "freq" => "2412",
               "beacon_int" => "100",
               "capabilities" => "0x1511",
               "qual" => "0",
               "noise" => "-89",
               "level" => "-45",
               "tsf" => "0000000007680407",
               "age" => "1",
               "flags" => "[WPA2-PSK-CCMP][ESS]",
               "ie" =>
                 "0018f09f91bef09f91bef09f91bef09f91bef09f91bef09f91be010882848b962430486c0301010706555320010d1e200100230213002a010032040c12186030140100000fac040100000fac040100000fac020c002d1a2d0017ffff0000000000000000000000000000000000000000003d16010000000000000000000000000000000000000000007f080400000000000040dd0a0017f206010103010000dd0d0017f206020106c09ad001c70fdd090010180200001c0000dd180050f2020101800003a4000027a4000042435e0062322f00",
               "snr" => "44",
               "est_throughput" => "65000",
               "update_idx" => "7",
               "beacon_ie" =>
                 "0018f09f91bef09f91bef09f91bef09f91bef09f91bef09f91be010882848b962430486c0301010504000300000706555320010d1e200100230213002a010032040c12186030140100000fac040100000fac040100000fac020c002d1a2d0017ffff0000000000000000000000000000000000000000003d16010000000000000000000000000000000000000000007f080400000000000040dd0a0017f206010103010000dd0d0017f206020106c09ad001c70fdd090010180200001c0000dd180050f2020101800003a4000027a4000042435e0062322f00",
               "ssid" => "👾👾👾👾👾👾",
               "id" => "2"
             }

    # Empty BSS response
    assert WPASupplicantDecoder.decode_kv_response("\n") == %{}
  end

  test "decodes interactive requests from the supplicant" do
    assert WPASupplicantDecoder.decode_notification("CTRL-REQ-IDENTITY-1-Human readable text") ==
             {:interactive, "CTRL-REQ-IDENTITY", 1, "Human readable text"}

    assert WPASupplicantDecoder.decode_notification("CTRL-REQ-PASSWORD-1-Human readable text") ==
             {:interactive, "CTRL-REQ-PASSWORD", 1, "Human readable text"}

    assert WPASupplicantDecoder.decode_notification("CTRL-REQ-NEW_PASSWORD-1-Human readable text") ==
             {:interactive, "CTRL-REQ-NEW_PASSWORD", 1, "Human readable text"}

    assert WPASupplicantDecoder.decode_notification("CTRL-REQ-PIN-1-Human readable text") ==
             {:interactive, "CTRL-REQ-PIN", 1, "Human readable text"}

    assert WPASupplicantDecoder.decode_notification("CTRL-REQ-OTP-1-Human readable text") ==
             {:interactive, "CTRL-REQ-OTP", 1, "Human readable text"}

    assert WPASupplicantDecoder.decode_notification("CTRL-REQ-PASSPHRASE-1-Human readable text") ==
             {:interactive, "CTRL-REQ-PASSPHRASE", 1, "Human readable text"}
  end

  test "decodes events" do
    assert WPASupplicantDecoder.decode_notification(
             "CTRL-EVENT-CONNECTED - Connection to ca:21:59:2b:d2:a9 completed [id=1 id_str=]"
           ) ==
             {:event, "CTRL-EVENT-CONNECTED", "ca:21:59:2b:d2:a9", "completed", %{"id" => "1"}}

    assert WPASupplicantDecoder.decode_notification(
             "CTRL-EVENT-DISCONNECTED bssid=ca:21:59:2b:d2:a9 reason=0 locally_generated=1"
           ) ==
             {:event, "CTRL-EVENT-DISCONNECTED", "ca:21:59:2b:d2:a9",
              %{"reason" => "0", "locally_generated" => "1"}}

    assert WPASupplicantDecoder.decode_notification("CTRL-EVENT-TERMINATING") ==
             {:event, "CTRL-EVENT-TERMINATING"}

    assert WPASupplicantDecoder.decode_notification(
             "CTRL-EVENT-SSID-TEMP-DISABLED id=1 ssid=\"FarmbotConnect\" auth_failures=1 duration=10 reason=CONN_FAILED"
           ) ==
             {:event, "CTRL-EVENT-SSID-TEMP-DISABLED",
              %{
                "id" => "1",
                "ssid" => "FarmbotConnect",
                "auth_failures" => "1",
                "duration" => "10",
                "reason" => "CONN_FAILED"
              }}

    assert WPASupplicantDecoder.decode_notification("CTRL-EVENT-PASSWORD-CHANGED") ==
             {:event, "CTRL-EVENT-PASSWORD-CHANGED"}

    assert WPASupplicantDecoder.decode_notification("CTRL-EVENT-EAP-NOTIFICATION") ==
             {:event, "CTRL-EVENT-EAP-NOTIFICATION"}

    assert WPASupplicantDecoder.decode_notification("CTRL-EVENT-EAP-STARTED") ==
             {:event, "CTRL-EVENT-EAP-STARTED"}

    assert WPASupplicantDecoder.decode_notification("CTRL-EVENT-EAP-SUCCESS") ==
             {:event, "CTRL-EVENT-EAP-SUCCESS"}

    eap_notif = """
    CTRL-EVENT-EAP-PEER-CERT depth=0 subject='/CN=redacted.local' cert=2a93f2000ca300d06096056c6f63616c31143012060a0a47c86745000047265796e312a302806035504031321456e746572c64011916091308205743082045ca0030201013060a099226899320200110002707269736520526f6f7420434120666f72207265796e2e6c6f63616c301e170d3138303330323135323531315a170d3139303330323135323531315a3020311e301c060355040313156e70732d7374616666312e7265796e2e6c6f63616c30820122300d06092a864886f70d01010105000382010f003082010a0282010100a8b610fdced6989e72f4b45f2c7c18d0a6e9efe494faed1a106076eef430ac64a43533cfacf5c052607d33c84aa714fed3350828ad0db3df86566033a12dd19c8c3740f70abad5604cd851fea23f7b46badba151c0166b8f33d4abc6c921209f759f3ff0a0eeb48b96487f3e5b5f37ce9f2c73788b5877bf9b2720e75736257aaaa7032178edf0f4604fe476b29dbdab27944121078357ea8e7f8d6a0f28748cb49a78ce28c139ffbeb067696f25a455ca5562e0ccf744d1b4e1e9a3240094d26d5c4980eccb44bef50d84aab25090926ddacc0e8f0fbc60fbf9e25eb0cf394812f089adac4f53a5551527f1b698c21827bfdaca022748ca8287425f55f228cb0203010001a382027530820271301d06092b060104018237140204101e0e004d0061006300680069006e0065301d0603551d25041630140608864886f70d01010505003059311530f22c6499226892b0601050507030206082b06010505070301300e0603551d0f0101ff0404030205a0301d0603551d0e041604144123c436c86a7e24dd63a787cf28118d6eb6b364301f0603551d2304183016801499f022b1dca093df17ff465941fcf54ce8c82c7f3081e10603551d1f0481d93081d63081d3a081d0a081cd8681ca6c6461703a2f2f2f434e3d456e7465727072697365253230526f6f742532304341253230666f722532307265796e2e6c6f63616c2c434e3d63612c434e3d4344502c434e3d5075626c69632532304b657925323053657276696365732c434e3d53657276696365732c434e3d436f6e66696775726174696f6e2c44433d7265796e2c44433d6c6f63616c3f63657274696669636174655265766f636174696f6e4c6973743f626173653f6f626a656374436c6173733d63524c446973747269627574696f6e506f696e743081da06082b060105050701010481cd3081ca3081c706082b060105050730028681ba6c6461703a2f2f2f434e3d456e7465727072697365253230526f6f742532304341253230666f722532307265796e2e6c6f63616c2c434e3d4149412c434e3d5075626c69632532304b65792532305365727
    """

    assert WPASupplicantDecoder.decode_notification(eap_notif) ==
             {:event, "CTRL-EVENT-EAP-PEER-CERT",
              %{
                "depth" => "0",
                "subject" => "/CN=redacted.local",
                "cert" =>
                  "2a93f2000ca300d06096056c6f63616c31143012060a0a47c86745000047265796e312a302806035504031321456e746572c64011916091308205743082045ca0030201013060a099226899320200110002707269736520526f6f7420434120666f72207265796e2e6c6f63616c301e170d3138303330323135323531315a170d3139303330323135323531315a3020311e301c060355040313156e70732d7374616666312e7265796e2e6c6f63616c30820122300d06092a864886f70d01010105000382010f003082010a0282010100a8b610fdced6989e72f4b45f2c7c18d0a6e9efe494faed1a106076eef430ac64a43533cfacf5c052607d33c84aa714fed3350828ad0db3df86566033a12dd19c8c3740f70abad5604cd851fea23f7b46badba151c0166b8f33d4abc6c921209f759f3ff0a0eeb48b96487f3e5b5f37ce9f2c73788b5877bf9b2720e75736257aaaa7032178edf0f4604fe476b29dbdab27944121078357ea8e7f8d6a0f28748cb49a78ce28c139ffbeb067696f25a455ca5562e0ccf744d1b4e1e9a3240094d26d5c4980eccb44bef50d84aab25090926ddacc0e8f0fbc60fbf9e25eb0cf394812f089adac4f53a5551527f1b698c21827bfdaca022748ca8287425f55f228cb0203010001a382027530820271301d06092b060104018237140204101e0e004d0061006300680069006e0065301d0603551d25041630140608864886f70d01010505003059311530f22c6499226892b0601050507030206082b06010505070301300e0603551d0f0101ff0404030205a0301d0603551d0e041604144123c436c86a7e24dd63a787cf28118d6eb6b364301f0603551d2304183016801499f022b1dca093df17ff465941fcf54ce8c82c7f3081e10603551d1f0481d93081d63081d3a081d0a081cd8681ca6c6461703a2f2f2f434e3d456e7465727072697365253230526f6f742532304341253230666f722532307265796e2e6c6f63616c2c434e3d63612c434e3d4344502c434e3d5075626c69632532304b657925323053657276696365732c434e3d53657276696365732c434e3d436f6e66696775726174696f6e2c44433d7265796e2c44433d6c6f63616c3f63657274696669636174655265766f636174696f6e4c6973743f626173653f6f626a656374436c6173733d63524c446973747269627574696f6e506f696e743081da06082b060105050701010481cd3081ca3081c706082b060105050730028681ba6c6461703a2f2f2f434e3d456e7465727072697365253230526f6f742532304341253230666f722532307265796e2e6c6f63616c2c434e3d4149412c434e3d5075626c69632532304b65792532305365727"
              }}

    assert WPASupplicantDecoder.decode_notification(
             "CTRL-EVENT-EAP-PEER-CERT depth=0 subject='/CN=staff.redacted.local' hash=a05eb2dd610feb5c77e910eb2af6b14a28fa62e6f0ca15af371a0f95b65f4f0e"
           ) == {
             :event,
             "CTRL-EVENT-EAP-PEER-CERT",
             %{
               "depth" => "0",
               "subject" => "/CN=staff.redacted.local",
               "hash" => "a05eb2dd610feb5c77e910eb2af6b14a28fa62e6f0ca15af371a0f95b65f4f0e"
             }
           }

    assert WPASupplicantDecoder.decode_notification(
             "CTRL-EVENT-EAP-STATUS status='completion' parameter='failure'"
           ) ==
             {
               :event,
               "CTRL-EVENT-EAP-STATUS",
               %{"status" => "completion", "parameter" => "failure"}
             }

    assert WPASupplicantDecoder.decode_notification(
             "CTRL-EVENT-EAP-STATUS status='started' parameter=''"
           ) == {
             :event,
             "CTRL-EVENT-EAP-STATUS",
             %{"status" => "started", "parameter" => ""}
           }

    assert WPASupplicantDecoder.decode_notification(
             "CTRL-EVENT-EAP-STATUS status='accept proposed method' parameter='PEAP'"
           ) == {
             :event,
             "CTRL-EVENT-EAP-STATUS",
             %{"status" => "accept proposed method", "parameter" => "PEAP"}
           }

    assert WPASupplicantDecoder.decode_notification(
             "CTRL-EVENT-EAP-FAILURE EAP authentication failed"
           ) == {
             :event,
             "CTRL-EVENT-EAP-FAILURE",
             "EAP authentication failed"
           }

    assert WPASupplicantDecoder.decode_notification(
             "CTRL-EVENT-EAP-METHOD EAP vendor 0 method 25 (PEAP) selected"
           ) ==
             {
               :event,
               "CTRL-EVENT-EAP-METHOD",
               "EAP vendor 0 method 25 (PEAP) selected"
             }

    assert(
      WPASupplicantDecoder.decode_notification(
        "CTRL-EVENT-EAP-PROPOSED-METHOD vendor=0 method=25"
      ) ==
        {
          :event,
          "CTRL-EVENT-EAP-PROPOSED-METHOD",
          %{"vendor" => "0", "method" => "25"}
        }
    )

    assert WPASupplicantDecoder.decode_notification("CTRL-EVENT-SCAN-RESULTS") ==
             {:event, "CTRL-EVENT-SCAN-RESULTS"}

    assert WPASupplicantDecoder.decode_notification("CTRL-EVENT-BSS-ADDED 34 00:11:22:33:44:55") ==
             {:event, "CTRL-EVENT-BSS-ADDED", 34, "00:11:22:33:44:55"}

    assert WPASupplicantDecoder.decode_notification("CTRL-EVENT-BSS-REMOVED 34 00:11:22:33:44:55") ==
             {:event, "CTRL-EVENT-BSS-REMOVED", 34, "00:11:22:33:44:55"}

    assert WPASupplicantDecoder.decode_notification("WPS-OVERLAP-DETECTED") ==
             {:event, "WPS-OVERLAP-DETECTED"}

    assert WPASupplicantDecoder.decode_notification("WPS-AP-AVAILABLE-PBC") ==
             {:event, "WPS-AP-AVAILABLE-PBC"}

    assert WPASupplicantDecoder.decode_notification("WPS-AP-AVAILABLE-PIN") ==
             {:event, "WPS-AP-AVAILABLE-PIN"}

    assert WPASupplicantDecoder.decode_notification("WPS-AP-AVAILABLE") ==
             {:event, "WPS-AP-AVAILABLE"}

    assert WPASupplicantDecoder.decode_notification("WPS-CRED-RECEIVED") ==
             {:event, "WPS-CRED-RECEIVED"}

    assert WPASupplicantDecoder.decode_notification("WPS-M2D") == {:event, "WPS-M2D"}
    assert WPASupplicantDecoder.decode_notification("WPS-FAIL") == {:event, "WPS-FAIL"}
    assert WPASupplicantDecoder.decode_notification("WPS-SUCCESS") == {:event, "WPS-SUCCESS"}
    assert WPASupplicantDecoder.decode_notification("WPS-TIMEOUT") == {:event, "WPS-TIMEOUT"}

    # assert WPASupplicantDecoder.decode_notification("WPS-ENROLLEE-SEEN 02:00:00:00:01:00\n572cf82f-c957-5653-9b16-b5cfb298abf1 1-0050F204-1 0x80 4 1\n[Wireless Client]") ==
    #                                      {:'WPS-ENROLLEE-SEEN', "02:00:00:00:01:00", "572cf82f-c957-5653-9b16-b5cfb298abf1", "1-0050F204-1", 0x80, 4, 1, "[Wireless Client]"}

    # assert WPASupplicantDecoder.decode_notification("WPS-ER-AP-ADD 87654321-9abc-def0-1234-56789abc0002 02:11:22:33:44:55\npri_dev_type=6-0050F204-1 wps_state=1 |Very friendly name|Company|\nLong description of the model|WAP|http://w1.fi/|http://w1.fi/hostapd/") ==
    #                                     {:'WPS-ER-AP-ADD', "87654321-9abc-def0-1234-56789abc0002", "02:11:22:33:44:55", "pri_dev_type=6-0050F204-1 wps_state=1", "Very friendly name", "Company", "Long description of the model", "WAP",  "http://w1.fi/", "http://w1.fi/hostapd/"}

    # assert WPASupplicantDecoder.decode_notification("WPS-ER-AP-REMOVE 87654321-9abc-def0-1234-56789abc0002") ==
    #                                      {:'WPS-ER-AP-ADD', "87654321-9abc-def0-1234-56789abc0002"}

    # WPS-ER-ENROLLEE-ADD 2b7093f1-d6fb-5108-adbb-bea66bb87333
    # 02:66:a0:ee:17:27 M1=1 config_methods=0x14d dev_passwd_id=0
    # pri_dev_type=1-0050F204-1
    # |Wireless Client|Company|cmodel|123|12345|

    # WPS-ER-ENROLLEE-REMOVE 2b7093f1-d6fb-5108-adbb-bea66bb87333
    # 02:66:a0:ee:17:27

    # WPS-PIN-NEEDED 5a02a5fa-9199-5e7c-bc46-e183d3cb32f7 02:2a:c4:18:5b:f3
    # [Wireless Client|Company|cmodel|123|12345|1-0050F204-1]

    assert WPASupplicantDecoder.decode_notification("WPS-NEW-AP-SETTINGS") ==
             {:event, "WPS-NEW-AP-SETTINGS"}

    assert WPASupplicantDecoder.decode_notification("WPS-REG-SUCCESS") ==
             {:event, "WPS-REG-SUCCESS"}

    assert WPASupplicantDecoder.decode_notification("WPS-AP-SETUP-LOCKED") ==
             {:event, "WPS-AP-SETUP-LOCKED"}

    assert WPASupplicantDecoder.decode_notification("AP-STA-CONNECTED 02:2a:c4:18:5b:f3") ==
             {:event, "AP-STA-CONNECTED", "02:2a:c4:18:5b:f3"}

    assert WPASupplicantDecoder.decode_notification("AP-STA-DISCONNECTED 02:2a:c4:18:5b:f3") ==
             {:event, "AP-STA-DISCONNECTED", "02:2a:c4:18:5b:f3"}

    # P2P-DEVICE-FOUND 02:b5:64:63:30:63 p2p_dev_addr=02:b5:64:63:30:63
    # pri_dev_type=1-0050f204-1 name='Wireless Client' config_methods=0x84
    # dev_capab=0x21 group_capab=0x0

    # P2P-GO-NEG-REQUEST 02:40:61:c2:f3:b7 dev_passwd_id=4
    # P2P-GO-NEG-SUCCESS
    # P2P-GO-NEG-FAILURE
    # P2P-GROUP-FORMATION-SUCCESS
    # P2P-GROUP-FORMATION-FAILURE
    # P2P-GROUP-STARTED
    # P2P-GROUP-STARTED wlan0-p2p-0 GO ssid="DIRECT-3F Testing"
    # passphrase="12345678" go_dev_addr=02:40:61:c2:f3:b7 [PERSISTENT]
    # P2P-GROUP-REMOVED wlan0-p2p-0 GO
    # P2P-PROV-DISC-SHOW-PIN 02:40:61:c2:f3:b7 12345670
    # p2p_dev_addr=02:40:61:c2:f3:b7 pri_dev_type=1-0050F204-1 name='Test'
    # config_methods=0x188 dev_capab=0x21 group_capab=0x0
    # P2P-PROV-DISC-ENTER-PIN 02:40:61:c2:f3:b7 p2p_dev_addr=02:40:61:c2:f3:b7
    # pri_dev_type=1-0050F204-1 name='Test' config_methods=0x188
    # dev_capab=0x21 group_capab=0x0
    # P2P-PROV-DISC-PBC-REQ 02:40:61:c2:f3:b7 p2p_dev_addr=02:40:61:c2:f3:b7
    # pri_dev_type=1-0050F204-1 name='Test' config_methods=0x188
    # dev_capab=0x21 group_capab=0x0
    # P2P-PROV-DISC-PBC-RESP 02:40:61:c2:f3:b7
    # P2P-SERV-DISC-REQ 2412 02:40:61:c2:f3:b7 0 0 02000001
    # P2P-SERV-DISC-RESP 02:40:61:c2:f3:b7 0 0300000101
    # P2P-INVITATION-RECEIVED sa=02:40:61:c2:f3:b7 persistent=0
    # P2P-INVITATION-RESULT status=1

    assert WPASupplicantDecoder.decode_notification(
             "Trying to associate with 58:6d:8f:8d:c8:92 (SSID='LKC Tech HQ' freq=2412 MHz)"
           ) ==
             {:info,
              "Trying to associate with 58:6d:8f:8d:c8:92 (SSID='LKC Tech HQ' freq=2412 MHz)"}
  end

  test "flag parsing" do
    assert [:wpa2_psk_ccmp, :ess] = WPASupplicantDecoder.parse_flags("[WPA2-PSK-CCMP][ESS]")
    assert [:wpa2_eap_ccmp, :ess] = WPASupplicantDecoder.parse_flags("[WPA2-EAP-CCMP][ESS]")
    assert [:rsn_ccmp, :mesh] = WPASupplicantDecoder.parse_flags("[RSN--CCMP][MESH]")
    assert [:ibss] = WPASupplicantDecoder.parse_flags("[IBSS]")

    assert [:wpa2_psk_ccmp_tkip, :wps] =
             WPASupplicantDecoder.parse_flags("[WPA2-PSK-CCMP+TKIP][WPS]")

    assert [] = WPASupplicantDecoder.parse_flags("[something random]")
  end
end
