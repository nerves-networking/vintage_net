defmodule VintageNet.Technology.WiFiTest do
  use ExUnit.Case
  alias VintageNet.Interface.RawConfig
  alias VintageNet.Technology.WiFi

  import VintageNetTest.Utils
  import ExUnit.CaptureLog

  test "normalizes old way of specifying ssid" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{ssid: "guest", key_mgmt: :none}
    }

    normalized_input = %{
      type: VintageNet.Technology.WiFi,
      ipv4: %{method: :dhcp},
      wifi: %{
        networks: [
          %{
            ssid: "guest",
            key_mgmt: :none,
            mode: :infrastructure
          }
        ]
      }
    }

    assert capture_log(fn ->
             assert normalized_input == WiFi.normalize(input)
           end) =~ "deprecated"
  end

  test "normalizes old way of specifying ap mode" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{mode: :host, ssid: "my_ap", key_mgmt: :none}
    }

    normalized_input = %{
      type: VintageNet.Technology.WiFi,
      ipv4: %{method: :dhcp},
      wifi: %{
        networks: [
          %{
            ssid: "my_ap",
            key_mgmt: :none,
            mode: :ap
          }
        ]
      }
    }

    assert capture_log(fn ->
             assert normalized_input == WiFi.normalize(input)
           end) =~ "deprecated"
  end

  test "normalizes old way of specifying infrastructure mode" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            ssid: "guest",
            key_mgmt: :none,
            mode: :client
          }
        ]
      }
    }

    normalized_input = %{
      type: VintageNet.Technology.WiFi,
      ipv4: %{method: :dhcp},
      wifi: %{
        networks: [
          %{
            ssid: "guest",
            key_mgmt: :none,
            mode: :infrastructure
          }
        ]
      }
    }

    assert normalized_input == WiFi.normalize(input)
  end

  test "normalizing an empty config works" do
    # An empty config should be normalized to a configuration that
    # allows the user to scan for networks.
    input = %{
      type: VintageNet.Technology.WiFi
    }

    normalized = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{networks: []},
      ipv4: %{method: :disabled}
    }

    assert normalized == WiFi.normalize(input)
  end

  test "an empty config enables wifi scanning" do
    input = %{
      type: VintageNet.Technology.WiFi
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "verbose flag turns on wpa_supplicant debug" do
    input = %{
      type: VintageNet.Technology.WiFi,
      verbose: true
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: true
         ]}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "normalization converts passphrases to PSKs" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [%{ssid: "IEEE", psk: "password", key_mgmt: :wpa_psk}]
      }
    }

    normalized_input = %{
      type: VintageNet.Technology.WiFi,
      ipv4: %{method: :dhcp},
      wifi: %{
        networks: [
          %{
            ssid: "IEEE",
            psk: "F42C6FC52DF0EBEF9EBB4B90B38A5F902E83FE1B135A70E23AED762E9710A12E",
            key_mgmt: :wpa_psk,
            mode: :infrastructure
          }
        ]
      }
    }

    assert normalized_input == WiFi.normalize(input)
  end

  test "normalization converts passphrases to psks for multiple networks" do
    input = %{
      type: VintageNet.Technology.WiFi,
      ipv4: %{method: :dhcp},
      wifi: %{
        networks: [
          %{
            ssid: "IEEE",
            psk: "password",
            key_mgmt: :wpa_psk
          },
          %{
            ssid: "IEEE2",
            psk: "password",
            key_mgmt: :wpa_psk
          }
        ]
      }
    }

    normalized_input = %{
      type: VintageNet.Technology.WiFi,
      ipv4: %{method: :dhcp},
      wifi: %{
        networks: [
          %{
            ssid: "IEEE",
            psk: "F42C6FC52DF0EBEF9EBB4B90B38A5F902E83FE1B135A70E23AED762E9710A12E",
            key_mgmt: :wpa_psk,
            mode: :infrastructure
          },
          %{
            ssid: "IEEE2",
            psk: "B06433395BD30B1455F538904B239D10A51964932A81D1407BAF2BA0767E22E9",
            key_mgmt: :wpa_psk,
            mode: :infrastructure
          }
        ]
      }
    }

    assert normalized_input == WiFi.normalize(input)
  end

  test "create a WPA2 WiFi configuration" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            ssid: "testing",
            psk: "1234567890123456789012345678901234567890123456789012345678901234",
            key_mgmt: :wpa_psk
          }
        ]
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        udhcpc_child_spec("wlan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="testing"
         key_mgmt=WPA-PSK
         mode=0
         psk=1234567890123456789012345678901234567890123456789012345678901234
         }
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "create an open WiFi configuration" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            ssid: "guest"
          }
        ]
      },
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        udhcpc_child_spec("wlan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="guest"
         key_mgmt=NONE
         mode=0
         }
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "Set regulatory_domain at runtime" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        regulatory_domain: "AU"
      },
      ipv4: %{method: :disabled},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=AU
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "create a WPA2 WiFi configuration with passphrase" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [%{ssid: "testing", psk: "a_passphrase_and_not_a_psk", key_mgmt: :wpa_psk}]
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        udhcpc_child_spec("wlan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="testing"
         key_mgmt=WPA-PSK
         mode=0
         psk=1EE0A473A954F61007E526365D4FDC056FE2A102ED2CE77D64492A9495B83030
         }
         """}
      ],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "create a password-less WiFi configuration" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{networks: [%{ssid: "testing", key_mgmt: :none}]},
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        udhcpc_child_spec("wlan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="testing"
         key_mgmt=NONE
         mode=0
         }
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "create a WEP WiFi configuration" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            ssid: "testing",
            bssid: "00:11:22:33:44:55",
            wep_key0: "42FEEDDEAFBABEDEAFBEEFAA55",
            wep_key1: "42FEEDDEAFBABEDEAFBEEFAA55",
            wep_key2: "ABEDEA42FFBEEFAA55EEDDEAFB",
            wep_key3: "EDEADEAFBABFBEEFAA5542FEED",
            key_mgmt: :none,
            wep_tx_keyidx: 0
          }
        ]
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        udhcpc_child_spec("wlan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="testing"
         bssid=00:11:22:33:44:55
         key_mgmt=NONE
         mode=0
         wep_key0=42FEEDDEAFBABEDEAFBEEFAA55
         wep_key1=42FEEDDEAFBABEDEAFBEEFAA55
         wep_key2=ABEDEA42FFBEEFAA55EEDDEAFB
         wep_key3=EDEADEAFBABFBEEFAA5542FEED
         wep_tx_keyidx=0
         }
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "create a hidden WiFi configuration" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            ssid: "testing",
            psk: "1234567890123456789012345678901234567890123456789012345678901234",
            key_mgmt: :wpa_psk,
            scan_ssid: 1
          }
        ]
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        udhcpc_child_spec("wlan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="testing"
         key_mgmt=WPA-PSK
         scan_ssid=1
         mode=0
         psk=1234567890123456789012345678901234567890123456789012345678901234
         }
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "create a basic EAP network" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            ssid: "testing",
            key_mgmt: :wpa_eap,
            scan_ssid: 1,
            pairwise: "CCMP TKIP",
            group: "CCMP TKIP",
            eap: "PEAP",
            identity: "user1",
            password: "supersecret",
            phase1: "peapver=auto",
            phase2: "MSCHAPV2"
          }
        ]
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        udhcpc_child_spec("wlan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="testing"
         key_mgmt=WPA-EAP
         scan_ssid=1
         mode=0
         identity="user1"
         password="supersecret"
         pairwise=CCMP TKIP
         group=CCMP TKIP
         eap=PEAP
         phase1="peapver=auto"
         phase2="MSCHAPV2"
         }
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "WPA-Personal(PSK) with TKIP and enforcement for frequent PTK rekeying" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            ssid: "example",
            proto: "WPA",
            key_mgmt: :wpa_psk,
            scan_ssid: 1,
            pairwise: "TKIP",
            psk: "not so secure passphrase",
            wpa_ptk_rekey: 600
          }
        ]
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        udhcpc_child_spec("wlan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="example"
         key_mgmt=WPA-PSK
         scan_ssid=1
         mode=0
         psk=F7C00EB4F1A1BF28F0C6D18C689DB6634FC85C894286A11DE979F2BA1C022988
         wpa_ptk_rekey=600
         pairwise=TKIP
         }
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "Only WPA-EAP is used. Both CCMP and TKIP is accepted" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            ssid: "example",
            proto: "RSN",
            key_mgmt: :wpa_eap,
            pairwise: "CCMP TKIP",
            eap: "TLS",
            identity: "user@example.com",
            ca_cert: "/etc/cert/ca.pem",
            client_cert: "/etc/cert/user.pem",
            private_key: "/etc/cert/user.prv",
            private_key_passwd: "password",
            priority: 1
          }
        ]
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        udhcpc_child_spec("wlan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="example"
         key_mgmt=WPA-EAP
         priority=1
         mode=0
         identity="user@example.com"
         pairwise=CCMP TKIP
         eap=TLS
         ca_cert="/etc/cert/ca.pem"
         client_cert="/etc/cert/user.pem"
         private_key="/etc/cert/user.prv"
         private_key_passwd="password"
         }
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "EAP-PEAP/MSCHAPv2 configuration for RADIUS servers that use the new peaplabel" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            ssid: "example",
            key_mgmt: :wpa_eap,
            eap: "PEAP",
            identity: "user@example.com",
            password: "foobar",
            ca_cert: "/etc/cert/ca.pem",
            phase1: "peaplabel=1",
            phase2: "auth=MSCHAPV2",
            priority: 10
          }
        ]
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        udhcpc_child_spec("wlan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="example"
         key_mgmt=WPA-EAP
         priority=10
         mode=0
         identity="user@example.com"
         password="foobar"
         eap=PEAP
         phase1="peaplabel=1"
         phase2="auth=MSCHAPV2"
         ca_cert="/etc/cert/ca.pem"
         }
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "EAP-TTLS/EAP-MD5-Challenge configuration with anonymous identity" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            ssid: "example",
            key_mgmt: :wpa_eap,
            eap: "TTLS",
            identity: "user@example.com",
            anonymous_identity: "anonymous@example.com",
            password: "foobar",
            ca_cert: "/etc/cert/ca.pem",
            priority: 2
          }
        ]
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        udhcpc_child_spec("wlan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="example"
         key_mgmt=WPA-EAP
         priority=2
         mode=0
         identity="user@example.com"
         anonymous_identity="anonymous@example.com"
         password="foobar"
         eap=TTLS
         ca_cert="/etc/cert/ca.pem"
         }
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "WPA-EAP, EAP-TTLS with different CA certificate used for outer and inner authentication" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            ssid: "example",
            key_mgmt: :wpa_eap,
            eap: "TTLS",
            anonymous_identity: "anonymous@example.com",
            ca_cert: "/etc/cert/ca.pem",
            phase2: "autheap=TLS",
            ca_cert2: "/etc/cert/ca2.pem",
            client_cert2: "/etc/cer/user.pem",
            private_key2: "/etc/cer/user.prv",
            private_key2_passwd: "password",
            priority: 2
          }
        ]
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        udhcpc_child_spec("wlan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="example"
         key_mgmt=WPA-EAP
         priority=2
         mode=0
         anonymous_identity="anonymous@example.com"
         eap=TTLS
         phase2="autheap=TLS"
         ca_cert="/etc/cert/ca.pem"
         ca_cert2="/etc/cert/ca2.pem"
         client_cert2="/etc/cer/user.pem"
         private_key2="/etc/cer/user.prv"
         private_key2_passwd="password"
         }
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "EAP-SIM with a GSM SIM or USIM" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [%{ssid: "eap-sim-test", key_mgmt: :wpa_eap, eap: "SIM", pin: "1234", pcsc: ""}]
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        udhcpc_child_spec("wlan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="eap-sim-test"
         key_mgmt=WPA-EAP
         mode=0
         eap=SIM
         pin="1234"
         pcsc=""
         }
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "EAP PSK" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            ssid: "eap-psk-test",
            key_mgmt: :wpa_eap,
            eap: "PSK",
            anonymous_identity: "eap_psk_user",
            password: "06b4be19da289f475aa46a33cb793029",
            identity: "eap_psk_user@example.com"
          }
        ]
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        udhcpc_child_spec("wlan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="eap-psk-test"
         key_mgmt=WPA-EAP
         mode=0
         identity="eap_psk_user@example.com"
         anonymous_identity="eap_psk_user"
         password="06b4be19da289f475aa46a33cb793029"
         eap=PSK
         }
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "IEEE 802.1X/EAPOL with dynamically generated WEP keys" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            ssid: "1x-test",
            key_mgmt: :IEEE8021X,
            eap: "TLS",
            identity: "user@example.com",
            ca_cert: "/etc/cert/ca.pem",
            client_cert: "/etc/cert/user.pem",
            private_key: "/etc/cert/user.prv",
            private_key_passwd: "password",
            eapol_flags: 3
          }
        ]
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        udhcpc_child_spec("wlan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="1x-test"
         key_mgmt=IEEE8021X
         mode=0
         identity="user@example.com"
         eap=TLS
         eapol_flags=3
         ca_cert="/etc/cert/ca.pem"
         client_cert="/etc/cert/user.pem"
         private_key="/etc/cert/user.prv"
         private_key_passwd="password"
         }
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "configuration blacklisting two APs" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            ssid: "example",
            key_mgmt: :wpa_psk,
            psk: "very secret passphrase",
            bssid_blacklist: "02:11:22:33:44:55 02:22:aa:44:55:66"
          }
        ]
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        udhcpc_child_spec("wlan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="example"
         key_mgmt=WPA-PSK
         bssid_blacklist=02:11:22:33:44:55 02:22:aa:44:55:66
         mode=0
         psk=3033345C1478F89E4BE9C4937401DEAFD58808CD3E63568DCBFBBD4A8D281175
         }
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "configuration limiting AP selection to a specific set of APs" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            ssid: "example",
            key_mgmt: :wpa_psk,
            psk: "very secret passphrase",
            bssid_whitelist:
              "02:55:ae:bc:00:00/ff:ff:ff:ff:00:00 00:00:77:66:55:44/00:00:ff:ff:ff:ff"
          }
        ]
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        udhcpc_child_spec("wlan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="example"
         key_mgmt=WPA-PSK
         bssid_whitelist=02:55:ae:bc:00:00/ff:ff:ff:ff:00:00 00:00:77:66:55:44/00:00:ff:ff:ff:ff
         mode=0
         psk=3033345C1478F89E4BE9C4937401DEAFD58808CD3E63568DCBFBBD4A8D281175
         }
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "host AP mode" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{mode: :ap, ssid: "example ap", psk: "very secret passphrase", key_mgmt: :wpa_psk}
        ]
      },
      ipv4: %{method: :disabled},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: true,
           verbose: false
         ]}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="example ap"
         key_mgmt=WPA-PSK
         mode=2
         psk=94A7360596213CEB96007A25A63FCBCF4D540314CEB636353C62A86632A6BD6E
         }
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: [
        "/tmp/vintage_net/wpa_supplicant/p2p-dev-wlan0",
        "/tmp/vintage_net/wpa_supplicant/wlan0"
      ]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "create a multi-network WiFi configuration" do
    # All of the IPv4 settings need to be the same for this configuration. This is
    # probably "good enough". `nerves_network` does better, though.
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            ssid: "first_priority",
            psk: "1234567890123456789012345678901234567890123456789012345678901234",
            key_mgmt: :wpa_psk,
            priority: 100
          },
          %{
            ssid: "second_priority",
            psk: "1234567890123456789012345678901234567890123456789012345678901234",
            key_mgmt: :wpa_psk,
            priority: 1
          },
          %{
            ssid: "third_priority",
            key_mgmt: :none,
            priority: 0
          }
        ]
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        udhcpc_child_spec("wlan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="first_priority"
         key_mgmt=WPA-PSK
         priority=100
         mode=0
         psk=1234567890123456789012345678901234567890123456789012345678901234
         }
         network={
         ssid="second_priority"
         key_mgmt=WPA-PSK
         priority=1
         mode=0
         psk=1234567890123456789012345678901234567890123456789012345678901234
         }
         network={
         ssid="third_priority"
         key_mgmt=NONE
         priority=0
         mode=0
         }
         """}
      ],
      up_cmds: [{:run, "ip", ["link", "set", "wlan0", "up"]}],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "creates a static ip config" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [%{ssid: "example ap", psk: "very secret passphrase", key_mgmt: :wpa_psk}]
      },
      ipv4: %{
        method: :static,
        address: "192.168.1.2",
        netmask: "255.255.0.0",
        gateway: "192.168.1.1"
      },
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: false,
           verbose: false
         ]},
        {VintageNet.Interface.InternetConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="example ap"
         key_mgmt=WPA-PSK
         mode=0
         psk=94A7360596213CEB96007A25A63FCBCF4D540314CEB636353C62A86632A6BD6E
         }
         """}
      ],
      up_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["addr", "add", "192.168.1.2/16", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "up"]},
        {:fun, VintageNet.RouteManager, :set_route,
         ["wlan0", [{{192, 168, 1, 2}, 16}], {192, 168, 1, 1}, :lan]},
        {:fun, VintageNet.NameResolver, :clear, ["wlan0"]}
      ],
      down_cmds: [
        {:fun, VintageNet.RouteManager, :clear_route, ["wlan0"]},
        {:fun, VintageNet.NameResolver, :clear, ["wlan0"]},
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "create an AP running dhcpd config" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            mode: :ap,
            ssid: "example ap",
            key_mgmt: :none,
            scan_ssid: 1
          }
        ],
        ap_scan: 1,
        bgscan: :simple
      },
      ipv4: %{
        method: :static,
        address: "192.168.24.1",
        netmask: "255.255.255.0"
      },
      dhcpd: %{
        start: "192.168.24.2",
        end: "192.168.24.100",
        options: %{
          dns: ["192.168.24.1"],
          subnet: {255, 255, 255, 0},
          router: ["192.168.24.1"],
          domain: "example.com",
          search: ["example.com"]
        }
      },
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: true,
           verbose: false
         ]},
        {VintageNet.Interface.LANConnectivityChecker, "wlan0"},
        udhcpd_child_spec("wlan0")
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         bgscan="simple"
         ap_scan=1
         network={
         ssid="example ap"
         key_mgmt=NONE
         scan_ssid=1
         mode=2
         }
         """},
        {"/tmp/vintage_net/udhcpd.conf.wlan0",
         """
         interface wlan0
         pidfile /tmp/vintage_net/udhcpd.wlan0.pid
         lease_file /tmp/vintage_net/udhcpd.wlan0.leases
         notify_file #{Application.app_dir(:vintage_net, ["priv", "udhcpd_handler"])}

         end 192.168.24.100
         opt dns 192.168.24.1
         opt domain example.com
         opt router 192.168.24.1
         opt search example.com
         opt subnet 255.255.255.0
         start 192.168.24.2

         """}
      ],
      down_cmds: [
        {:fun, VintageNet.RouteManager, :clear_route, ["wlan0"]},
        {:fun, VintageNet.NameResolver, :clear, ["wlan0"]},
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      up_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["addr", "add", "192.168.24.1/24", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "up"]},
        {:fun, VintageNet.RouteManager, :clear_route, ["wlan0"]},
        {:fun, VintageNet.NameResolver, :clear, ["wlan0"]}
      ],
      cleanup_files: [
        "/tmp/vintage_net/wpa_supplicant/p2p-dev-wlan0",
        "/tmp/vintage_net/wpa_supplicant/wlan0"
      ]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "create an ad hoc network" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        networks: [
          %{
            mode: :ibss,
            ssid: "my_mesh",
            key_mgmt: :none
          }
        ]
      },
      ipv4: %{
        method: :static,
        address: "192.168.24.1",
        netmask: "255.255.255.0"
      },
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: WiFi.normalize(input),
      child_specs: [
        {VintageNet.WiFi.WPASupplicant,
         [
           wpa_supplicant: "wpa_supplicant",
           ifname: "wlan0",
           wpa_supplicant_conf_path: "/tmp/vintage_net/wpa_supplicant.conf.wlan0",
           control_path: "/tmp/vintage_net/wpa_supplicant",
           ap_mode: true,
           verbose: false
         ]},
        {VintageNet.Interface.LANConnectivityChecker, "wlan0"}
      ],
      restart_strategy: :rest_for_one,
      files: [
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="my_mesh"
         key_mgmt=NONE
         mode=1
         }
         """}
      ],
      down_cmds: [
        {:fun, VintageNet.RouteManager, :clear_route, ["wlan0"]},
        {:fun, VintageNet.NameResolver, :clear, ["wlan0"]},
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "down"]}
      ],
      up_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["addr", "add", "192.168.24.1/24", "dev", "wlan0", "label", "wlan0"]},
        {:run, "ip", ["link", "set", "wlan0", "up"]},
        {:fun, VintageNet.RouteManager, :clear_route, ["wlan0"]},
        {:fun, VintageNet.NameResolver, :clear, ["wlan0"]}
      ],
      cleanup_files: [
        "/tmp/vintage_net/wpa_supplicant/p2p-dev-wlan0",
        "/tmp/vintage_net/wpa_supplicant/wlan0"
      ]
    }

    assert output == WiFi.to_raw_config("wlan0", input, default_opts())
  end
end
